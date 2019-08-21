import 'dart:io';
import 'package:xml/xml.dart' as xml;

import 'app.dart';

final FLUTTER = "https://github.com/flutter/flutter/wiki";
final XDML = "https://github.com/miao17game/xdml/wiki/xdml";

class DartReference {
  String type;
  String name;
  String alias = null;
  DartReference(this.type, this.name, this.alias);

  get reference => "$type:$name";

  @override
  String toString() {
    return "DartReference -> $type:$name";
  }
}

class DocumentParesResult {
  List<String> libraries = [];
  List<DartReference> references = [];
  Map<String, String> namespaces = {};
  ComponentTreeNode app = null;
  DocumentParesResult();
}

DocumentParesResult parseXmlDocument(String xdmlPath, String viewPath) {
  File xdml = new File(xdmlPath);
  var xmlDocument = xml.parse(xdml.readAsStringSync());
  var mains = xmlDocument.findElements("Page", namespace: "dart").toList();
  if (mains == null || mains.length == 0) {
    throw new UnsupportedError(
        "resolve xdml $viewPath file failed => XDML Page declaration not found");
  }

  var main = mains.elementAt(0);
  var attrs = main.attributes.toList();
  List<String> libraries = [];
  List<DartReference> references = [];
  Map<String, String> namespaces = {};

  for (var attr in attrs) {
    var refName = attr.name.toString();
    var refValue = attr.value;
    if (refName.startsWith("xmlns:")) {
      var alias = refName.replaceAll("xmlns:", "");
      namespaces[refValue] = alias;
      if (refValue == XDML || refValue == FLUTTER) {
        continue;
      }
      var splits = refValue.split(":");
      var type = splits.elementAt(0);
      var name = splits.elementAt(1);
      references.add(new DartReference(type, name, alias));
    }
  }

  if (!namespaces.containsKey(XDML)) {
    throw new UnsupportedError(
        "resolve xdml $viewPath file failed => dart namespace not found");
  }

  var refNodes = main.findAllElements("Reference", namespace: XDML).toList();
  if (refNodes != null && refNodes.length > 0) {
    var refRoot = refNodes.elementAt(0);
    refRoot.children.where((e) => e is xml.XmlElement).forEach((child) {
      xml.XmlElement thisNode = child;
      var name = thisNode.name;
      if (name.namespaceUri.trim() != XDML) return;
      var childAttrs = thisNode.attributes;
      var nameAttr = childAttrs.firstWhere((i) => i.name.toString() == "name",
          orElse: () => null);
      if (nameAttr != null) {
        if (name.local == "Library") {
          libraries.add(nameAttr.value);
          return;
        }
        var type = name.local == "Internal" ? "dart" : "package";
        references.add(new DartReference(type, nameAttr.value, null));
      }
    });
  }

  xml.XmlElement appRoot = null;
  var childrenNodes = main.children.where((i) => i is xml.XmlElement).toList();
  if (childrenNodes.length == 1) {
    appRoot = childrenNodes.elementAt(0);
  } else if (childrenNodes.length > 1) {
    appRoot = childrenNodes.elementAt(1);
  } else {
    throw new UnsupportedError(
        "resolve xdml $viewPath file failed => app root not found");
  }

  var app = resolveApp(references, namespaces, libraries, appRoot);

  var result = new DocumentParesResult();
  result.libraries = libraries;
  result.namespaces = namespaces;
  result.references = references;
  result.app = app;

  return result;
}
