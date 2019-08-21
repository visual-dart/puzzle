part of "main.dart";

FunctionExpressionInvocation generateTree(
    AstFactoryImpl fac, ComponentTreeNode app,
    {String subName}) {
  var attrs = app.attrs.where((i) => !i.startsWith("slot@@@"));
  var children = app.children;
  var slots = app.slots;
  var text = app.innerText;
  List<Expression> content = [];
  if (text != null) {
    var insert = parseInsertExpression(text);
    content.add(fac
        .simpleIdentifier(new StringToken(TokenType.STRING, insert.value, 0)));
  } else {
    for (var attr in attrs) {
      var nss = attr.split("@@@");
      var insert = parseInsertExpression(nss.elementAt(1));
      content.add(fac.namedExpression(
          fac.label(
              fac.simpleIdentifier(
                  new StringToken(TokenType.STRING, nss.elementAt(0), 0)),
              new SimpleToken(TokenType.COLON, 0)),
          fac.simpleIdentifier(
              new StringToken(TokenType.STRING, insert.value, 0))));
    }
    for (var child in children) {
      var childIdx = children.indexOf(child);
      if (slots.length > 0) {
        var slot = slots.firstWhere((sl) => sl.endsWith("&&&$childIdx"),
            orElse: () => null);
        // 没找到当前位置的slot，为普通child，暂时不处理
        if (slot == null) continue;
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
  }
  return fac.functionExpressionInvocation(
      fac.simpleIdentifier(
          new StringToken(TokenType.IDENTIFIER, app.fullname, 0)),
      null,
      fac.argumentList(null, content, null));
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
      if (insertValue.startsWith("this.")) {
        return "_delegate." + insertValue.substring(5);
      }
      return insertValue;
    } else {
      return matched.input;
    }
  });
  return new InsertResult(valid, valid ? newExpression : "'$newExpression'");
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
