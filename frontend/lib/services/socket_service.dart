import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config.dart';
import '../repositories/grocery_repository.dart';

class SocketEvent {
  final String type;
  final Map<String, dynamic> data;
  SocketEvent(this.type, this.data);
}

class SocketService {
  late IO.Socket socket;
  final GroceryRepository repository;

  final _socketStreamController = StreamController<SocketEvent>.broadcast();
  Stream<SocketEvent> get eventStream => _socketStreamController.stream;

  SocketService(this.repository);

  String get baseUrl => AppConfig.apiUrl;

  void connect(String userEmail) {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'x-user-email': userEmail}
    });

    socket.connect();

    // Catch-all listener to pipe everything into the StreamController
    socket.onAny((event, data) {
      if (data is Map<String, dynamic>) {
        _socketStreamController.add(SocketEvent(event, data));
      }
    });

    socket.onConnect((_) {
      print('✅ Socket Connected');
      final activeGroupId = repository.getActiveGroupId();
      if (activeGroupId != null) joinGroup(activeGroupId);
    });

    socket.onDisconnect((_) => print('❌ Socket Disconnected'));
  }

  void joinGroup(String groupId) {
    if (socket.connected) {
      socket.emit('join_group', groupId);
    }
  }

  void dispose() {
    _socketStreamController.close();
    socket.dispose();
  }
}