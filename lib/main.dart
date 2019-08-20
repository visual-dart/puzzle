library xdml;

import 'dart:core';
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:front_end/src/scanner/token.dart';
// import "package:source_gen/source_gen.dart";
// import 'package:build/build.dart';

import 'package:dart_style/dart_style.dart' as dartfmt;
import 'package:glob/glob.dart' as glob;
import 'package:xml/xml.dart' as xml;
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart' as watch;

part "main.transform.dart";
part "main.xdml.dart";

// dart main.dart --entry=../../../../GIT/fe-assets/assets-flutter/example/lib --group=com.example.lib

void main(List<String> arguments) {
  var argus = parseArguments(arguments);
  var target = argus.firstWhere((i) => i[0] == "entry", orElse: () => null);
  var target2 = argus.firstWhere((i) => i[0] == "group", orElse: () => null);
  var entry = target == null ? "." : target[1];
  var group = target2 == null ? "com.example" : target2[1];
  print("provide : $entry/**.dart");
  final _glob = new glob.Glob("$entry/**.dart");
  var fileList = _glob.listSync();
  // print(fileList);
  List<List<String>> relations = [];
  for (var i in fileList) {
    if (i.path.endsWith('binding.dart')) continue;
    parseLib(
        filePath: i.path, relations: relations, basedir: entry, group: group);
  }
  var watcher = watch.DirectoryWatcher(entry);
  relations.forEach((e) => print("${e[0]}\n${e[1]}\n${e[2]}\n----------"));
  watcher.events.listen((event) {
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
  var transformer =
      new BuildTransformer(file.unit, ({String viewPath, dynamic sourceFile}) {
    // print(viewPath);
    var result = createXdmlBinding(
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
