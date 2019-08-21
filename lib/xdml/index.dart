import 'dart:core';
import 'dart:io';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:front_end/src/scanner/token.dart';

import 'package:dart_style/dart_style.dart' as dartfmt;

import 'base.dart';
import 'binding.dart';
import 'paths.dart';
import 'source.dart';

class BindingRelation {
  String source;
  String binding;
  String xdml;
  BindingRelation(this.source, this.xdml, this.binding);
}

BindingRelation createXdmlBinding(
    {String group,
    String basedir,
    String sourcePath,
    String viewPath,
    String className,
    CompilationUnit sourceFile}) {
  try {
    var paths = readPaths(basedir, sourcePath, viewPath);

    var result = parseXmlDocument(paths.xdmlPath, viewPath);
    var references = result.references;
    var namespaces = result.namespaces;
    // var libraries = result.libraries;

    List<Directive> otherDirecs = [];
    List<Directive> imports = [];
    List<Directive> partDirecs = [];
    List<Directive> libDirecs = [];

    List<DartReference> importsNeedAdd = [];
    List<ImportDirective> importsBindingAdd = [];

    AstFactory fac = new AstFactoryImpl();
    var formatter = dartfmt.DartFormatter();

    splitDirectives(sourceFile, imports, partDirecs, libDirecs, otherDirecs);
    decideImportDirectives(references, namespaces, imports, importsNeedAdd);

    for (var item in importsNeedAdd) {
      print(item.toString());
      createImportDirective(importsBindingAdd, fac, item);
    }

    List<Directive> newDirectives = [];
    newDirectives.addAll(imports);
    newDirectives.addAll(libDirecs);
    newDirectives.addAll(otherDirecs);
    newDirectives.addAll(partDirecs);

    decideXdmlImportDirectives(paths, fac, newDirectives);

    List<SimpleIdentifier> invokeParams = [];

    var newDeclarations = sourceFile.declarations
        .map((i) =>
            wrapBuildMethod(i, className, fac, (List<SimpleIdentifier> params) {
              invokeParams = params;
            }))
        .toList();

    var newSourceFile =
        updateSpurceFile(fac, sourceFile, newDirectives, newDeclarations);

    refreshSourceFile(sourcePath, formatter, newSourceFile);

    var buildFn = generateBuildFn(fac, invokeParams, className, result.app);

    refreshBindingFile(paths, formatter, importsBindingAdd, buildFn);

    return new BindingRelation(sourcePath, paths.xdmlPath, paths.realView);
  } catch (error) {
    if (error is FileSystemException) {
      print(error.toString());
    } else {
      print(error);
    }
    return null;
  }
}

void refreshBindingFile(Paths paths, dartfmt.DartFormatter formatter,
    List<Directive> imports, FunctionDeclaration buildFn) {
  File bindingFile = new File(paths.realView);

  List<AstNode> list = [];
  list.addAll(imports);
  list.add(buildFn);

  var newBinding = formatter.format(list.map((i) => i.toSource()).join(("\n")));
  String oldBinding;
  try {
    oldBinding = bindingFile.readAsStringSync();
  } catch (error) {
    print(error);
    oldBinding = "";
  }
  if (oldBinding != newBinding) {
    bindingFile.writeAsStringSync(newBinding);
  }
}

void refreshSourceFile(String sourcePath, dartfmt.DartFormatter formatter,
    CompilationUnit newSourceFile) {
  File source = new File(sourcePath);
  var newContent = formatter.format(newSourceFile.toSource());
  var oldContent = source.readAsStringSync();
  if (newContent != oldContent) {
    source.writeAsStringSync(newContent);
  }
}

CompilationUnit updateSpurceFile(
    AstFactory fac,
    CompilationUnit sourceFile,
    List<Directive> newDirectives,
    List<CompilationUnitMember> newDeclarations) {
  return fac.compilationUnit(
      beginToken: sourceFile.beginToken,
      scriptTag: sourceFile.scriptTag,
      directives: newDirectives,
      declarations: newDeclarations,
      endToken: sourceFile.endToken,
      featureSet: sourceFile.featureSet);
}

PartOfDirective createPartOf(
    AstFactory fac, Paths paths, LibraryIdentifier libIdentify) {
  return fac.partOfDirective(
      null,
      null,
      new KeywordToken(Keyword.PART, 0),
      new KeywordToken(Keyword.OF, 0),
      fac.simpleStringLiteral(
          new StringToken(TokenType.STRING, "'${paths.sourceName}'", 0), ''),
      libIdentify,
      null);
}

void decideXdmlImportDirectives(
    Paths paths, AstFactory fac, List<Directive> newDirectives) {
  var importDire = fac.importDirective(
      null,
      [],
      new KeywordToken(Keyword.IMPORT, 0),
      fac.simpleStringLiteral(
          new StringToken(TokenType.STRING, "'${paths.relativeView}'", 1), ''),
      null,
      null,
      null,
      null,
      null,
      null);
  newDirectives.removeWhere((i) =>
      (i as ImportDirective).uri.toString() == importDire.uri.toString());
  newDirectives.add(importDire);
}

LibraryIdentifier decideLibIdentify(
    String group, Paths paths, List<String> libraries, AstFactory fac) {
  var secs = group.split("/");
  secs.addAll(paths.relative.split("/"));

  if (libraries.length > 0) {
    secs = libraries.elementAt(0).split(".");
  }

  var libIdentify = fac.libraryIdentifier(secs
      .map((s) =>
          fac.simpleIdentifier(new StringToken(TokenType.IDENTIFIER, s, 0)))
      .toList());
  return libIdentify;
}

void decideImportDirectives(
    List<DartReference> references,
    Map<String, String> namespaces,
    List<Directive> imports,
    List<DartReference> importsNeedAdd) {
  for (var r in references) {
    var type = r.type;
    var name = r.name;
    var reference = r.reference;
    var hasAlias = namespaces.containsKey(reference);
    var alias = hasAlias ? namespaces[reference] : null;
    importsNeedAdd.add(new DartReference(type, name, alias));
  }
}

void splitDirectives(
    CompilationUnit sourceFile,
    List<Directive> imports,
    List<Directive> partDirecs,
    List<Directive> libDirecs,
    List<Directive> otherDirecs) {
  for (var i in sourceFile.directives) {
    if (i is ImportDirective) {
      imports.add(i);
    } else if (i is PartDirective) {
      partDirecs.add(i);
    } else if (i is LibraryDirective) {
      libDirecs.add(i);
    } else {
      otherDirecs.add(i);
    }
  }
}

void createImportDirective(
    List<ImportDirective> array, AstFactoryImpl fac, DartReference matched) {
  array.add(fac.importDirective(
      null,
      [],
      new KeywordToken(Keyword.IMPORT, 0),
      fac.simpleStringLiteral(
          new StringToken(TokenType.STRING, "'${matched.reference}'", 1), ''),
      null,
      null,
      matched.alias == null ? null : new KeywordToken(Keyword.AS, 0),
      matched.alias == null
          ? null
          : fac.simpleIdentifier(
              new StringToken(TokenType.IDENTIFIER, matched.alias, 0)),
      null,
      null));
}
