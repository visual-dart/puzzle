class Binding {
  final String path;
  const Binding(this.path);
}

class Configuration {
  String entry;
  String group;
  bool watch;
  bool throwOnError;
  Configuration(this.entry, this.group, this.watch, this.throwOnError);

  Configuration fork() {
    return Configuration(entry, group, watch, throwOnError);
  }
}

final DEFAULT_CONFIG = new Configuration(".", "com.example", false, false);
