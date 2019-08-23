import 'dart:core';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast_factory.dart';
import 'package:analyzer/Src/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:front_end/src/scanner/token.dart';

import 'base.dart';
import 'app.dart';

class TempPayload {
  ComponentTreeNode node;
  SlotNode slot;
  int childIndex;
  bool isIf = false;
  bool isElse = false;
  bool isIfStatement = false;
  bool isIfElement = false;
  TempPayload(this.node, this.slot, this.childIndex);

  bool get isSelf => this.isIf && this.isElse;
}

enum TurnType { statement, element, node }

class Turn {
  TurnType type = TurnType.node;
  List<TempPayload> payload = [];

  Turn(this.payload);
}

class InsertResult {
  bool valid = false;
  dynamic value;
  InsertResult(this.valid, this.value);
}

class XDMLNodeFactory {
  AstFactory fac = new AstFactoryImpl();
  ComponentTreeNode app;
  String className;
  List<SimpleIdentifier> invokeParams = [];

  XDMLNodeFactory(this.app, this.className, {this.invokeParams});

  FunctionDeclaration generate({Iterable<VariableDeclaration> variables}) {
    var content = generateTree(app);
    List<Statement> statements = [];
    if (variables != null && variables.isNotEmpty) {
      var variableDeclarations = <VariableDeclaration>[]
        ..addAll(variables ?? []);
      variableDeclarations.forEach((va) => statements.add(
          fac.variableDeclarationStatement(
              fac.variableDeclarationList(
                  null, null, new KeywordToken(Keyword.VAR, 0), null, [va]),
              null)));
    }
    statements.add(fac.returnStatement(
        new KeywordToken(Keyword.RETURN, 0), content, null));
    return fac.functionDeclaration(
        null,
        null,
        null,
        fac.typeName(
            fac.simpleIdentifier(
                new StringToken(TokenType.STRING, "Widget", 0)),
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
                    statements,
                    new SimpleToken(TokenType.CLOSE_CURLY_BRACKET, 0)))));
  }

  Expression generateTree(ComponentTreeNode host, {String subName}) {
    var internal = host.internal;
    var attrs = host.attrs.where((i) => !isXDMLSlot(i)).toList();
    var children = host.children;
    var slots = host.slots;
    var commonAttrs = internal ? <AttributeNode>[] : attrs;

    List<dynamic> content = host.innerText != null
        ? insertTextNode(host.innerText)
        : insertCommonNode(internal, commonAttrs, children, slots, host);

    if (!internal) {
      return createFunctionInvokation(host, content);
    }
    if (host.name == "NodeList") {
      return createNodeList(attrs, content);
    }
    if (host.name == "EscapeText") {
      return createEscapeText(host.innerText);
    }
    if (host.name == "Template") {
      return createFunctionInvokation(host, content);
    }
    throw UnsupportedError(
        "parse tree node failed -> unsupport node ${host.fullname}");
  }

  List<AstNode> insertCommonNode(
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
      if (isStatementIf(attr) || isStatementElse(attr) || isXDMLHost(attr))
        continue;
      var insert = isInsertBind(attr)
          ? attr.value
          : parseInsertExpression(attr.value).value;
      attrNodes.add(createNamedParamByAttr(attr.name, insert));
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
            .add(createNormalParamByChildNode(attrs, turn.payload[0].node));
      } else {
        var ifChild = turn.payload[0].node;
        var elseChild = turn.payload.length > 1 ? turn.payload[1].node : null;
        var ifAttr = ifChild.attrs
            .firstWhere((i) => isStatementIf(i), orElse: () => null);
        var condition = fac.simpleStringLiteral(
            new StringToken(TokenType.STRING, ifAttr.value, 0), '');
        var then = createNormalParamByChildNode(attrs, ifChild);
        var elseNode = elseChild == null
            ? null
            : createNormalParamByChildNode(attrs, elseChild);
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
        slotNodes.add(createSlotChildNode(children, turn.payload[0].slot, app));
      } else {
        var ifChild = turn.payload[0];
        var elseChild = turn.payload.length > 1 ? turn.payload[1].node : null;
        var ifAttr = ifChild.node.attrs
            .firstWhere((i) => isStatementIf(i), orElse: () => null);
        slotNodes.add(createSlotChildNode(children, ifChild.slot, app,
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

  NamedExpression createSlotChildNode(
      List<ComponentTreeNode> children, SlotNode result, ComponentTreeNode app,
      {ComponentTreeNode elseNode, AttributeNode ifStatement}) {
    var targetChild = findSlotChildNode(children, result);
    if (targetChild == null) {
      throw UnsupportedError(
          "generate tree node failed -> node ${app.fullname}'s slot [${result.target}] not found");
    }
    return createNamedParamByChildNode(result.target, targetChild,
        elseNode: elseNode, ifStatement: ifStatement);
  }

  ComponentTreeNode findSlotChildNode(
      List<ComponentTreeNode> children, SlotNode result) {
    return children.firstWhere(
        (c) => c.name == result.value && c.ns == result.ns,
        orElse: () => null);
  }

  Expression createNormalParamByChildNode(
      Iterable<AttributeNode> attrs, ComponentTreeNode targetChild) {
    return generateTree(targetChild);
  }

  NamedExpression createNamedParamByChildNode(
      String slotName, ComponentTreeNode targetChild,
      {ComponentTreeNode elseNode,
      AttributeNode ifStatement,
      bool useIfElement}) {
    return fac.namedExpression(
        fac.label(
            fac.simpleIdentifier(
                new StringToken(TokenType.STRING, slotName, 0)),
            new SimpleToken(TokenType.COLON, 0)),
        elseNode == null
            ? generateTree(targetChild)
            : fac.conditionalExpression(
                fac.simpleStringLiteral(
                    new StringToken(TokenType.STRING, ifStatement.value, 0),
                    ''),
                new SimpleToken(TokenType.QUESTION, 0),
                generateTree(targetChild),
                null,
                generateTree(elseNode)));
  }

  ListLiteral createNodeList(List<AttributeNode> attrs, List<dynamic> content) {
    // fix type mismatch
    List<CollectionElement> list = [];
    for (var item in content) {
      if (item is CollectionElement) {
        list.add(item);
      } else {
        print(
            "warning : [${item.runtimeType}] element is drop -> ${item.toString()}");
      }
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

  SimpleIdentifier createEscapeText(String text) {
    return fac.simpleIdentifier(new StringToken(TokenType.STRING, text, 0));
  }

  FunctionExpressionInvocation createFunctionInvokation(
      ComponentTreeNode host, List<dynamic> content) {
    // fix type mismatch
    List<Expression> list = [];
    for (var item in content) {
      if (item is Expression) {
        list.add(item);
      } else {
        print(
            "warning : [${item.runtimeType}] element is drop -> ${item.toString()}");
      }
    }
    return fac.functionExpressionInvocation(
        fac.simpleIdentifier(
            new StringToken(TokenType.IDENTIFIER, host.fullname, 0)),
        null,
        fac.argumentList(null, list, null));
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

  NamedExpression createNamedParamByAttr(String slotName, String insert) {
    return fac.namedExpression(
        fac.label(
            fac.simpleIdentifier(
                new StringToken(TokenType.STRING, slotName, 0)),
            new SimpleToken(TokenType.COLON, 0)),
        fac.simpleIdentifier(new StringToken(TokenType.STRING, insert, 0)));
  }

  List<SimpleIdentifier> insertTextNode(String text) {
    List<SimpleIdentifier> content = [];
    var insert = parseInsertExpression(text);
    content.add(fac
        .simpleIdentifier(new StringToken(TokenType.STRING, insert.value, 0)));
    return content;
  }

  List<Turn> normalizeIfElseOfNodes(
      List<TempPayload> payloads, bool canUseIfElement) {
    List<Turn> turns = [];
    for (var idx = 0; idx < payloads.length; idx++) {
      // print("start step ${idx + 1}");
      var item = payloads[idx];
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
        var previousItem = payloads[idx - 1];
        if (previousItem.isIf && !previousItem.isSelf) {
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
    for (var idx = 0; idx < payloads.length; idx++) {
      // print(idx);
      var payload = payloads[idx];
      if (payload.isSelf) {
        var node = payload.node;
        var elseNode = node.attrs
            .firstWhere((i) => isStatementElse(i), orElse: () => null);
        var newEscape = new ComponentTreeNode(
            true,
            "EscapeText",
            /** 暂时不处理，需要改 */ null,
            XDML,
            [],
            [],
            elseNode?.value,
            node.parent);
        turns.add(
            new Turn([payload, new TempPayload(newEscape, payload.slot, -1)])
              ..type = TurnType.statement);
        continue;
      }
      if (payload.isIfStatement) {
        var payloadNext = payloads[idx + 1];
        turns.add(new Turn([payload, payloadNext])..type = TurnType.statement);
        idx++;
        continue;
      }
      if (payload.isIfElement) {
        var payloadNext = payloads[idx + 1];
        if (payloadNext.isElse) {
          turns.add(new Turn([payload, payloadNext])..type = TurnType.element);
          idx++;
        } else {
          turns.add(new Turn([payload])..type = TurnType.element);
        }
        continue;
      }
      turns.add(new Turn([payload])..type = TurnType.node);
    }
    return turns;
  }
}
