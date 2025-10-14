class AppleWebAuth {
  static bool get isSupported => false;

  static Future<String?> signIn({
    required String clientId,
    required String redirectUri,
    List<String> scopes = const ['name', 'email'],
    bool usePopup = true,
    void Function(String message)? onError,
  }) async {
    onError?.call('Apple sign-in is not available on this platform.');
    return null;
  }
}
