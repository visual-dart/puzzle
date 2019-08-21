List<List<String>> parseArguments(List<String> arguments) {
  List<List<String>> argus = [];
  for (var arg in arguments) {
    if (arg.startsWith("--")) {
      argus.add(arg.replaceAll("--", "").split("="));
    }
  }
  return argus;
}
