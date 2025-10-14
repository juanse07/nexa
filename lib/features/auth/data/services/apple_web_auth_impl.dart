// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_util' as js_util;

import 'package:js/js.dart';

@JS('AppleID.auth.init')
external void _appleInit(AppleInitOptions options);

@JS('AppleID.auth.signIn')
external dynamic _appleSignIn([AppleSignInOptions? options]);

@JS()
@anonymous
class AppleInitOptions {
  external String get clientId;
  external String get scope;
  external String get redirectURI;
  external bool get usePopup;
  external String? get state;
  external String? get nonce;

  external factory AppleInitOptions({
    required String clientId,
    required String scope,
    required String redirectURI,
    required bool usePopup,
    String? state,
    String? nonce,
  });
}

@JS()
@anonymous
class AppleSignInOptions {
  external String? get state;
  external String? get nonce;

  external factory AppleSignInOptions({
    String? state,
    String? nonce,
  });
}

class AppleWebAuth {
  static bool _initialized = false;

  static bool get isSupported => js_util.hasProperty(js_util.globalThis, 'AppleID');

  static Future<String?> signIn({
    required String clientId,
    required String redirectUri,
    List<String> scopes = const ['name', 'email'],
    bool usePopup = true,
    String? state,
    String? nonce,
    void Function(String message)? onError,
  }) async {
    if (!isSupported) {
      onError?.call('Apple JS SDK not loaded. Ensure appleid.auth.js is included.');
      return null;
    }

    if (!_initialized) {
      try {
        _appleInit(
          AppleInitOptions(
            clientId: clientId,
            scope: scopes.join(' '),
            redirectURI: redirectUri,
            usePopup: usePopup,
            state: state,
            nonce: nonce,
          ),
        );
        _initialized = true;
      } catch (error) {
        onError?.call('Failed to initialize Apple sign-in.');
        return null;
      }
    }

    try {
      final result = await js_util.promiseToFuture<dynamic>(
        _appleSignIn(
          AppleSignInOptions(
            state: state,
            nonce: nonce,
          ),
        ),
      );
      if (result == null) {
        onError?.call('Apple sign-in returned no data.');
        return null;
      }

      final authorization = js_util.getProperty(result, 'authorization');
      if (authorization == null) {
        onError?.call('Apple sign-in response missing authorization.');
        return null;
      }

      final idToken = js_util.getProperty<String?>(authorization, 'id_token');
      if (idToken == null || idToken.isEmpty) {
        onError?.call('Apple did not return an identity token.');
        return null;
      }

      return idToken;
    } catch (error) {
      final message = _mapError(error);
      onError?.call(message);
      return null;
    }
  }

  static String _mapError(Object error) {
    try {
      final code = js_util.getProperty<String?>(error, 'error');
      switch (code) {
        case 'popup_closed_by_user':
          return 'Sign-in cancelled.';
        case 'user_cancelled_authorize':
          return 'Sign-in cancelled.';
        case 'invalid_request':
          return 'Apple sign-in request was invalid.';
        case 'service_error':
          return 'Apple reported a service error.';
        default:
          return 'Apple sign-in failed.';
      }
    } catch (_) {
      return 'Apple sign-in failed.';
    }
  }
}
