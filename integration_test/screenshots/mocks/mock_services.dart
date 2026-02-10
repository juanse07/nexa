/// Mock GetIt registrations for screenshot mode.
///
/// Replaces real services (ApiClient, SecureStorage, etc.) with simple stubs
/// so the app can render screens without any backend or auth dependencies.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/core/network/network_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Register all mock dependencies in GetIt for screenshot mode.
///
/// This mirrors [configureDependencies] from `lib/core/di/injection.dart`
/// but uses stubs that never touch the network.
Future<void> registerMockDependencies() async {
  final getIt = GetIt.instance;

  // Reset any previous registrations
  await getIt.reset();

  // SharedPreferences — in-memory test instance
  SharedPreferences.setMockInitialValues({
    'work_terminology': 'Events',
  });
  final prefs = await SharedPreferences.getInstance();
  getIt.registerLazySingleton<SharedPreferences>(() => prefs);

  // FlutterSecureStorage — mock that returns our dummy JWT
  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  // Connectivity
  getIt.registerLazySingleton<Connectivity>(() => Connectivity());

  // Dio (never used in screenshot mode)
  getIt.registerLazySingleton<Dio>(() => Dio());

  // Logger
  getIt.registerLazySingleton<Logger>(
    () => Logger(level: Level.off), // Silence logs during screenshots
  );

  // NetworkInfo
  getIt.registerLazySingleton<NetworkInfo>(
    () => _AlwaysConnectedNetworkInfo(),
  );

  // ApiClient — real instance but it won't be called since
  // the screenshot app navigates directly to MainScreen
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(
      secureStorage: getIt<FlutterSecureStorage>(),
      logger: getIt<Logger>(),
      dio: getIt<Dio>(),
    ),
  );
}

/// A NetworkInfo that always reports connected.
class _AlwaysConnectedNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);
}
