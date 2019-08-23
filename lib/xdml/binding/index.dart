import 'dart:core';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:front_end/src/scanner/token.dart';

import '../app.dart';

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
  throw UnsupportedError(
      "parse tree node failed -> unsupport node ${app.fullname}");
}

FunctionExpressionInvocation createFunctionInvokation(
    AstFactory fac, ComponentTreeNode app, List<dynamic> content) {
  // fix type mismatch
  List<Expression> list = [];
  for (var item in content) {
    if (item is Expression) list.add(item);
  }
  return fac.functionExpressionInvocation(
      fac.simpleIdentifier(
          new StringToken(TokenType.IDENTIFIER, app.fullname, 0)),
      null,
      fac.argumentList(null, list, null));
}

ListLiteral createNodeList(
    AstFactory fac, List<AttributeNode> attrs, List<dynamic> content) {
  // fix type mismatch
  List<Expression> list = [];
  for (var item in content) {
    if (item is Expression) list.add(item);
  }
  var type = attrs.firstWhere((i) => i.name == "type" && i.ns == null,
      orElse: () => null);
  var typeMeta = type?.value;
  var typeList = typeMeta != null
      ? fac.typeArgumentList(
          null,
          [
            fac.typeName(
                fac.simpleIdentifier(
                    new StringToken(TokenType.STRING, typeMeta, 0)),
                null)
          ],
          null)
      : null;
  return fac.listLiteral(null, typeList, null, list, null);
}

class _TempPayload {
  ComponentTreeNode node;
  SlotNode slot;
  int childIndex;
  bool isIf = false;
  bool isElse = false;
  bool isIfStatement = false;
  bool isIfElement = false;
  _TempPayload(this.node, this.slot, this.childIndex);
}

enum _TurnType { statement, element, node }

class Turn {
  _TurnType type = _TurnType.node;
  List<_TempPayload> payload = [];

  Turn(this.payload);
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

  List<_TempPayload> slotTreeNodes = [];
  List<_TempPayload> queueTreeNodes = [];

  for (var child in children) {
    // print("${child.fullname}");
    var childIdx = children.indexOf(child);
    var result =
        slots.firstWhere((sl) => sl.index == childIdx, orElse: () => null);
    var isSlotNode = result != null && !internal;
    if (!isSlotNode) {
      queueTreeNodes.add(new _TempPayload(child, result, childIdx));
    } else {
      slotTreeNodes.add(new _TempPayload(child, result, childIdx));
    }
  }

  var turn1 = normalizeIfElseOfNodes(queueTreeNodes, canUseIfElement);
  var turn2 = normalizeIfElseOfNodes(slotTreeNodes, false);

  // print("start resolve turns");

