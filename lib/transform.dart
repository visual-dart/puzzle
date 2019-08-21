import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

typedef void OnHandle({String viewPath, dynamic sourceFile, String className});

class BuildTransformer extends RecursiveAstVisitor<dynamic> {
  AstNode node;
  OnHandle handler;
  BuildTransformer(this.node, this.handler) {}

  call() {
    node.visitChildren(this);
  }

  @override
  dynamic visitClassDeclaration(node) {
    if (node.metadata != null && node.metadata.length > 0) {
      var decos = _readDecorator(node.metadata);
      decos.forEach((name, deco) {
        if (name != 'Binding') return;
        List<String> a = deco['arguments'];
        // print("deco => name : $name ; arguments : $a");
        handler(
            className: node.name.name,
            viewPath: a[0].substring(1, a[0].length - 1),
            sourceFile: this.node);
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
        if (item is SimpleIdentifier) {
          data['name'] = item.name;
        }
        if (item is ArgumentList) {
          // print(item.arguments);
          // print(item.arguments.toList().runtimeType);
          data['arguments'] = item.arguments.map((i) => i.toSource()).toList();
        }
      }
      results[data['name']] = data;
    }
    return results;
  }
}
