part of "main.dart";

FunctionExpressionInvocation generateTree(
    AstFactoryImpl fac, ComponentTreeNode app,
    {String subName}) {
  var attrs = app.attrs.where((i) => !i.startsWith("slot@@@"));
  var children = app.children;
  var slots = app.slots;
  List<NamedExpression> content = [];
  for (var child in children) {
    if (slots.length > 0) {
      // var slot = slots.firstWhere((sl)=> sl.startsWith())
      // var ss = slot.split("###");
      // var sn = ss.elementAt(1).split("@@@");
      // var slotName = ss.elementAt(0);
      // var compNs = sn[0] == "__no_ns__" ? null : sn[0];
      // var compName = sn[1];
      // var targetChild = children.firstWhere(
      //     (c) => c.name == compName && c.ns == compNs,
      //     orElse: () => null);
      // if (targetChild == null) {
      //   throw UnsupportedError(
      //       "generate tree node failed -> node ${app.fullname}'s slot [$slotName] not found");
      // }
      // content.add(fac.namedExpression(
      //     fac.label(
      //         fac.simpleIdentifier(
      //             new StringToken(TokenType.STRING, slotName, 0)),
      //         new SimpleToken(TokenType.COLON, 0)),
      //     generateTree(fac, targetChild)));
    }
  }
  if (slots.length > 0) {
    for (var slot in slots) {
      var result = parsePairInfo(slot);
      var targetChild = children.firstWhere(
          (c) => c.name == result.name && c.ns == result.ns,
          orElse: () => null);
      if (targetChild == null) {
        throw UnsupportedError(
            "generate tree node failed -> node ${app.fullname}'s slot [${result.slot}] not found");
      }
      content.add(fac.namedExpression(
          fac.label(
              fac.simpleIdentifier(
                  new StringToken(TokenType.STRING, result.slot, 0)),
              new SimpleToken(TokenType.COLON, 0)),
          generateTree(fac, targetChild)));
    }
  }
  return fac.functionExpressionInvocation(
      fac.simpleIdentifier(
          new StringToken(TokenType.IDENTIFIER, app.fullname, 0)),
      null,
      fac.argumentList(null, content, null));
}

FunctionDeclaration generateBuildFn(
    AstFactoryImpl fac,
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
      fac.simpleIdentifier(new StringToken(TokenType.STRING, "__build", 0)),
      fac.functionExpression(
          null,
          fac.formalParameterList(
            null,
            invokeParams.map((i) {
              var paramName = i.name;
              var isThis = paramName == "this";
              var isContext = paramName == "context";
              var typeName =
                  isThis ? className : isContext ? "BuildContext" : "dynamic";
              var param = fac.simpleFormalParameter(
                  null,
                  null,
                  null,
                  fac.typeName(
                      fac.simpleIdentifier(
                          new StringToken(TokenType.STRING, typeName, 0)),
                      null),
                  fac.simpleIdentifier(new StringToken(
                      TokenType.STRING, isThis ? "_delegate" : paramName, 0)));
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
