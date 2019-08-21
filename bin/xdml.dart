import "../lib/main.dart";
import '../lib/utils.dart';

// dart xdml.dart --entry=../../../../GIT/fe-assets/assets-flutter/example --group=com.example --watch=true

void main(List<String> arguments) {
  var argus = parseArguments(arguments);
  var target_entry =
      argus.firstWhere((i) => i[0] == "entry", orElse: () => null);
  var target_group =
      argus.firstWhere((i) => i[0] == "group", orElse: () => null);
  var target_watch =
      argus.firstWhere((i) => i[0] == "watch", orElse: () => null);
  return parse(
      entry: target_entry == null ? "." : target_entry[1],
      group: target_group == null ? "com.example" : target_group[1],
      watch: target_watch == null ? false : target_watch[1] == "true");
}
