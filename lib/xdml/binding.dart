import 'dart:core';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:front_end/src/scanner/token.dart';

import 'app.dart';

Expression generateTree(AstFactory fac, ComponentTreeNode app,
    {String subName}) {
  var internal = app.internal;
  var attrs = app.attrs.where((i) => !i.startsWith("slot@@@"));
  var children = app.children;
  var slots = app.slots;
  var text = app.innerText;
  List<Expression> content = [];

  if (text != null) {
    insertTextNode(fac, internal, content, text);
  } else {
    insertCommonNode(fac, internal, content, attrs, children, slots, app);
  }
  if (internal) {
    if (app.name == "NodeList") {
      var type =
          attrs.firstWhere((i) => i.startsWith("type@@@"), orElse: () => null);
      var typeMeta = type?.split("@@@")?.elementAt(1);
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
  }
  return fac.functionExpressionInvocation(
      fac.simpleIdentifier(
          new StringToken(TokenType.IDENTIFIER, app.fullname, 0)),
      null,
      fac.argumentList(null, content, null));
}

void insertCommonNode(
    AstFactory fac,
    bool internal,
    List<Expression> content,
    Iterable<String> attrs,
    List<ComponentTreeNode> children,
    List<String> slots,
    ComponentTreeNode app) {
  if (!internal) {
    for (var attr in attrs) {
      var nss = attr.split("@@@");
      var insert = parseInsertExpression(nss.elementAt(1));
      content.add(createNamedParamByAttr(fac, nss.elementAt(0), insert));
    }
  }
  List<Expression> slotNodes = [];
  List<Expression> queueNodes = [];
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
  content.addAll(queueNodes);
  content.addAll(slotNodes);
}

void insertTextNode(
    AstFactory fac, bool internal, List<Expression> content, String text) {
  var insert = parseInsertExpression(text);
  content.add(
      fac.simpleIdentifier(new StringToken(TokenType.STRING, insert.value, 0)));
}

Expression createNormalParamByChildNode(
    AstFactory fac, Iterable<String> attrs, ComponentTreeNode targetChild) {
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
    AstFactory fac, String slotName, InsertResult insert) {
  return fac.namedExpression(
      fac.label(
          fac.simpleIdentifier(new StringToken(TokenType.STRING, slotName, 0)),
          new SimpleToken(TokenType.COLON, 0)),
      fac.simpleIdentifier(new StringToken(TokenType.STRING, insert.value, 0)));
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
              // var isThis = paramName == "this";
              var isContext = paramName == "context";
              var typeName =
                  /* isThis ? className :*/ isContext
                      ? "BuildContext"
                      : "dynamic";
              var param = fac.simpleFormalParameter(
                  null,
                  null,
                  null,
                  fac.typeName(
                      fac.simpleIdentifier(
                          new StringToken(TokenType.STRING, typeName, 0)),
                      null),
                  fac.simpleIdentifier(new StringToken(
                      TokenType.STRING,
                      /*isThis ? "_delegate" :*/ paramName,
                      0)));
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
