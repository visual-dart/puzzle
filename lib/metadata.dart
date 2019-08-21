class Binding {
  final String path;
  const Binding(this.path);
}

class Configuration {
  String entry;
  String group;
  bool watch;
  Configuration(this.entry, this.group, this.watch);

  Configuration fork() {
    return Configuration(entry, group, watch);
  }
}

final DEFAULT_CONFIG = new Configuration(".", "com.example", false);
