import 'dart:io';
import 'package:xml/xml.dart';

import 'app.dart';
import 'vnode.dart';

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
  var xmlDocument = parse(xdml.readAsStringSync());
  var mains = xmlDocument.findElements("Page", namespace: XDML).toList();
  if (mains == null || mains.isEmpty) {
    throw new UnsupportedError(
        "resolve xdml $viewPath file failed => XDML Page declaration not found");
  }

  var main = VNode.fromNode(mains.elementAt(0));
  var attrs = main.attrs;
  List<DartReference> references = [];
  Map<String, String> namespaces = {};

  for (var attr in attrs) {
    var refName = attr.name;
    var refValue = attr.value;
    if (attr.nsLabel == "xmlns") {
      namespaces[refValue] = refName;
      if (isInternalNs(refValue)) {
        continue;
      }
      var splits = refValue.split(":");
      var type = splits.elementAt(0);
      var name = splits.elementAt(1);
      references.add(new DartReference(type, name, refName));
    }
  }

  if (!namespaces.containsKey(XDML)) {
    throw new UnsupportedError(
        "resolve xdml $viewPath file failed => dart namespace not found");
  }

  var refNodes =
      main.children.where((i) => i.name == "Reference" && i.ns == XDML);
  if (refNodes != null && refNodes.isNotEmpty) {
    var refRoot = refNodes.elementAt(0);
    refRoot.children.where((e) => e is VNodeElement).forEach((child) {
      VNodeElement thisNode = child;
      if (thisNode.ns != XDML) return;
      if (thisNode.name == "Import") {
        var childAttrs = thisNode.attrs;
        var pathUri =
            childAttrs.firstWhere((i) => i.name == "path", orElse: () => null);
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

  VNode appRoot = null;
  var childrenNodes = main.children.where((i) => i is VNodeElement).toList();
  List<Map<String, dynamic>> templateRefs = [];
  if (childrenNodes.length == 1) {
    appRoot = childrenNodes.elementAt(0);
  } else if (childrenNodes.length > 1) {
    for (var ele in childrenNodes) {
      if (isXDMLTemplate(ele)) {
        // print(local);
        var refName = getTemplateRefName(ele);
        if (refName != null && ele.children.isNotEmpty) {
          var firstElement = getFirstElement(ele);
          if (firstElement != null) {
            templateRefs.add({"name": refName.value, "element": firstElement});
          } else {
            templateRefs.add(
                {"name": refName.value, "element": ele.children.elementAt(0)});
          }
          continue;
        }
      }
      var attrs = ele.attrs;
      // 不要重复查找host
      var hostBuild = appRoot != null ? null : getHostBuildNode(attrs);
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
    result.addTemplate(name, resolveApp(references, namespaces, ele));
  }

  return result;
}

VNodeAttr getHostBuildNode(List<VNodeAttr> attrs) {
  return attrs.firstWhere(
      (i) => i.ns == XDML && i.name == "host" && i.value == "build",
      orElse: () => null);
}

VNodeElement getFirstElement(VNodeElement ele) {
  return ele.children.firstWhere((e) => e is VNodeElement, orElse: () => null);
}

VNodeAttr getTemplateRefName(VNode ele) {
  return ele.attrs
      .firstWhere((i) => i.ns == XDML && i.name == "ref", orElse: () => null);
}

bool isXDMLTemplate(VNode ele) {
  return ele is VNodeElement && ele.name == "Template" && ele.ns == XDML;
}
