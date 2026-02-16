import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Service that handles incoming deep links (Universal Links / App Links).
///
/// Listens for links matching:
///   https://flowshift.work/invite/:shortCode
///   https://flowshift.work/p/:shortCode
///
/// Stores a pending invite code if the user is not yet authenticated,
/// so it can be consumed after login.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// The pending invite code parsed from a deep link.
  /// Null when there is no pending invite.
  String? _pendingInviteCode;
  String? get pendingInviteCode => _pendingInviteCode;

  /// Whether the pending invite is a public recruitment link (/p/).
  bool _isPublicLink = false;
  bool get isPublicLink => _isPublicLink;

  /// Callbacks that are notified when a new invite code arrives.
  final List<void Function(String shortCode, bool isPublic)> _listeners = [];

  /// Register a listener that fires when an invite deep link is received.
  void addListener(void Function(String shortCode, bool isPublic) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(String shortCode, bool isPublic) listener) {
    _listeners.remove(listener);
  }

  /// Initialize the deep link service. Call once during app startup.
  Future<void> initialize() async {
    // Check for initial link (app launched from a link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Error getting initial link: $e');
    }

    // Listen for subsequent links (app already running)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (err) {
        debugPrint('[DeepLinkService] Link stream error: $err');
      },
    );
  }

  void _handleUri(Uri uri) {
    debugPrint('[DeepLinkService] Received URI: $uri');

    // Match /invite/:shortCode or /p/:shortCode
    final segments = uri.pathSegments;
    if (segments.length == 2) {
      final prefix = segments[0]; // 'invite' or 'p'
      final code = segments[1];

      if ((prefix == 'invite' || prefix == 'p') && code.length == 6) {
        final shortCode = code.toUpperCase();
        final isPublic = prefix == 'p';

        _pendingInviteCode = shortCode;
        _isPublicLink = isPublic;

        debugPrint('[DeepLinkService] Parsed invite code: $shortCode (public: $isPublic)');

        // Notify listeners
        for (final listener in _listeners) {
          listener(shortCode, isPublic);
        }
      }
    }
  }

  /// Consume the pending invite code (returns it and clears it).
  /// Returns null if there is no pending code.
  (String code, bool isPublic)? consumePendingInvite() {
    if (_pendingInviteCode == null) return null;
    final result = (_pendingInviteCode!, _isPublicLink);
    _pendingInviteCode = null;
    _isPublicLink = false;
    return result;
  }

  /// Dispose the service and cancel subscriptions.
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _listeners.clear();
  }
}
