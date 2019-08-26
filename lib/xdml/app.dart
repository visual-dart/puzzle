import 'dart:core';
import 'base.dart';
import 'vnode.dart';

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
    Map<String, String> namespaces, VNode appRoot) {
  var internal = false;
  if (appRoot is VNodeElement) {
    var rootName = appRoot.name;
    var nsUri = appRoot.ns;
    var hasNs = namespaces.containsKey(nsUri);
    var rootNs = namespaces[nsUri];
    if (nsUri == XDML) internal = true;
    var attrs =
        appRoot.attrs.map((attr) => createAttribute(attr, namespaces)).toList();
    var isText = appRoot.children.length == 1 &&
        appRoot.children.elementAt(0) is VNodeString;
    List<ComponentTreeNode> children = isText
        ? []
        : appRoot.children
            .where((n) => n is VNodeElement)
            .map((i) => resolveApp(references, namespaces, i))
            .toList();
    var node = new ComponentTreeNode(
        internal,
        rootName,
        hasNs ? rootNs : null,
        hasNs ? nsUri : null,
        attrs,
        [],
        isText ? appRoot.children.elementAt(0).value : null,
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
  if (appRoot is VNodeString) {
    return new ComponentTreeNode(true, InternalNodes.EscapeText, null, null, [],
        [], "'${appRoot.value}'", null);
  }
  return null;
}

AttributeNode createAttribute(VNodeAttr attr, Map<String, String> namespaces) {
  var attrName = attr.name;
  var attrNsUri = attr.ns;
  var hasAttrNs = namespaces.containsKey(attrNsUri);
  return new AttributeNode(
      attrNsUri == XDML || attrNsUri == BIND,
      attrName,
      hasAttrNs ? namespaces[attrNsUri] : null,
      hasAttrNs ? attrNsUri : null,
      attr.value);
}

bool isXDMLHost(AttributeNode t) {
  return t.name == "host" && t.nsUri == XDML;
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

bool isStatementElseIf(AttributeNode t) {
  return t.nsUri == XDML && t.name == "else-if";
}
