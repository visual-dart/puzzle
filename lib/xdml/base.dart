import 'dart:io';
import 'package:xml/xml.dart';

import 'app.dart';
import 'vnode.dart';

final FLUTTER = "https://github.com/flutter/flutter/wiki";
final XDML = "https://github.com/miao17game/xdml/wiki/xdml";
final BIND = "https://github.com/miao17game/xdml/wiki/bind";

/** XDML内置节点 */
class XDMLNodes {
  /** 视图单元 */
  static const ViewUnit = "ViewUnit";
  /** 视图函数 */
  static const ViewBuilder = "ViewBuilder";
  /** 导入声明 */
  static const Import = "Import";
  /** 引用集合 */
  static const ReferenceGroup = "ReferenceGroup";
  /** 节点数组 */
  static const NodeList = "NodeList";
  /** 根页面 */
  static const Page = "Page";
  /** 逃逸字符串，不被插值解析 */
  static const EscapeText = "EscapeText";
  /** 表达式文本，被插值解析 */
  static const ExpressionText = "ExpressionText";
  /** 可执行代码行 */
  static const Execution = "Execution";
  /** 临时变量上下文，承载临时虚拟变量表达式 */
  static const VirtualContext = "Virtual";
  /** 临时变量，不具备独立输出的能力，只能在条件语句中插值 */
  static const VirtualVariable = "VirtualVariable";
}

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
  Map<String, ElementParesResult> generators = {};
  List<DartReference> references = [];
  Map<String, String> namespaces = {};
  DocumentParesResult(host) : super(host);

  void addTemplate(String name, ComponentTreeNode template) {
    templates[name] = new ElementParesResult(template)..parent = this.host;
  }

  void addGenerator(String name, ComponentTreeNode generator) {
    generators[name] = new ElementParesResult(generator)..parent = this.host;
  }
}

DocumentParesResult parseXmlDocument(String xdmlPath, String viewPath) {
  File xdml = new File(xdmlPath);
  var xmlDocument = parse(xdml.readAsStringSync());
  var mains =
      xmlDocument.findElements(XDMLNodes.Page, namespace: XDML).toList();
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

  var refNodes = main.children
      .where((i) => i.name == XDMLNodes.ReferenceGroup && i.ns == XDML);
  if (refNodes != null && refNodes.isNotEmpty) {
    var refRoot = refNodes.elementAt(0);
    refRoot.children.where((e) => e is VNodeElement).forEach((child) {
      VNodeElement thisNode = child;
      if (thisNode.ns != XDML) return;
      if (thisNode.name == XDMLNodes.Import) {
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
  List<Map<String, dynamic>> viewGenerators = [];
  if (childrenNodes.length == 1) {
    appRoot = childrenNodes.elementAt(0);
  } else if (childrenNodes.length > 1) {
    for (var ele in childrenNodes) {
      if (isXDMLPartialView(ele)) {
        // print(local);
        var refName = getTemplateRefName(ele);
        if (refName != null && ele.children.isNotEmpty) {
          templateRefs.add(mapElementNode(ele, refName));
        }
        continue;
      } else if (isXDMLPartialGenerator(ele)) {
        var refName = getTemplateRefName(ele);
        if (refName != null && ele.children.isNotEmpty) {
          viewGenerators.add({"name": refName.value, "element": ele});
        }
        continue;
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

  for (var tpl in viewGenerators) {
    var ele = tpl["element"];
    var name = tpl["name"];
    if (ele == null || name == null) continue;
    // print(ele);
    result.addGenerator(name, resolveApp(references, namespaces, ele));
  }

  return result;
}

Map<String, dynamic> mapElementNode(VNode ele, VNodeAttr refName) {
  var firstElement = getFirstElement(ele);
  if (firstElement != null) {
    var item = {"name": refName.value, "element": firstElement};
    return item;
  } else {
    var item = {"name": refName.value, "element": ele.children.elementAt(0)};
    return item;
  }
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
  // x：前缀不必要
  return ele.attrs.firstWhere((i) => /* i.ns == XDML &&*/ i.name == "ref",
      orElse: () => null);
}

bool isXDMLPartialView(VNode ele) {
  return ele is VNodeElement &&
      ele.name == XDMLNodes.ViewUnit &&
      ele.ns == XDML;
}

bool isXDMLPartialGenerator(VNode ele) {
  return ele is VNodeElement &&
      ele.name == XDMLNodes.ViewBuilder &&
      ele.ns == XDML;
}

bool isVirtualVariable(VNode ele) {
  return ele is VNodeElement &&
      (ele.name.startsWith(XDMLNodes.VirtualContext) ||
          ele.name == XDMLNodes.VirtualVariable) &&
      ele.ns == XDML;
}
