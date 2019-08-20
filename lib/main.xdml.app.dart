part of "main.dart";

class ComponentTreeNode {
  String ns = null;
  String name;
  ComponentTreeNode parent = null;
  List<ComponentTreeNode> children = [];
  List<String> attrs = [];
  List<String> slots = [];
  String innerText = null;
  ComponentTreeNode(this.name, this.ns, this.attrs, this.children,
      this.innerText, this.parent);

  get fullname => ns == null ? name : "${ns}:${name}";
}

ComponentTreeNode resolveApp(
    List<DartReference> references,
    Map<String, String> namespaces,
    List<String> libraries,
    xml.XmlElement appRoot) {
  var rootName = appRoot.name.local;
  var hasNs = namespaces.containsKey(appRoot.name.namespaceUri);
  var rootNs = namespaces[appRoot.name.namespaceUri];
  print("${hasNs ? "$rootNs:" : ""}$rootName");
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
  var node = new ComponentTreeNode(rootName, hasNs ? rootNs : null, attrs, [],
      isText ? appRoot.children.elementAt(0).toString() : null, null);
  children.forEach((c) {
    c.parent = node;
    var slot =
        c.attrs.firstWhere((t) => t.startsWith("slot@@@"), orElse: () => null);
    if (slot != null) {
      node.slots.add(
          "${slot.replaceAll("slot@@@", "")}###${c.ns == null ? "__no_ns__" : c.ns}@@@${c.name}");
    }
  });
  node.children = children;
  return node;
}