  for (var turn in turn1) {
    if (turn.type == _TurnType.node) {
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
      if (turn.type == _TurnType.element) {
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
    if (turn.type == _TurnType.node) {
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

List<Turn> normalizeIfElseOfNodes(
    List<_TempPayload> nodes, bool canUseIfElement) {
  List<Turn> turns = [];
  for (var idx = 0; idx < nodes.length; idx++) {
    // print("start step ${idx + 1}");
    var item = nodes[idx];
    var child = item.node;
    var ifIdx = child.attrs.indexWhere((i) => isStatementIf(i));
    if (ifIdx >= 0) {
      // print("${item.node.fullname} - if");
      item.isIf = true;
    }
    var elseIdx = child.attrs.indexWhere((i) => isStatementElse(i));
    if (elseIdx >= 0) {
      // print("${item.node.fullname} - else");
      item.isElse = true;
    }
    if (idx > 0) {
      var previousItem = nodes[idx - 1];
      if (previousItem.isIf) {
        if (!canUseIfElement && !item.isElse) {
          throw UnsupportedError(
              "generate tree node failed -> statement 'if' can't exist without statement 'else'");
        }
        if (canUseIfElement && !item.isElse) {
          previousItem.isIfElement = true;
          continue;
        }
        previousItem.isIfStatement = true;
      }
    }
  }
  for (var idx = 0; idx < nodes.length; idx++) {
    // print(idx);
    var item = nodes[idx];
    if (item.isIfStatement) {
      var item2 = nodes[idx + 1];
      turns.add(new Turn([item, item2])..type = _TurnType.statement);
      idx++;
      continue;
    }
    if (item.isIfElement) {
      var item2 = nodes[idx + 1];
      if (item2.isElse) {
        turns.add(new Turn([item, item2])..type = _TurnType.element);
        idx++;
      } else {
        turns.add(new Turn([item])..type = _TurnType.element);
      }
      continue;
    }
    turns.add(new Turn([item])..type = _TurnType.node);
  }
  return turns;
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

List<SimpleIdentifier> insertTextNode(AstFactory fac, String text) {
  List<SimpleIdentifier> content = [];
  var insert = parseInsertExpression(text);
  content.add(
      fac.simpleIdentifier(new StringToken(TokenType.STRING, insert.value, 0)));
  return content;
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

NamedExpression createNamedParamByAttr(
    AstFactory fac, String slotName, String insert) {
  return fac.namedExpression(
      fac.label(
          fac.simpleIdentifier(new StringToken(TokenType.STRING, slotName, 0)),
          new SimpleToken(TokenType.COLON, 0)),
      fac.simpleIdentifier(new StringToken(TokenType.STRING, insert, 0)));
}

class InsertResult {
  bool valid = false;
  dynamic value;
  InsertResult(this.valid, this.value);
}

InsertResult parseInsertExpression(String expression) {
  var valid = false;
  var reg = new RegExp("({{\r*([^}{]+)\r*}})");
  // print("input $expression --> matched:${reg.hasMatch(expression)}");
  var newExpression = expression.replaceAllMapped(reg, (matched) {
    if (matched is RegExpMatch) {
      if (valid == false) valid = true;
      // var insertExp = matched.group(1);
      var insertValue = matched.group(2).trim();
      // print("expr -> [$insertExp]");
      // print("matc -> [$insertValue]");
      return insertValue /*.replaceAll("this.", "_delegate.")*/;
    } else {
      return matched.input;
    }
  });
  return new InsertResult(valid, valid ? newExpression : "'$newExpression'");
}

FunctionDeclaration generateBuildFn(
    AstFactory fac,
    List<SimpleIdentifier> invokeParams,
    String className,
    ComponentTreeNode app) {
  var content = generateTree(fac, app);
  return fac.functionDeclaration(
      null,
      null,
      null,
      fac.typeName(
          fac.simpleIdentifier(new StringToken(TokenType.STRING, "Widget", 0)),
          null),
      null,
      fac.simpleIdentifier(new StringToken(TokenType.STRING, "bindXDML", 0)),
      fac.functionExpression(
          null,
          fac.formalParameterList(
            null,
            invokeParams.map((i) {
              var paramName = i.name;
              var isContext = paramName == "context";
              var typeName = isContext ? "BuildContext" : "dynamic";
              var param = fac.simpleFormalParameter2(
                  type: fac.typeName(
                      fac.simpleIdentifier(
                          new StringToken(TokenType.STRING, typeName, 0)),
                      null),
                  identifier: fac.simpleIdentifier(
                      new StringToken(TokenType.STRING, paramName, 0)));
              return param;
            }).toList(),
            null,
            null,
            null,
          ),
          fac.blockFunctionBody(
              null,
              null,
              fac.block(
                  new SimpleToken(TokenType.OPEN_CURLY_BRACKET, 0),
                  [
                    fac.returnStatement(
                        new KeywordToken(Keyword.RETURN, 0), content, null)
                  ],
                  new SimpleToken(TokenType.CLOSE_CURLY_BRACKET, 0)))));
}
