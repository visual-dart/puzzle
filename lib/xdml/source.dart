import 'dart:core';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:front_end/src/scanner/token.dart';

typedef void OnRenderBuild(List<SimpleIdentifier> params);

CompilationUnitMember wrapBuildMethod(CompilationUnitMember i, String className,
    AstFactoryImpl fac, OnRenderBuild onRender) {
  if (i is ClassDeclaration && i.name.name == className) {
    var buildFn = i.getMethod("build");
    if (buildFn == null) {
      throw new UnsupportedError(
          "resolve widget $className's build method failed => no such method");
    }
    Block block = buildFn.body.childEntities.toList().elementAt(0);
    var variables =
        block.statements.where((s) => s is VariableDeclarationStatement);

    var returns = block.statements.where((s) => s is ReturnStatement);
    if (returns.isEmpty) {
      throw new UnsupportedError(
          "resolve widget $className's build method failed => method no return is invalid");
    }
    ReturnStatement returnState = returns.elementAt(0);

    var newArguments = [
      fac.simpleIdentifier(new StringToken(TokenType.STRING, "this", 0)),
      fac.simpleIdentifier(new StringToken(TokenType.STRING, "context", 0)),
    ];
    variables.forEach((vb) {
      VariableDeclarationStatement statement = vb;
      newArguments.addAll(statement.variables.variables.map((vari) {
        return fac.simpleIdentifier(
            new StringToken(TokenType.STRING, vari.name.name, 0));
      }));
    });
    onRender(newArguments);
    var functionInvoke = fac.functionExpressionInvocation(
        fac.simpleIdentifier(
            new StringToken(TokenType.IDENTIFIER, "bindXDML", 0)),
        null,
        fac.argumentList(new SimpleToken(TokenType.LT, 0), newArguments,
            new SimpleToken(TokenType.LT, 0)));

    var otherMembers = i.members
        .where((i) => !(i is MethodDeclaration && i.name.name == "build"))
        .toList();
    List<Statement> finalStatements = [];
    finalStatements
        .addAll(block.statements.sublist(0, block.statements.length - 1));
    finalStatements.add(fac.returnStatement(
        returnState.returnKeyword, functionInvoke, returnState.semicolon));

    otherMembers.add(fac.methodDeclaration(
        buildFn.documentationComment,
        buildFn.metadata,
        buildFn.externalKeyword,
        buildFn.modifierKeyword,
        buildFn.returnType,
        buildFn.propertyKeyword,
        buildFn.operatorKeyword,
        buildFn.name,
        buildFn.typeParameters,
        buildFn.parameters,
        fac.blockFunctionBody(
            buildFn.body.keyword,
            buildFn.body.star,
            fac.block(
                block.leftBracket, finalStatements, block.rightBracket))));
    return fac.classDeclaration(
        i.documentationComment,
        i.metadata,
        i.abstractKeyword,
        i.classKeyword,
        i.name,
        i.typeParameters,
        i.extendsClause,
        i.withClause,
        i.implementsClause,
        i.leftBracket,
        otherMembers,
        i.rightBracket);
  } else {
    return i;
  }
}
