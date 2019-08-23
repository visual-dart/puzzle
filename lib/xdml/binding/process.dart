import 'dart:core';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:front_end/src/scanner/token.dart';

import '../app.dart';
import 'base.dart';
import 'node.dart';

Expression generateTree(AstFactory fac, ComponentTreeNode app,
    {String subName}) {
  var internal = app.internal;
  var attrs = app.attrs.where((i) => !isXDMLSlot(i)).toList();
  var children = app.children;
  var slots = app.slots;
  var commonAttrs = internal ? <AttributeNode>[] : attrs;

  List<dynamic> content = app.innerText != null
      ? insertTextNode(fac, app.innerText)
      : insertCommonNode(fac, internal, commonAttrs, children, slots, app);

  if (!internal) {
    return createFunctionInvokation(fac, app, content);
  }
  if (app.name == "NodeList") {
    return createNodeList(fac, attrs, content);
  }
  if (app.name == "EscapeText") {
    return createEscapeText(fac, app.innerText);
  }
  throw UnsupportedError(
      "parse tree node failed -> unsupport node ${app.fullname}");
}

List<AstNode> insertCommonNode(
    AstFactory fac,
    bool internal,
    List<AttributeNode> attrs,
    List<ComponentTreeNode> children,
    List<SlotNode> slots,
    ComponentTreeNode app) {
  List<NamedExpression> attrNodes = [];
  List<NamedExpression> slotNodes = [];
  List<AstNode> queueNodes = [];

  bool canUseIfElement = internal && app.name == "NodeList";

  for (var attr in attrs) {
    if (isStatementIf(attr) || isStatementElse(attr)) continue;
    var insert = isInsertBind(attr)
        ? attr.value
        : parseInsertExpression(attr.value).value;
    attrNodes.add(createNamedParamByAttr(fac, attr.name, insert));
  }

  List<TempPayload> slotTreeNodes = [];
  List<TempPayload> queueTreeNodes = [];

  for (var child in children) {
    // print("${child.fullname}");
    var childIdx = children.indexOf(child);
    var result =
        slots.firstWhere((sl) => sl.index == childIdx, orElse: () => null);
    var isSlotNode = result != null && !internal;
    if (!isSlotNode) {
      queueTreeNodes.add(new TempPayload(child, result, childIdx));
    } else {
      slotTreeNodes.add(new TempPayload(child, result, childIdx));
    }
  }

  var turn1 = normalizeIfElseOfNodes(queueTreeNodes, canUseIfElement);
  var turn2 = normalizeIfElseOfNodes(slotTreeNodes, false);

  // print("start resolve turns");

  for (var turn in turn1) {
    if (turn.type == TurnType.node) {
      queueNodes
          .add(createNormalParamByChildNode(fac, attrs, turn.payload[0].node));
    } else {
      var ifChild = turn.payload[0].node;
      var elseChild = turn.payload.length > 1 ? turn.payload[1].node : null;
      var ifAttr =
          ifChild.attrs.firstWhere((i) => isStatementIf(i), orElse: () => null);
      var condition = fac.simpleStringLiteral(
          new StringToken(TokenType.STRING, ifAttr.value, 0), '');
      var then = createNormalParamByChildNode(fac, attrs, ifChild);
      var elseNode = elseChild == null
          ? null
          : createNormalParamByChildNode(fac, attrs, elseChild);
      if (turn.type == TurnType.element) {
        queueNodes.add(fac.ifElement(
            condition: condition, thenElement: then, elseElement: elseNode));
      } else {
        queueNodes.add(fac.conditionalExpression(condition,
            new SimpleToken(TokenType.QUESTION, 0), then, null, elseNode));
      }
    }
  }

  // print("start resolve turns2");

  for (var turn in turn2) {
    if (turn.type == TurnType.node) {
      slotNodes
          .add(createSlotChildNode(children, turn.payload[0].slot, app, fac));
    } else {
      var ifChild = turn.payload[0];
      var elseChild = turn.payload.length > 1 ? turn.payload[1].node : null;
      var ifAttr = ifChild.node.attrs
          .firstWhere((i) => isStatementIf(i), orElse: () => null);
      slotNodes.add(createSlotChildNode(children, ifChild.slot, app, fac,
          elseNode: elseChild, ifStatement: ifAttr));
    }
  }

  List<AstNode> content = []..addAll(queueNodes);
  // 节点优先级，slot节点靠后
  for (var attr in attrNodes) {
    content.add(attr);
  }
  for (var slot in slotNodes) {
    content.add(slot);
  }
  return content;
}

NamedExpression createSlotChildNode(List<ComponentTreeNode> children,
    SlotNode result, ComponentTreeNode app, AstFactory fac,
    {ComponentTreeNode elseNode, AttributeNode ifStatement}) {
  var targetChild = findSlotChildNode(children, result);
  if (targetChild == null) {
    throw UnsupportedError(
        "generate tree node failed -> node ${app.fullname}'s slot [${result.target}] not found");
  }
  return createNamedParamByChildNode(fac, result.target, targetChild,
      elseNode: elseNode, ifStatement: ifStatement);
}

ComponentTreeNode findSlotChildNode(
    List<ComponentTreeNode> children, SlotNode result) {
  return children.firstWhere((c) => c.name == result.value && c.ns == result.ns,
      orElse: () => null);
}

Expression createNormalParamByChildNode(AstFactory fac,
    Iterable<AttributeNode> attrs, ComponentTreeNode targetChild) {
  return generateTree(fac, targetChild);
}

NamedExpression createNamedParamByChildNode(
    AstFactory fac, String slotName, ComponentTreeNode targetChild,
    {ComponentTreeNode elseNode,
    AttributeNode ifStatement,
    bool useIfElement}) {
  return fac.namedExpression(
      fac.label(
          fac.simpleIdentifier(new StringToken(TokenType.STRING, slotName, 0)),
          new SimpleToken(TokenType.COLON, 0)),
      elseNode == null
          ? generateTree(fac, targetChild)
          : fac.conditionalExpression(
              fac.simpleStringLiteral(
                  new StringToken(TokenType.STRING, ifStatement.value, 0), ''),
              new SimpleToken(TokenType.QUESTION, 0),
              generateTree(fac, targetChild),
              null,
              generateTree(fac, elseNode)));
}
