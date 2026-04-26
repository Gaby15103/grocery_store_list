import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../repositories/grocery_repository.dart';

class SocketService {
  late IO.Socket socket;
  final GroceryRepository repository;

  SocketService(this.repository);

  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'http://localhost:3000';
    }
  }


  void connect(String userEmail) {
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'x-user-email': userEmail}
    });

    socket.connect();

    socket.on('item_added', (data) => repository.handleSocketItemAdded(data));
    socket.on('item_updated', (data) => repository.handleSocketItemUpdated(data));

    socket.onConnect((_) {
      print('✅ Connected to WebSocket');
    });

    socket.onDisconnect((_) => print('❌ Disconnected from WebSocket'));
  }

  void joinGroup(String groupId) {
    socket.emit('join_group', groupId);
  }

  void dispose() {
    socket.dispose();
  }
}