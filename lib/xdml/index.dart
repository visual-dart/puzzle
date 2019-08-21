import 'dart:core';
import 'dart:io';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:front_end/src/scanner/token.dart';

import 'package:dart_style/dart_style.dart' as dartfmt;
import 'package:xml/xml.dart' as xml;
import 'package:path/path.dart' as path;

import 'base.dart';
import 'app.dart';
import 'binding.dart';
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
    var relative =
        path.relative(sourcePath, from: basedir).split(".").elementAt(0);
    var prefix = path.dirname(sourcePath);
    var sourceName = path.basename(sourcePath);
    var xdmlPath = path.join(prefix, viewPath);

    var viewPathSeg = viewPath;
    if (viewPath.endsWith(".dart.xml")) {
      viewPathSeg = viewPathSeg.replaceAll(".dart.xml", ".binding.dart");
    }
    if (viewPathSeg.endsWith(".xdml")) {
      viewPathSeg.replaceAll(".xdml", ".binding.dart");
    }
    var realView = path.join(prefix, viewPathSeg);

    File xdml = new File(xdmlPath);
    var xmlDocument = xml.parse(xdml.readAsStringSync());
    var mains = xmlDocument.findElements("Page", namespace: "dart").toList();
    if (mains == null || mains.length == 0) {
      throw new UnsupportedError(
          "resolve xdml $viewPath file failed => dart Page declaration not found");
    }

    var main = mains.elementAt(0);
    var attrs = main.attributes.toList();
    List<String> libraries = [];
    List<DartReference> references = [];
    Map<String, String> namespaces = {};

    for (var attr in attrs) {
      var refName = attr.name.toString();
      var refValue = attr.value;
      if (refName.startsWith("xmlns:")) {
        var alias = refName.replaceAll("xmlns:", "");
        namespaces[refValue] = alias;
        if (refValue == "dart" || refValue == "flutter") {
          continue;
        }
        var splits = refValue.split(":");
        var type = splits.elementAt(0);
        var name = splits.elementAt(1);
        references.add(new DartReference(type, name, alias));
      }
    }

    if (!namespaces.containsKey("dart")) {
      throw new UnsupportedError(
          "resolve xdml $viewPath file failed => dart namespace not found");
    }

    var refNodes =
        main.findAllElements("Reference", namespace: "dart").toList();
    if (refNodes != null && refNodes.length > 0) {
      var refRoot = refNodes.elementAt(0);
      refRoot.children.where((e) => e is xml.XmlElement).forEach((child) {
        xml.XmlElement thisNode = child;
        var name = thisNode.name;
        if (name.namespaceUri.trim() != "dart") return;
        var childAttrs = thisNode.attributes;
        var nameAttr = childAttrs.firstWhere((i) => i.name.toString() == "name",
            orElse: () => null);
        if (nameAttr != null) {
          if (name.local == "Library") {
            libraries.add(nameAttr.value);
            return;
          }
          var type = name.local == "Internal" ? "dart" : "package";
          references.add(new DartReference(type, nameAttr.value, null));
        }
      });
    }

    xml.XmlElement appRoot = null;
    var childrenNodes =
        main.children.where((i) => i is xml.XmlElement).toList();
    if (childrenNodes.length == 1) {
      appRoot = childrenNodes.elementAt(0);
    } else if (childrenNodes.length > 1) {
      appRoot = childrenNodes.elementAt(1);
    } else {
      throw new UnsupportedError(
          "resolve xdml $viewPath file failed => app root not found");
    }

    var app = resolveApp(references, namespaces, libraries, appRoot);

    var factory = new AstFactoryImpl();
    var formatter = dartfmt.DartFormatter();

    List<Directive> otherDirecs = [];
    List<Directive> imports = [];
    List<Directive> partDirecs = [];
    List<Directive> libDirecs = [];

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

    List<DartReference> importsNeedAdd = [];
    List<DartReference> importsNeedReplace = [];

    // print(imports.map((i) => (i as ImportDirective).uri.stringValue));
    for (var r in references) {
      var type = r.type;
      var name = r.name;
      var reference = r.reference;
      var hasAlias = namespaces.containsKey(reference);
      var alias = hasAlias ? namespaces[reference] : null;
      var matched = imports.firstWhere(
          (i) => (i as ImportDirective).uri.stringValue == reference,
          orElse: () => null);
      if (matched != null) {
        importsNeedReplace.add(new DartReference(type, name, alias));
      } else {
        importsNeedAdd.add(new DartReference(type, name, alias));
      }
    }

    List<ImportDirective> importsNeedReset = [];
    for (ImportDirective item in imports) {
      var matched = importsNeedReplace.firstWhere(
          (i) => item.uri.stringValue == i.reference,
          orElse: () => null);
      if (matched == null) {
        importsNeedReset.add(item);
      } else {
        createImportDirective(importsNeedReset, factory, matched);
      }
    }
    for (DartReference item in importsNeedAdd) {
      createImportDirective(importsNeedReset, factory, item);
    }

    var secs = group.split("/");
    secs.addAll(relative.split("/"));

    if (libraries.length > 0) {
      secs = libraries.elementAt(0).split(".");
    }

    var libIdentify = factory.libraryIdentifier(secs
        .map((s) => factory
            .simpleIdentifier(new StringToken(TokenType.IDENTIFIER, s, 0)))
        .toList());

    // 在模板提供了library，则强行覆盖
    // 否则，不进行更新，只进行初始化
    if (libDirecs.length == 0 || libraries.length > 0) {
      libDirecs = [
        factory.libraryDirective(
            null, null, new KeywordToken(Keyword.LIBRARY, 0), libIdentify, null)
      ];
    }

    // reset part of any way
    partDirecs = [
      factory.partDirective(
          null,
          null,
          new KeywordToken(Keyword.PART, 0),
          factory.simpleStringLiteral(
              new StringToken(TokenType.STRING, "'$viewPathSeg'", 0), ''),
          null)
    ];

    List<Directive> newDirectives = [];
    newDirectives.addAll(libDirecs);
    newDirectives.addAll(otherDirecs);
    newDirectives.addAll(importsNeedReset);
    newDirectives.addAll(partDirecs);

    List<SimpleIdentifier> invokeParams = [];

    var newDeclarations = sourceFile.declarations
        .map((i) => wrapBuildMethod(i, className, factory,
                (List<SimpleIdentifier> params) {
              invokeParams = params;
            }))
        .toList();

    var newSourceFile = factory.compilationUnit(
        beginToken: sourceFile.beginToken,
        scriptTag: sourceFile.scriptTag,
        directives: newDirectives,
        declarations: newDeclarations,
        endToken: sourceFile.endToken,
        featureSet: sourceFile.featureSet);

    var partOf = factory.partOfDirective(
        null,
        null,
        new KeywordToken(Keyword.PART, 0),
        new KeywordToken(Keyword.OF, 0),
        factory.simpleStringLiteral(
            new StringToken(TokenType.STRING, "'$sourceName'", 0), ''),
        libIdentify,
        null);

    File source = new File(sourcePath);
    var newContent = formatter.format(newSourceFile.toSource());
    var oldContent = source.readAsStringSync();
    if (newContent != oldContent) {
      source.writeAsStringSync(newContent);
    }

    var buildFn = generateBuildFn(factory, invokeParams, className, app);

    File bindingFile = new File(realView);
    var newBinding =
        formatter.format([partOf.toSource(), buildFn.toSource()].join(("\n")));
    var oldBinding = bindingFile.readAsStringSync();
    if (oldBinding != newBinding) {
      bindingFile.writeAsStringSync(newBinding);
    }

    return new BindingRelation(sourcePath, xdmlPath, realView);
  } catch (error) {
    print(error);
    return null;
  }
}

void createImportDirective(List<ImportDirective> importsNeedReset,
    AstFactoryImpl fac, DartReference matched) {
  importsNeedReset.add(fac.importDirective(
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
