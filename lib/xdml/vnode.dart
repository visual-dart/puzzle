import 'package:xml/xml.dart' as xml;

final RNRegExp = new RegExp(("(\r\n|\n)\r*"), multiLine: false);

enum VNodeType { Text, Element }

class VNodeAttr {
  String ns;
  String nsLabel;
  String name;
  String value;

  String get fullname => ns == null ? name : "$nsLabel.$name";

  VNodeAttr();

  @override
  String toString() {
    return "VNode.Attr [$fullname]";
  }

  factory VNodeAttr.fromNode(xml.XmlAttribute attr) {
    var name = attr.name.local;
    var ns = attr.name.namespaceUri;
    var nsLabel = attr.name.prefix;
    var value = attr.value;
    return new VNodeAttr()
      ..name = name
      ..ns = ns
      ..nsLabel = nsLabel
      ..value = value;
  }
}

class VNode {
  String ns;
  String nsLabel;
  String name;
  String value;
  VNodeType type;
  List<VNodeAttr> attrs = [];
  List<VNode> children = [];

  String get fullname => ns == null ? name : "$nsLabel.$name";

  VNode();

  @override
  String toString() {
    if (type == VNodeType.Text) {
      return "XmlVNode.Text ['$value']";
    } else {
      return "XmlVNode.Element [$fullname]";
    }
  }

  void overview({String indent = ''}) {
    print((indent ?? '') + this.toString());
    if (children.isNotEmpty) {
      for (var child in children) {
        child.overview(indent: (indent ?? '') + '--');
      }
    }
  }

  factory VNode.fromNode(xml.XmlNode node) {
    if (node is xml.XmlElement) {
      return VNodeElement.fromNode(node);
    }
    return VNodeString.fromXmlString(node);
  }
}

class VNodeString extends VNode {
  final VNodeType type = VNodeType.Text;

  VNodeString();

  factory VNodeString.fromXmlString(xml.XmlNode node) {
    if (node is! xml.XmlText) {
      return null;
    } else {
      node.normalize();
      var value = node.text;
      var hasRN = value.contains(RNRegExp);
      if (hasRN) {
        var noRN = value.replaceAll(RNRegExp, "").trim();
        if (noRN != "") {
          value = noRN;
        } else {
          return null;
        }
      }
      return new VNodeString()..value = value;
    }
  }
}

class VNodeElement extends VNode {
  final VNodeType type = VNodeType.Element;

  VNodeElement();

  factory VNodeElement.fromNode(xml.XmlNode node) {
    if (node is xml.XmlElement) {
      node.normalize();
      var name = node.name.local;
      var ns = node.name.namespaceUri;
      var nsLabel = node.name.prefix;
      var attrs =
          node.attributes.map((attr) => VNodeAttr.fromNode(attr)).toList();
      List<VNode> children = [];
      for (var child in node.children) {
        var childVNode = VNode.fromNode(child);
        if (childVNode != null) children.add(childVNode);
      }
      return VNodeElement()
        ..ns = ns
        ..nsLabel = nsLabel
        ..name = name
        ..attrs = attrs
        ..children = children;
    }
    return null;
  }
}
