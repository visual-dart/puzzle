import "../lib/main.dart";
import '../lib/utils.dart';

// dart xdml.dart --entry=../../../../GIT/fe-assets/assets-flutter/example --group=com.example --watch=true

void main(List<String> arguments) {
  var argus = parseArguments(arguments);
  var target = argus.firstWhere((i) => i[0] == "entry", orElse: () => null);
  var target2 = argus.firstWhere((i) => i[0] == "group", orElse: () => null);
  var target3 = argus.firstWhere((i) => i[0] == "watch", orElse: () => null);
  return parse(
      entry: target == null ? "." : target[1],
      group: target2 == null ? "com.example" : target2[1],
      watch: target3 == null ? false : target2[1] == "true");
}
