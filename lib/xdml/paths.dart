import 'package:path/path.dart' as path;

class Paths {
  String relative;
  String prefix;
  String sourceName;
  String xdmlPath;
  String realView;
  String relativeView;
  String viewPathSeg;
  Paths(this.relative, this.prefix, this.sourceName, this.xdmlPath,
      this.realView, this.relativeView, this.viewPathSeg);
}

Paths readPaths(String basedir, String sourcePath, String viewPath) {
  var relative =
      path.relative(sourcePath, from: basedir).split(".").elementAt(0);
  var prefix = path.dirname(sourcePath);
  var sourceName = path.basename(sourcePath);
  var xdmlPath = path.join(prefix, viewPath);

  var viewPathSeg =
      sourceName.substring(0, sourceName.length - 5) + ".binding.dart";
  var realView = path.join(prefix, viewPathSeg);
  var relativeView = path.relative(realView, from: prefix);
  return new Paths(relative, prefix, sourceName, xdmlPath, realView,
      relativeView, viewPathSeg);
}
