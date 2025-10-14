import 'dart:async';

import 'env_file_loader_stub.dart'
    if (dart.library.io) 'env_file_loader_io.dart';

/// Load environment key/value pairs from a local file without bundling it.
Future<Map<String, String>> loadEnvFile(String path) =>
    loadEnvFileImpl(path);
