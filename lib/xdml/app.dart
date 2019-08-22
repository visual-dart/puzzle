import 'dart:core';

import 'package:xml/xml.dart' as xml;

import 'base.dart';

class ComponentTreeNode {
  bool internal = false;
  String ns = null;
  String name;
  ComponentTreeNode parent = null;
  List<ComponentTreeNode> children = [];
  List<String> attrs = [];
  List<String> slots = [];
  String innerText = null;
  ComponentTreeNode(this.internal, this.name, this.ns, this.attrs,
      this.children, this.innerText, this.parent);

  get fullname => ns == null ? name : "${ns}:${name}";
}

ComponentTreeNode resolveApp(
    List<DartReference> references,
    Map<String, String> namespaces,
    List<String> libraries,
    xml.XmlElement appRoot) {
  var internal = false;
  var rootName = appRoot.name.local;
  var nsUri = appRoot.name.namespaceUri;
  var hasNs = namespaces.containsKey(nsUri);
  var rootNs = namespaces[nsUri];
  // print("${hasNs ? "$rootNs:" : ""}$rootName");
  // 内置节点类型
  if (nsUri == XDML) {
    internal = true;
  }
  appRoot.normalize();
  var attrs = appRoot.attributes
      .map((attr) => "${attr.name.toString()}@@@${attr.value}")
      .toList();
  var isText = rootName == "Text" && !hasNs;
  List<ComponentTreeNode> children = isText
      ? []
      : appRoot.children
          .where((n) => n is xml.XmlElement)
          .map((i) => resolveApp(references, namespaces, libraries, i))
          .toList();
  var node = new ComponentTreeNode(
      internal,
      rootName,
      hasNs ? rootNs : null,
      attrs,
      [],
      isText ? appRoot.children.elementAt(0).toString() : null,
      null);
  for (var c in children) {
    c.parent = node;
    var idx = children.indexOf(c);
    var slot =
        c.attrs.firstWhere((t) => t.startsWith("slot@@@"), orElse: () => null);
    if (slot != null) {
      node.slots.add(
          "${slot.replaceAll("slot@@@", "")}###${c.ns == null ? "__no_ns__" : c.ns}@@@${c.name}&&&$idx");
    }
  }
  node.children = children;
  return node;
}

class PairInfo {
  String slot;
  String ns = null;
  String name;
  int index = -1;
  PairInfo(this.slot, this.name);
}

PairInfo parsePairInfo(String pairSrr) {
  var ss = pairSrr.split("###");
  var sn = ss.elementAt(1).split("@@@");
  var sm = sn.elementAt(1).split("&&&");
  var slotName = ss.elementAt(0);
  var compNs = sn.elementAt(0) == "__no_ns__" ? null : sn.elementAt(0);
  var compName = sm.elementAt(0);
  var idx = int.parse(sm.elementAt(1));
  var pair = new PairInfo(slotName, compName);
  if (compNs != null) pair.ns = compNs;
  if (idx >= 0) pair.index = idx;
  return pair;
}
