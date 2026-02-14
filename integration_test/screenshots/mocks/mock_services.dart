/// Mock GetIt registrations for screenshot mode.
///
/// Replaces real services (ApiClient, SecureStorage, etc.) with simple stubs
/// so the app can render screens without any backend or auth dependencies.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:nexa/core/network/api_client.dart';
import 'package:nexa/core/network/network_info.dart';
import 'package:nexa/features/brand/data/providers/brand_provider.dart';
import 'package:nexa/features/cities/data/services/city_service.dart';
import 'package:nexa/features/subscription/data/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_dio_interceptor.dart';

/// Register all mock dependencies in GetIt for screenshot mode.
///
/// This mirrors [configureDependencies] from `lib/core/di/injection.dart`
/// but uses stubs that never touch the network.
Future<void> registerMockDependencies() async {
  final getIt = GetIt.instance;

  // Reset any previous registrations
  await getIt.reset();

  // ── Environment ─────────────────────────────────────────────────
  dotenv.testLoad(fileInput: '''
API_BASE_URL=http://localhost:3000
API_PATH_PREFIX=/api
ENVIRONMENT=development
DEBUG_MODE=false
''');

  // ── SharedPreferences ───────────────────────────────────────────
  SharedPreferences.setMockInitialValues({
    'work_terminology': 'Events',
  });
  final prefs = await SharedPreferences.getInstance();
  getIt.registerLazySingleton<SharedPreferences>(() => prefs);

  // ── FlutterSecureStorage ────────────────────────────────────────
  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  // ── Connectivity ────────────────────────────────────────────────
  getIt.registerLazySingleton<Connectivity>(() => Connectivity());

  // ── Dio (with mock interceptor) ─────────────────────────────────
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:3000/api',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  dio.interceptors.insert(0, MockDioInterceptor());
  getIt.registerLazySingleton<Dio>(() => dio);

  // ── Logger ──────────────────────────────────────────────────────
  getIt.registerLazySingleton<Logger>(
    () => Logger(level: Level.off),
  );

  // ── NetworkInfo ─────────────────────────────────────────────────
  getIt.registerLazySingleton<NetworkInfo>(
    () => _AlwaysConnectedNetworkInfo(),
  );

  // ── ApiClient ───────────────────────────────────────────────────
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(
      secureStorage: getIt<FlutterSecureStorage>(),
      logger: getIt<Logger>(),
      dio: getIt<Dio>(),
    ),
  );

  // ── CityService ─────────────────────────────────────────────────
  getIt.registerLazySingleton<CityService>(
    () => CityService(getIt<ApiClient>()),
  );

  // ── SubscriptionService ─────────────────────────────────────────
  getIt.registerLazySingleton<SubscriptionService>(
    () => SubscriptionService(getIt<ApiClient>()),
  );

  // ── BrandProvider ───────────────────────────────────────────────
  getIt.registerLazySingleton<BrandProvider>(
    () => BrandProvider(getIt<ApiClient>()),
  );
}

/// A NetworkInfo that always reports connected.
class _AlwaysConnectedNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);
}
