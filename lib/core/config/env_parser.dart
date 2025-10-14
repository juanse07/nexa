Map<String, String> parseEnvLines(Iterable<String> lines) {
  final env = <String, String>{};
  for (final rawLine in lines) {
    if (rawLine.isEmpty) continue;
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final separatorIndex = line.indexOf('=');
    if (separatorIndex <= 0) continue;
    final key = line.substring(0, separatorIndex).trim();
    if (key.isEmpty) continue;
    var value = line.substring(separatorIndex + 1).trim();
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      value = value.substring(1, value.length - 1);
    } else if (value.startsWith("'") &&
        value.endsWith("'") &&
        value.length >= 2) {
      value = value.substring(1, value.length - 1);
    }
    env[key] = value;
  }
  return env;
}
