library xdml;

import 'dart:core';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/ast.dart';
// import "package:source_gen/source_gen.dart";
// import 'package:build/build.dart';

import 'package:glob/glob.dart';

part "main.d.dart";

// --entry=../../../../GIT/fe-assets/assets-flutter/example/lib/pages

void main(List<String> arguments) {
  var argus = parseArguments(arguments);
  var target = argus.firstWhere((i) => i[0] == "entry", orElse: () => null);
  var entry = target == null ? "." : target[1];
  print("provide : $entry");
  final _glob = new Glob("$entry/**.dart");
  var fileList = _glob.listSync();
  print(fileList);
  for (var i in fileList) {
    if (i.path.endsWith('binding.dart')) continue;
    parseLib(i.path);
  }
}

void parseLib(String filePath) {
  var file =
      parseFile(path: filePath, featureSet: FeatureSet.fromEnableFlags([]));
  print(DateTime.now().toIso8601String());
  new BuildTransformer(file.unit);
  print(DateTime.now().toIso8601String());
}
