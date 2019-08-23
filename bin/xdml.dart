import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart' as yaml;

import "../lib/main.dart";
import '../lib/utils.dart';
import '../lib/metadata.dart';

// dart xdml.dart --entry=../../../../GIT/fe-assets/assets-flutter/example --group=com.example --watch=true
// dart xdml.dart --config=demo.config.yaml

void main(List<String> arguments) {
  var argus = parseArguments(arguments);
  var target_entry =
      argus.firstWhere((i) => i[0] == "entry", orElse: () => null);
  var target_group =
      argus.firstWhere((i) => i[0] == "group", orElse: () => null);
  var target_watch =
      argus.firstWhere((i) => i[0] == "watch", orElse: () => null);
  var target_throwOnError =
      argus.firstWhere((i) => i[0] == "throwOnError", orElse: () => null);

  var default_conf = tryLoadConfigFile(argus);

  return parse(new Configuration(
      target_entry == null ? default_conf.entry : target_entry[1],
      target_group == null ? default_conf.group : target_group[1],
      target_watch == null ? default_conf.watch : target_watch[1] == "true",
      target_throwOnError == null
          ? default_conf.throwOnError
          : target_throwOnError[1] == "true"));
}

Configuration tryLoadConfigFile(List<List<String>> argus) {
  var target_config =
      argus.firstWhere((i) => i[0] == "config", orElse: () => null);
  var default_conf = DEFAULT_CONFIG.fork();
  try {
    if (target_config != null) {
      var confFile = path.absolute(target_config[1]);
      var ext = path.extension(confFile);
      if (ext.endsWith("yaml") || ext.endsWith("yml")) {
        var file = new File(confFile);
        var str = file.readAsStringSync();
        yaml.YamlMap doc = yaml.loadYaml(str);
        if (doc.containsKey('entry')) {
          default_conf.entry = doc['entry'];
        }
        if (doc.containsKey('group')) {
          default_conf.group = doc['group'];
        }
        if (doc.containsKey('watch')) {
          default_conf.watch = doc['watch'];
        }
        if (doc.containsKey('throwOnError')) {
          default_conf.throwOnError = doc['throwOnError'];
        }
      }
    }
  } catch (error) {
    print(error);
  }
  return default_conf;
}
