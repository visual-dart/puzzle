import 'dart:core';

import 'package:xml/xml.dart' as xml;

import 'base.dart';

class AttributeNode {
  bool internal = false;
  String ns = null;
  String nsUri = null;
  String name;
  String value;
  AttributeNode(this.internal, this.name, this.ns, this.nsUri, this.value);

  String get fullname => ns == null ? name : "${ns}:${name}";

  AttributeNode fork() {
    return new AttributeNode(internal, name, ns, nsUri, value);
  }
}

class SlotNode {
  String ns = null;
  String nsUri = null;
  String target;
  String value;
  int index;
  SlotNode(this.ns, this.nsUri, this.target, this.value, this.index);

  SlotNode fork() {
    return new SlotNode(ns, nsUri, target, value, index);
  }
}

class ComponentTreeNode {
  bool internal = false;
  String ns = null;
  String nsUri = null;
  String name;
  ComponentTreeNode parent = null;
  List<ComponentTreeNode> children = [];
  List<AttributeNode> attrs = [];
  List<SlotNode> slots = [];
  String innerText = null;
  ComponentTreeNode(this.internal, this.name, this.ns, this.nsUri, this.attrs,
      this.children, this.innerText, this.parent);

  String get fullname => ns == null ? name : "${ns}:${name}";

  ComponentTreeNode fork() {
    return new ComponentTreeNode(
        internal, name, ns, nsUri, [], [], innerText, parent?.fork())
      ..attrs = attrs.map((a) => a.fork()).toList()
      ..slots = slots.map((a) => a.fork()).toList()
      ..children = children.map((a) => a.fork()).toList();
  }
}

ComponentTreeNode resolveApp(List<DartReference> references,
    Map<String, String> namespaces, xml.XmlElement appRoot) {
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
      .map((attr) => createAttribute(attr, namespaces))
      .toList();
  var isText = rootName == "Text" && !hasNs;
  List<ComponentTreeNode> children = isText
      ? []
      : appRoot.children
          .where((n) => n is xml.XmlElement)
          .map((i) => resolveApp(references, namespaces, i))
          .toList();
  var node = new ComponentTreeNode(
      internal,
      rootName,
      hasNs ? rootNs : null,
      hasNs ? nsUri : null,
      attrs,
      [],
      isText ? appRoot.children.elementAt(0).toString() : null,
      null);
  for (var c in children) {
    c.parent = node;
    var idx = children.indexOf(c);
    var slot = c.attrs.firstWhere((t) => isXDMLSlot(t), orElse: () => null);
    if (slot != null) {
      node.slots.add(new SlotNode(c.ns, c.nsUri, slot.value, c.name, idx));
    }
  }
  node.children = children;
  return node;
}

AttributeNode createAttribute(
    xml.XmlAttribute attr, Map<String, String> namespaces) {
  var attrName = attr.name.local;
  var attrNsUri = attr.name.namespaceUri;
  var hasAttrNs = namespaces.containsKey(attrNsUri);
  return new AttributeNode(
      attrNsUri == XDML || attrNsUri == BIND,
      attrName,
      hasAttrNs ? namespaces[attrNsUri] : null,
      hasAttrNs ? attrNsUri : null,
      attr.value);
}

bool isXDMLSlot(AttributeNode t) {
  return t.name == "slot" && t.nsUri == XDML;
}

bool isInsertBind(AttributeNode t) {
  return t.nsUri == BIND;
}

bool isStatementIf(AttributeNode t) {
  return t.nsUri == XDML && t.name == "if";
}

bool isStatementElse(AttributeNode t) {
  return t.nsUri == XDML && t.name == "else";
}
