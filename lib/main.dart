library xdml;

import 'dart:core';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:xdml/transform.dart';

import 'package:glob/glob.dart' as glob;
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart' as watcher;

import 'xdml/index.dart';

void parse({String group, String entry, bool watch}) {
  // print("$entry/**.dart");
  final _glob = new glob.Glob("$entry/**.dart");
  var fileList = _glob.listSync();
  List<List<String>> relations = [];
  for (var i in fileList) {
    if (i.path.endsWith('binding.dart')) continue;
    parseLib(
        filePath: i.path, relations: relations, basedir: entry, group: group);
  }
  if (!watch) return;
  var _watcher = watcher.DirectoryWatcher(entry);
  _watcher.events.listen((event) {
    var changedPath = path.relative(event.path);
    print("file changed -> $changedPath");
    var matched = relations.firstWhere((rela) => changedPath == rela[0],
        orElse: () => null);
    if (matched != null) {
      print("source file changed -> $changedPath");
      parseLib(
          filePath: changedPath,
          relations: relations,
          basedir: entry,
          group: group);
    }
    matched = relations.firstWhere((rela) => changedPath == rela[1],
        orElse: () => null);
    if (matched != null) {
      print("xdml file changed -> ${matched[0]}");
      parseLib(
          filePath: matched[0],
          relations: relations,
          basedir: entry,
          group: group);
    }
    // ignore binding file changes
  });
}

void parseLib(
    {String filePath,
    String group,
    String basedir,
    List<List<String>> relations}) {
  var file =
      parseFile(path: filePath, featureSet: FeatureSet.fromEnableFlags([]));
  // print(DateTime.now().toIso8601String());
  var transformer = new BuildTransformer(file.unit, (
      {String viewPath, dynamic sourceFile, String className}) {
    // print(viewPath);
    var result = createXdmlBinding(
        className: className,
        basedir: basedir,
        group: group,
        sourcePath: filePath,
        viewPath: viewPath,
        sourceFile: sourceFile);
    // print(DateTime.now().toIso8601String());
    if (result == null) {
      return;
    }
    relations.add([
      path.relative(result.source),
      path.relative(result.xdml),
      path.relative(result.binding)
    ]);
  });
  transformer();
}
