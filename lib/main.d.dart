part of "main.dart";

List<List<String>> parseArguments(List<String> arguments) {
  List<List<String>> argus = [];
  for (var arg in arguments) {
    if (arg.startsWith("--")) {
      argus.add(arg.replaceAll("--", "").split("="));
    }
  }
  return argus;
}

class BuildTransformer extends RecursiveAstVisitor<dynamic> {
  AstNode node;
  BuildTransformer(this.node) {
    node.visitChildren(this);
  }

  @override
  dynamic visitClassDeclaration(node) {
    // print(node.childEntities.map((e) => e.toString()).join(("\n")));
    // print(node.childEntities.map((e) => e.runtimeType.toString()).join(("\n")));
    // print("=========");
    // var methods = node.childEntities
    //     .where((e) => e.runtimeType.toString() == "MethodDeclarationImpl");
    // print("=========");
    if (node.metadata.length > 0) {
      var decoArgs = node.metadata[0].arguments;
      var ctorName = node.metadata[0].constructorName;
      print("$decoArgs - $ctorName");
      node.visitChildren(this);
    }
    return null;
  }
}
