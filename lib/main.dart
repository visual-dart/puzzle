import 'dart:core';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';

import 'package:glob/glob.dart' as glob;
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart' as watcher;
import 'package:ansicolor/ansicolor.dart' as color;

import 'xdml/index.dart';
import 'metadata.dart';
import "transform.dart";

final BLUE = color.AnsiPen()..blue();
final GREEN = color.AnsiPen()..green();
final YELLOW = color.AnsiPen()..yellow();
final RED = color.AnsiPen()..red();
final MAGENTA = color.AnsiPen()..magenta();
final CYAN = color.AnsiPen()..cyan();
final GRAY = color.AnsiPen()..rgb(r: 0.5, g: 0.5, b: 0.5);

bool isSourceFile(String file) {
  return file.endsWith(".dart") && !file.endsWith(".binding.dart");
}

void parse(Configuration config) {
  print(BLUE("===> Puzzle Compiler"));
  // print("$entry/**.dart");
  final _glob = new glob.Glob("${config.entry}/**.dart");
  var fileList = _glob.listSync();
  for (var item in fileList) {
    if (!isSourceFile(item.path)) continue;
    print(
        "${CYAN("file loaded")} -> ${GRAY(path.relative(item.path, from: config.entry))}");
  }
  List<List<String>> relations = [];
  print(GREEN("===> Puzzle compilation start ..."));
  for (var i in fileList) {
    if (!isSourceFile(i.path)) continue;
    parseLib(
        filePath: i.path,
        relations: relations,
        basedir: config.entry,
        group: config.group,
        connect: true,
        throwOnError: config.throwOnError);
  }
  print(GREEN("===> Puzzle compilation done."));
  if (!config.watch) return;
  print(MAGENTA("===> Puzzle watcher is running..."));
  var _watcher = watcher.DirectoryWatcher(config.entry);
  _watcher.events.listen((event) {
    var changedPath = path.relative(event.path);
    // print("file changed -> $changedPath");
    var matched = relations.firstWhere((rela) => changedPath == rela[0],
        orElse: () => null);
    if (matched != null) {
      print(
          "${YELLOW("source file changed")} -> ${GRAY(path.relative(changedPath, from: config.entry))}");
      parseLib(
          filePath: changedPath,
          relations: relations,
          basedir: config.entry,
          group: config.group);
    }
    matched = relations.firstWhere((rela) => changedPath == rela[1],
        orElse: () => null);
    if (matched != null) {
      print(
          "${YELLOW("xdml file changed")} -> ${GRAY(path.relative(matched[1], from: config.entry))}");
      parseLib(
          filePath: matched[0],
          relations: relations,
          basedir: config.entry,
          group: config.group);
    }
    // ignore binding file changes
    if (changedPath.endsWith(".incremental.dill")) {
      print(CYAN("hot reload is completed."));
    }
  });
}

void parseLib(
    {String filePath,
    String group,
    String basedir,
    List<List<String>> relations,
    bool connect = false,
    bool throwOnError = false}) {
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
        sourceFile: sourceFile,
        throwOnError: throwOnError);
    // print(DateTime.now().toIso8601String());
    if (result == null || !connect) {
      return;
    }
    relations.add([
      path.relative(result.source),
      path.relative(result.xdml),
      path.relative(result.binding)
    ]);
    print(
        "${BLUE("xdml file related")} -> ${GRAY(path.relative(result.xdml, from: basedir))}");
    print(
        "${BLUE("source file related")} -> ${GRAY(path.relative(result.source, from: basedir))}");
  });
  transformer();
}
