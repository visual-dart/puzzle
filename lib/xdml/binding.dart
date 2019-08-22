import 'dart:core';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:front_end/src/scanner/token.dart';

import 'app.dart';

Expression generateTree(AstFactory fac, ComponentTreeNode app,
    {String subName}) {
  var internal = app.internal;
  var attrs = app.attrs.where((i) => !isXDMLSlot(i));
  var children = app.children;
  var slots = app.slots;

  List<Expression> content = app.innerText != null
      ? insertTextNode(fac, internal, app.innerText)
      : insertCommonNode(fac, internal, attrs, children, slots, app);

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
    AstFactory fac, ComponentTreeNode app, List<Expression> content) {
  return fac.functionExpressionInvocation(
      fac.simpleIdentifier(
          new StringToken(TokenType.IDENTIFIER, app.fullname, 0)),
      null,
      fac.argumentList(null, content, null));
}

ListLiteral createNodeList(
    AstFactory fac, Iterable<AttributeNode> attrs, List<Expression> content) {
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
  return fac.listLiteral(null, typeList, null, content, null);
}

List<Expression> insertCommonNode(
    AstFactory fac,
    bool internal,
    Iterable<AttributeNode> attrs,
    List<ComponentTreeNode> children,
    List<String> slots,
    ComponentTreeNode app) {
  List<Expression> attrNodes = [];
  List<Expression> slotNodes = [];
  List<Expression> queueNodes = [];

  // 内部节点无视attrs属性
  if (!internal) {
    for (var attr in attrs) {
      var insert = isInsertBind(attr)
          ? attr.value
          : parseInsertExpression(attr.value).value;
      attrNodes.add(createNamedParamByAttr(fac, attr.name, insert));
    }
  }
  for (var child in children) {
    var childIdx = children.indexOf(child);
    var slot = slots.firstWhere((sl) => sl.endsWith("&&&$childIdx"),
        orElse: () => null);
    if (slot != null && !internal) {
      var result = parsePairInfo(slot);
      var targetChild = children.firstWhere(
          (c) => c.name == result.name && c.ns == result.ns,
          orElse: () => null);
      if (targetChild == null) {
        throw UnsupportedError(
            "generate tree node failed -> node ${app.fullname}'s slot [${result.slot}] not found");
      }
      slotNodes.add(createNamedParamByChildNode(fac, result.slot, targetChild));
    } else {
      queueNodes.add(createNormalParamByChildNode(fac, attrs, child));
    }
  }

  List<Expression> content = [];
  // 节点优先级，slot节点靠后
  content.addAll(attrNodes);
  content.addAll(queueNodes);
  content.addAll(slotNodes);
  return content;
}

List<Expression> insertTextNode(AstFactory fac, bool internal, String text) {
  List<Expression> content = [];
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
    AstFactory fac, String slotName, ComponentTreeNode targetChild) {
  return fac.namedExpression(
      fac.label(
          fac.simpleIdentifier(new StringToken(TokenType.STRING, slotName, 0)),
          new SimpleToken(TokenType.COLON, 0)),
      generateTree(fac, targetChild));
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
