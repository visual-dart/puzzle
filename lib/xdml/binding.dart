import 'dart:core';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast_factory.dart';
import 'package:analyzer/Src/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:front_end/src/scanner/token.dart';

import 'base.dart';
import 'app.dart';

// final PARAMS_REG = new RegExp("([^\r,\.]*\r*)([^\r,\.]+)");

class IfElsePayload {
  ComponentTreeNode node;
  SlotNode slot;
  int childIndex;

  bool isIf = false;
  bool isElse = false;
  bool isElseIf = false;
  /** if声明语句，在语法块中使用 */
  bool isIfStatement = false;
  /** if元素语句，可以在List中使用 */
  bool isIfElement = false;

  bool useAsIf = false;
  bool useAsElseIf = false;
  bool useAsElse = false;

  IfElsePayload(this.node, this.slot, this.childIndex);

  /** 自关闭if声明 */
  bool get isSelf => isElse && (isIf || isElseIf);

  /** 非if声明 */
  bool get isNotStatement => !isIf && !isElse && !isElseIf;
}

enum IfElseType { statement, element, node }

class IfElseSection {
  IfElseType type = IfElseType.node;
  List<IfElsePayload> payload = [];

  IfElseSection(this.payload);
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

  FunctionDeclaration generateFn(
      {Iterable<VariableDeclaration> variables,
      String returnType,
      String contextName,
      String contextType}) {
    var content = generateTree();
    if (content is! Expression) {
      throw UnsupportedError(
          "generate content error : content's realType is [${content.runtimeType}] but not [Expression]");
    }
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
        fac.typeName(createIdentifier(returnType ?? "Widget"), null),
        null,
        createIdentifier("bindXDML"),
        fac.functionExpression(
            null,
            fac.formalParameterList(
              null,
              invokeParams.map((i) {
                var paramName = i.name;
                var isContext = paramName == (contextName ?? "context");
                var typeName =
                    isContext ? (contextType ?? "BuildContext") : "dynamic";
                var param = fac.simpleFormalParameter2(
                    type: fac.typeName(createIdentifier(typeName), null),
                    identifier: createIdentifier(paramName));
                return param;
              }).toList(),
              null,
              null,
              null,
            ),
            fac.blockFunctionBody(null, null, createBlock(statements))));
  }

  AstNode generateTree({ComponentTreeNode app, String subName}) {
    var host = app ?? this.app;

    if (host.name == XDMLNodes.Execution) {
      return fac.expressionStatement(
          createIdentifier((host.children.elementAt(0).innerText)), null);
    }
    if (host.name == XDMLNodes.ViewBuilder) {
      return createViewGeneratorExpression(host);
    }
    if (host.name == XDMLNodes.EscapeText) {
      return createIdentifier(host.innerText);
    }
    if (host.name == XDMLNodes.ExpressionText) {
      return createIdentifier(parseInsertExpression(host.innerText).value);
    }

    var internal = host.internal;
    var attrs = host.attrs.where((i) => !isXDMLSlot(i)).toList();
    var children = host.children;
    var slots = host.slots;
    var commonAttrs = internal ? <AttributeNode>[] : attrs;
    var content =
        insertCommonNode(internal, commonAttrs, children, slots, host);

    if (host.name == XDMLNodes.NodeList) {
      return createNodeList(attrs, content);
    }
    if (host.name == XDMLNodes.ViewUnit) {
      return createFunctionInvokation(host, content);
    }
    if (!internal) {
      return createFunctionInvokation(host, content);
    }
    throw UnsupportedError(
        "parse tree node failed -> unsupport node ${host.fullname}");
  }

  FormalParameterList createViewGeneratorParams(ComponentTreeNode host) {
    if (host.name != XDMLNodes.ViewBuilder) return null;
    var attrs = host.attrs;
    List<FormalParameter> params = [];
    // List<FormalParameter> paramNameds = [];
    for (var attr in attrs) {
      // print(attr.name);
      if (attr.name.startsWith("params")) {
        var value = (attr.value == null || attr.value == "") ? "" : attr.value;
        var parameters = value.split(",").map((i) => i.trim());
        for (var param in parameters) {
          var tv = param.split(" ").map((i) => i.trim());
          if (tv.isNotEmpty) {
            params.add(fac.simpleFormalParameter2(
                type: fac.typeName(
                    createIdentifier(tv.length > 1 ? tv.first : "dynamic"),
                    null),
                identifier: createIdentifier(tv.last)));
          }
        }
      }
      if (attr.name.startsWith("param-")) {
        var paramName = attr.name.replaceAll("param-", "");
        var paramType =
            (attr.value == null || attr.value == "") ? "dynamic" : attr.value;
        params.add(fac.simpleFormalParameter2(
            type: fac.typeName(createIdentifier(paramType), null),
            identifier: createIdentifier(paramName)));
        continue;
      }
      // 命名参数暂不支持实现
      if (attr.name.startsWith("namedPass-")) {
        // var paramNames = attr.name.replaceAll("namedPass-", "").split("-");
        // var paramType = attr.value;
        // String sourceName;
        // sourceName = paramNames.elementAt(0);
        // paramNameds.add(fac.fieldFormalParameter2(
        //     thisKeyword: null,
        //     period: null,
        //     identifier: createIdentifier(sourceName),
        //     type: fac.typeName(createIdentifier(paramType), null)));
        // continue;
      }
    }
    return fac.formalParameterList(
        null,
        <FormalParameter>[]..addAll(params) /*..addAll(paramNameds)*/,
        new SimpleToken(TokenType.OPEN_CURLY_BRACKET, 0),
        new SimpleToken(TokenType.CLOSE_CURLY_BRACKET, 0),
        null);
  }

  BlockFunctionBody createViewGeneratorBody(ComponentTreeNode host) {
    if (host.name != XDMLNodes.ViewBuilder) return null;
    List<VariableDeclarationList> declarations = [];
    List<Statement> executions = [];
    var attrs = host.attrs;
    for (var attr in attrs) {
      if (attr.name == "vars") {
        var value = (attr.value == null || attr.value == "") ? "" : attr.value;
        var vars = value.split(";").map((i) => i.trim());
        for (var variable in vars) {
          if (!variable.startsWith("var")) variable = "var " + variable.trim();
          if (variable.endsWith(";"))
            variable = variable.substring(0, variable.length - 1);
          executions
              .add(fac.expressionStatement(createIdentifier(variable), null));
        }
      }
      if (attr.name.startsWith("var-")) {
        var paramName = attr.name.replaceAll("var-", "");
        var expression = attr.value;
        declarations.add(fac.variableDeclarationList(
            null, null, new KeywordToken(Keyword.VAR, 0), null, [
          fac.variableDeclaration(createIdentifier(paramName), null,
              createStringLiteral(expression))
        ]));
        continue;
      }
    }
    var variableStatements =
        declarations.map((s) => fac.variableDeclarationStatement(s, null));
    var result = insertCommonNode(host.internal, [], host.children, [], host);
    Expression returnExpression;
    for (var item in result) {
      // print(item.runtimeType);
      if (result.indexOf(item) == result.length - 1 && item is Expression) {
        returnExpression = item;
      } else if (item is Statement) {
        executions.add(item);
      }
    }
    var resurnStatement = fac.returnStatement(
        new KeywordToken(Keyword.RETURN, 0), returnExpression, null);
    return fac.blockFunctionBody(
        null,
        null,
        createBlock(<Statement>[]
          ..addAll(variableStatements)
          ..addAll(executions)
          ..add(resurnStatement)));
  }

  bool isIfElseAttrNode(ComponentTreeNode i) {
    return (getStatementIf(i) != null) || (getStatementElse(i) != null);
  }

  AttributeNode getStatementElse(ComponentTreeNode i) =>
      i.attrs.firstWhere((i) => isStatementElse(i), orElse: () => null);

  AttributeNode getStatementIf(ComponentTreeNode i) =>
      i.attrs.firstWhere((i) => isStatementIf(i), orElse: () => null);

  List<AstNode> insertCommonNode(
      bool internal,
      List<AttributeNode> attrs,
      List<ComponentTreeNode> children,
      List<SlotNode> slots,
      ComponentTreeNode app) {
    List<NamedExpression> attrNodes = [];
    List<NamedExpression> slotNodes = [];
    List<AstNode> queueNodes = [];

    // print("app name [${app.fullname}]");

    bool canUseIfElement = internal && app.name == XDMLNodes.NodeList;

    for (var attr in attrs) {
      if (isStatementIf(attr) ||
          isStatementElse(attr) ||
          isStatementElseIf(attr) ||
          isXDMLHost(attr)) continue;
      var insert = isInsertBind(attr)
          ? attr.value
          : parseInsertExpression(attr.value).value;
      attrNodes.add(createNamedParamByAttr(attr.name, insert));
    }

    List<IfElsePayload> slotTreeNodes = [];
    List<IfElsePayload> queueTreeNodes = [];

    for (var child in children) {
      // print("${child.fullname}");
      var childIdx = children.indexOf(child);
      var result =
          slots.firstWhere((sl) => sl.index == childIdx, orElse: () => null);
      var isSlotNode = result != null && !internal;
      if (!isSlotNode) {
        queueTreeNodes.add(new IfElsePayload(child, result, childIdx));
      } else {
        slotTreeNodes.add(new IfElsePayload(child, result, childIdx));
      }
    }

    // print(canUseIfElement);
    // print("start normalize turns1");
    var turn1 = normalizeIfElseOfNodes(queueTreeNodes, canUseIfElement);
    // print("start normalize turns2");
    var turn2 = normalizeIfElseOfNodes(slotTreeNodes, false);

    // print("start resolve turns1");
    for (var turn in turn1) {
      if (turn.type == IfElseType.node) {
        queueNodes
            .add(createNormalParamByChildNode(attrs, turn.payload[0].node));
      } else {
        var ifChild = turn.payload[0].node;
        List<IfElsePayload> afterChildren =
            turn.payload.length > 1 ? turn.payload.sublist(1) : [];
        var ifAttr = ifChild.attrs
            .firstWhere((i) => isStatementIf(i), orElse: () => null);
        var condition = createStringLiteral(ifAttr.value);
        var thenExpression = createNormalParamByChildNode(attrs, ifChild);
        var elseExpression = createIfStatementElse(
            attrs, afterChildren.map((f) => f.node).toList(),
            useEle: canUseIfElement);
        queueNodes.add(canUseIfElement
            ? fac.ifElement(
                condition: condition,
                thenElement: thenExpression,
                elseElement: elseExpression)
            : fac.conditionalExpression(
                condition,
                new SimpleToken(TokenType.QUESTION, 0),
                thenExpression,
                null,
                elseExpression));
      }
    }

    // print("start resolve turns2");

    for (var turn in turn2) {
      if (turn.type == IfElseType.node) {
        // print("visti slot node [${turn.payload[0].node.fullname}]");
        slotNodes.add(createSlotChildNode(
            children, turn.payload[0].slot, turn.payload[0].node));
      } else {
        // print("visti slot if-else [${turn.payload[0].node.fullname}]");
        // print(turn.payload.map((f) => f.node.fullname).join("-"));
        var ifChild = turn.payload[0].node;
        List<IfElsePayload> afterChildren =
            turn.payload.length > 1 ? turn.payload.sublist(1) : [];
        var ifAttr = ifChild.attrs
            .firstWhere((i) => isStatementIf(i), orElse: () => null);
        var elseExpression = createIfStatementElse(
            attrs, afterChildren.map((f) => f.node).toList(),
            useEle: false);
        slotNodes.add(createSlotChildNode(
            children, turn.payload[0].slot, ifChild,
            elseExpression: elseExpression, ifStatement: ifAttr));
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

  CollectionElement createIfStatementElse(
      List<AttributeNode> attrs, List<ComponentTreeNode> children,
      {bool useEle = false}) {
    // print(children.length);
    if (children.isNotEmpty) {
      if (children.length > 1) {
        var ifChild = children.elementAt(0);
        var afterChildren = children.sublist(1);
        var thenExpression = createNormalParamByChildNode(attrs, ifChild);
        var elseExpression =
            createIfStatementElse(attrs, afterChildren, useEle: useEle);
        var esleIfAttr = ifChild.attrs
            .firstWhere((i) => isStatementElseIf(i), orElse: () => null);
        var condition = createStringLiteral(esleIfAttr.value);
        return useEle
            ? fac.ifElement(
                condition: condition,
                thenElement: thenExpression,
                elseElement: elseExpression)
            : fac.conditionalExpression(
                condition,
                new SimpleToken(TokenType.QUESTION, 0),
                thenExpression,
                null,
                elseExpression);
      } else {
        var ifChild = children.elementAt(0);
        var esleIfAttr = ifChild.attrs
            .firstWhere((i) => isStatementElseIf(i), orElse: () => null);
        var condition =
            esleIfAttr != null ? createStringLiteral(esleIfAttr.value) : null;
        var thenExpression = createNormalParamByChildNode(attrs, ifChild);
        return (useEle && condition != null)
            ? fac.ifElement(
                condition: condition,
                thenElement: thenExpression,
                elseElement: null)
            : createNormalParamByChildNode(attrs, children.elementAt(0));
      }
    } else {
      return null;
    }
  }

  NamedExpression createSlotChildNode(
      List<ComponentTreeNode> children, SlotNode result, ComponentTreeNode app,
      {ComponentTreeNode elseNode,
      Expression elseExpression,
      AttributeNode ifStatement}) {
    var targetChild = findSlotChildNode(children, result);
    if (targetChild == null) {
      throw UnsupportedError(
          "generate tree node failed -> node ${app.fullname}'s slot [${result.target}] not found");
    }
    return createNamedParamByChildNode(result.target, targetChild,
        elseNode: elseNode,
        elseExpression: elseExpression,
        ifStatement: ifStatement);
  }

  ComponentTreeNode findSlotChildNode(
      List<ComponentTreeNode> children, SlotNode result) {
    return children.firstWhere(
        (c) => c.name == result.value && c.ns == result.ns,
        orElse: () => null);
  }

  AstNode createNormalParamByChildNode(
      Iterable<AttributeNode> attrs, ComponentTreeNode targetChild) {
    // print("[createNormalParamByChildNode] - [${app.fullname}]");
    return generateTree(app: targetChild);
  }

  NamedExpression createNamedParamByChildNode(
      String slotName, ComponentTreeNode targetChild,
      {ComponentTreeNode elseNode,
      Expression elseExpression,
      AttributeNode ifStatement,
      bool useIfElement}) {
    Expression finalExp;
    if (elseNode == null && elseExpression == null) {
      var result = generateTree(app: targetChild);
      if (result is! Expression) {
        throw UnsupportedError(
            "generate namedResult node error : namedResult's realType is [${result.runtimeType}] but not [Expression]");
      }
      finalExp = result;
    } else {
      var nodeIf = generateTree(app: targetChild);
      var nodeElse = elseExpression ?? generateTree(app: elseNode);
      if (nodeIf is! Expression) {
        throw UnsupportedError(
            "generate nodeIf node error : nodeIf's realType is [${nodeIf.runtimeType}] but not [Expression]");
      }
      if (nodeElse is! Expression) {
        throw UnsupportedError(
            "generate nodeElse node error : nodeElse's realType is [${nodeElse.runtimeType}] but not [Expression]");
      }
      finalExp = fac.conditionalExpression(
          createStringLiteral(ifStatement.value),
          new SimpleToken(TokenType.QUESTION, 0),
          generateTree(app: targetChild),
          null,
          nodeElse);
    }
    return fac.namedExpression(
        fac.label(
            createIdentifier(slotName), new SimpleToken(TokenType.COLON, 0)),
        finalExp);
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
            null, [fac.typeName(createIdentifier(typeMeta), null)], null)
        : null;
    return fac.listLiteral(null, typeList, null, list, null);
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

  FunctionExpression createViewGeneratorExpression(ComponentTreeNode host) {
    return fac.functionExpression(
        null, createViewGeneratorParams(host), createViewGeneratorBody(host));
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
            createIdentifier(slotName), new SimpleToken(TokenType.COLON, 0)),
        createIdentifier(insert));
  }

  List<SimpleIdentifier> insertTextNode(String text) {
    List<SimpleIdentifier> content = [];
    var insert = parseInsertExpression(text);
    content.add(createIdentifier(insert.value));
    return content;
  }

  List<IfElseSection> normalizeIfElseOfNodes(
      List<IfElsePayload> payloads, bool canUseIfElement) {
    List<IfElseSection> turns = [];
    List<IfElsePayload> tempList = [];
    // print("payload length [${payloads.length}]");
    for (var idx = 0; idx < payloads.length; idx++) {
      var item = checkItemIfElse(payloads[idx]);
      if (item.isIf || item.isElseIf || item.isElse) {
        tempList.add(item);
      } else {
        turns.add(new IfElseSection([item])..type = IfElseType.node);
        continue;
      }
      // 下一个node可能将要触发close语句
      if ((item.isIf || item.isElseIf) &&
          !item.isElse &&
          idx < payloads.length - 1) {
        var nextItem = checkItemIfElse(payloads[idx + 1]);
        // print(
        //     "[${nextItem.node.fullname}:${nextItem.node.innerText ?? '..'}] - not-statement[${nextItem.isNotStatement}] - is-else[${nextItem.isElse}]");
        if (nextItem.isElse) {
          tempList.add(nextItem);
          var newTurn = collectIfStatements(tempList, canUseIfElement);
          if (newTurn != null) {
            turns.add(newTurn);
            tempList = [];
          }
          idx++;
          continue;
        }
        if (nextItem.isNotStatement || nextItem.isIf) {
          var newTurn = collectIfStatements(tempList, canUseIfElement);
          if (newTurn != null) {
            turns.add(newTurn);
            tempList = [];
          }
          continue;
        }
      }
    }
    return turns;
  }

  IfElseSection collectIfStatements(
      List<IfElsePayload> tempList, bool canUseIfElement) {
    for (var tdx = 0; tdx < tempList.length; tdx++) {
      var crt = tempList[tdx];
      // 自关闭node，不存在前node，直接处理
      if (tdx == 0 && crt.isSelf) {
        // print(crt.node.fullname + " with self close");
        return createSelfStatement([crt]);
      }
      // 不是第一个元素，存在前node
      if (tdx > 0) {
        var pre = tempList[tdx - 1];
        // 前一个node是if，且没有关闭
        // 假如当前node依然是if，语法错误
        if ((pre.isIf || pre.isElseIf) &&
            !pre.isSelf &&
            crt.isIf &&
            !canUseIfElement) {
          throw UnsupportedError(
              "generate if logic failed -> statement 'if' or 'esle-if' can't exist with next 'if'");
        }
        if (tdx == tempList.length - 1) {
          // print(tempList.map((f) => f.node.fullname).join("-"));
          return createSelfStatement(tempList);
        }
      }
    }
    return null;
  }

  IfElsePayload checkItemIfElse(IfElsePayload item) {
    var child = item.node;
    item.isIf = child.attrs.indexWhere((i) => isStatementIf(i)) >= 0;
    item.isElse = child.attrs.indexWhere((i) => isStatementElse(i)) >= 0;
    item.isElseIf = child.attrs.indexWhere((i) => isStatementElseIf(i)) >= 0;
    return item;
  }

  IfElseSection createSelfStatement(List<IfElsePayload> payloads) {
    List<IfElsePayload> results = [];
    if (payloads.isEmpty) return new IfElseSection([]);
    if (payloads.length == 1) {
      var first = payloads.first;
      var hasIf = first.node.attrs
              .firstWhere((t) => isStatementIf(t), orElse: () => null) !=
          null;
      if (!hasIf) {
        return new IfElseSection(results)..type = IfElseType.node;
      }
      var attrElse = first.node.attrs
          .firstWhere((t) => isStatementElse(t), orElse: () => null);
      first.useAsIf = true;
      results.add(first);
      if (attrElse != null) {
        var last = new IfElsePayload(
            new ComponentTreeNode(
                true,
                XDMLNodes.EscapeText,
                /** 暂时不处理，需要改 */ null,
                XDML,
                [],
                [],
                first.node.parent)
              ..innerText = attrElse.value,
            first.slot,
            first.childIndex);
        last.useAsElse = true;
        results.add(last);
      }
      return new IfElseSection(results)..type = IfElseType.statement;
    } else {
      var first = payloads.first;
      var last = payloads.last;
      List<IfElsePayload> contents =
          payloads.length > 2 ? payloads.sublist(1, payloads.length - 1) : [];
      first.useAsIf = true;
      results.add(first);
      for (var child in contents) {
        var hasElseIf = child.node.attrs
                .firstWhere((t) => isStatementElseIf(t), orElse: () => null) !=
            null;
        if (hasElseIf) {
          child.useAsElseIf = true;
          results.add(child);
        }
      }
      var attrElseIf = last.node.attrs
          .firstWhere((t) => isStatementElseIf(t), orElse: () => null);
      var attrElse = last.node.attrs
          .firstWhere((t) => isStatementElse(t), orElse: () => null);
      if (attrElseIf != null) {
        last.useAsElseIf = true;
        results.add(last);
        if (attrElse != null &&
            (attrElse.value == null || attrElse.value == "")) {
          var preLast = new IfElsePayload(
              new ComponentTreeNode(
                  true,
                  XDMLNodes.EscapeText,
                  /** ��时不处理，需要改 */ null,
                  XDML,
                  [],
                  [],
                  last.node.parent)
                ..innerText = attrElse.value,
              last.slot,
              last.childIndex);
          preLast.useAsElse = true;
          results.add(preLast);
        }
      } else {
        last.useAsElseIf = false;
        last.useAsElse = true;
        results.add(last);
      }
      return new IfElseSection(results)..type = IfElseType.statement;
    }
  }

  StringToken createStringToken(String value) {
    return new StringToken(TokenType.STRING, value, 0);
  }

  SimpleIdentifier createIdentifier(String value) {
    return fac.simpleIdentifier(createStringToken(value));
  }

  SimpleStringLiteral createStringLiteral(String value) {
    return fac.simpleStringLiteral(createStringToken(value), '');
  }

  Block createBlock(List<Statement> statements) {
    return fac.block(new SimpleToken(TokenType.OPEN_CURLY_BRACKET, 0),
        statements, new SimpleToken(TokenType.CLOSE_CURLY_BRACKET, 0));
  }
}
