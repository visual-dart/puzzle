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
