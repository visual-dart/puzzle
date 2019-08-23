import 'dart:io';
import 'package:xml/xml.dart' as xml;

import 'app.dart';

final FLUTTER = "https://github.com/flutter/flutter/wiki";
final XDML = "https://github.com/miao17game/xdml/wiki/xdml";
final BIND = "https://github.com/miao17game/xdml/wiki/bind";

bool isInternalNs(String namespaceUri) {
  return namespaceUri == FLUTTER ||
      namespaceUri == XDML ||
      namespaceUri == BIND;
}

class DartReference {
  String type = null;
  String name;
  String alias = null;
  DartReference(this.type, this.name, this.alias);

  get reference => type == null ? name : "$type:$name";

  @override
  String toString() {
    return "DartReference -> $type:$name";
  }
}

class ElementParesResult {
  final ComponentTreeNode host;
  ComponentTreeNode parent = null;
  ElementParesResult(this.host);
}

class DocumentParesResult extends ElementParesResult {
  Map<String, ElementParesResult> templates = {};
  List<DartReference> references = [];
  Map<String, String> namespaces = {};
  DocumentParesResult(host) : super(host);

  void addTemplate(String name, ComponentTreeNode template) {
    templates[name] = new ElementParesResult(template)..parent = this.host;
  }
}

DocumentParesResult parseXmlDocument(String xdmlPath, String viewPath) {
  File xdml = new File(xdmlPath);
  var xmlDocument = xml.parse(xdml.readAsStringSync());
  var mains = xmlDocument.findElements("Page", namespace: XDML).toList();
  if (mains == null || mains.isEmpty) {
    throw new UnsupportedError(
        "resolve xdml $viewPath file failed => XDML Page declaration not found");
  }

  var main = mains.elementAt(0);
  var attrs = main.attributes.toList();
  List<DartReference> references = [];
  Map<String, String> namespaces = {};

  for (var attr in attrs) {
    var refName = attr.name.toString();
    var refValue = attr.value;
    if (refName.startsWith("xmlns:")) {
      var alias = refName.replaceAll("xmlns:", "");
      namespaces[refValue] = alias;
      if (isInternalNs(refValue)) {
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
  if (refNodes != null && refNodes.isNotEmpty) {
    var refRoot = refNodes.elementAt(0);
    refRoot.children.where((e) => e is xml.XmlElement).forEach((child) {
      xml.XmlElement thisNode = child;
      var name = thisNode.name;
      if (name.namespaceUri != XDML) return;
      if (name.local == "Import") {
        var childAttrs = thisNode.attributes;
        var pathUri = childAttrs.firstWhere((i) => i.name.toString() == "path",
            orElse: () => null);
        if (pathUri != null) {
          var secs = pathUri.value.split(":");
          if (secs.length > 1) {
            references.add(
                new DartReference(secs.elementAt(0), secs.elementAt(1), null));
          } else {
            references.add(new DartReference(null, secs.elementAt(0), null));
          }
        }
      }
    });
  }

  xml.XmlElement appRoot = null;
  var childrenNodes = main.children.where((i) => i is xml.XmlElement).toList();
  List<Map<String, dynamic>> templateRefs = [];
  if (childrenNodes.length == 1) {
    appRoot = childrenNodes.elementAt(0);
  } else if (childrenNodes.length > 1) {
    List<xml.XmlNode> elements =
        childrenNodes.where((i) => i is xml.XmlElement).toList();
    for (var ele in elements) {
      if (ele is xml.XmlElement &&
          ele.name.local == "Template" &&
          ele.name.namespaceUri == XDML) {
        // print(local);
        var refName = ele.attributes.firstWhere(
            (i) => i.name.namespaceUri == XDML && i.name.local == "ref",
            orElse: () => null);
        if (refName != null && ele.children.isNotEmpty) {
          ele.normalize();
          var firstElement = ele.children
              .firstWhere((e) => e is xml.XmlElement, orElse: () => null);
          if (firstElement != null) {
            templateRefs.add({"name": refName.value, "element": firstElement});
          } else {
            templateRefs.add({
              "name": refName.value,
              "element": ele.children.elementAt(0).toString()
            });
          }
          continue;
        }
      }
      var attrs = ele.attributes;
      // 不要重复查找host
      var hostBuild = appRoot != null
          ? null
          : attrs.firstWhere(
              (i) =>
                  i.name.namespaceUri == XDML &&
                  i.name.local == "host" &&
                  i.value == "build",
              orElse: () => null);
      if (hostBuild != null) {
        appRoot = ele;
        continue;
      }
    }
  }

  if (appRoot == null) {
    throw new UnsupportedError(
        "resolve xdml $viewPath file failed => app root not found");
  }

  var app = resolveApp(references, namespaces, appRoot);

  var result = new DocumentParesResult(app)
    ..namespaces = namespaces
    ..references = references;

  for (var tpl in templateRefs) {
    var ele = tpl["element"];
    var name = tpl["name"];
    if (ele == null || name == null) continue;
    if (ele is xml.XmlElement) {
      result.addTemplate(name, resolveApp(references, namespaces, ele));
    } else {
      result.addTemplate(
          name, resolveApp(references, namespaces, new xml.XmlText(ele)));
    }
  }

  return result;
}
