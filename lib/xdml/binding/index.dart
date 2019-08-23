import 'dart:core';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:front_end/src/scanner/token.dart';

import '../app.dart';
import 'process.dart';

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
