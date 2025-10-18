import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../features/auth/data/services/auth_service.dart';
import '../config/app_config.dart';

class SocketEvent {
  SocketEvent(this.event, this.data);

  final String event;
  final dynamic data;
}

class SocketManager {
  SocketManager._internal();

  static final SocketManager instance = SocketManager._internal();

  final StreamController<SocketEvent> _controller =
      StreamController<SocketEvent>.broadcast();

  io.Socket? _socket;
  bool _connecting = false;
  String? _managerId;
  final Set<String> _joinedTeams = <String>{};

  Stream<SocketEvent> get events => _controller.stream;
  io.Socket? get socket => _socket;

  Future<void> registerManager(String? managerId) async {
    if (managerId == null || managerId.isEmpty) return;
    _managerId = managerId;
    if (_socket == null) {
      await _ensureConnected();
      return;
    }
    _socket!.emit('register', {'managerId': managerId});
  }

  Future<void> joinTeams(Iterable<String> teamIds) async {
    final ids = teamIds
        .where((id) => id.trim().isNotEmpty)
        .map((id) => id.trim())
        .toSet();
    if (ids.isEmpty) return;
    _joinedTeams
      ..removeWhere((id) => !ids.contains(id))
      ..addAll(ids);
    if (_socket == null) {
      await _ensureConnected();
      return;
    }
    _socket!.emit('joinTeams', _joinedTeams.toList());
  }

  Future<void> _ensureConnected() async {
    if (_socket != null || _connecting) return;
    _connecting = true;
    try {
      final baseUrl = AppConfig.instance.baseUrl;
      final uri = Uri.parse(baseUrl);
      final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
      final host = uri.host.isEmpty ? uri.path : uri.host;
      final port = uri.hasPort ? ':${uri.port}' : '';
      final origin = '$scheme://$host$port';

      final token = await AuthService.getJwt();

      final options = io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({
            if (token != null) 'token': token,
            if (_managerId != null) 'managerId': _managerId,
            if (_joinedTeams.isNotEmpty) 'teamIds': _joinedTeams.toList(),
          })
          .disableAutoConnect()
          .build();

      final socket = io.io(origin, options);
      socket.onConnect((_) {
        if (_joinedTeams.isNotEmpty) {
          socket.emit('joinTeams', _joinedTeams.toList());
        }
      });
      socket.onAny((event, data) {
        if (_controller.hasListener && !_controller.isClosed) {
          _controller.add(SocketEvent(event.toString(), data));
        }
      });
      socket.onDisconnect((_) {});
      socket.onError((error) {
        if (_controller.hasListener && !_controller.isClosed) {
          _controller.add(SocketEvent('socket:error', error));
        }
      });
      socket.connect();
      _socket = socket;
    } finally {
      _connecting = false;
    }
  }

  Future<void> dispose() async {
    await _controller.close();
    _socket?.dispose();
    _socket = null;
  }
}
