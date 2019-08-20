part of "main.dart";

typedef void OnHandle({@required String viewPath});

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
  OnHandle handler;
  BuildTransformer(this.node, this.handler) {
    node.visitChildren(this);
  }

  @override
  dynamic visitClassDeclaration(node) {
    if (node.metadata != null && node.metadata.length > 0) {
      var decos = _readDecorator(node.metadata);
      decos.forEach((name, deco) {
        if (name != 'Binding') return;
        List<String> a = deco['arguments'];
        print("deco => name : $name ; arguments : $a");
        handler(viewPath: a[0].substring(1, a[0].length - 1));
      });
      return null;
    }
    return null;
  }

  Map<String, Map<String, dynamic>> _readDecorator(List<Annotation> annos) {
    Map<String, Map<String, dynamic>> results = {};
    for (var anno in annos) {
      Map<String, dynamic> data = {};
      for (var item in anno.childEntities) {
        if (item is SimpleIdentifierImpl) {
          data['name'] = item.name;
        }
        if (item is ArgumentListImpl) {
          print(item.arguments);
          print(item.arguments.toList().runtimeType);
          data['arguments'] = item.arguments.map((i) => i.toSource()).toList();
        }
      }
      results[data['name']] = data;
    }
    return results;
  }
}
