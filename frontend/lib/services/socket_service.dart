import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';

class SocketEvent {
  final String type;
  final Map<String, dynamic> data;
  SocketEvent(this.type, this.data);
}

class SocketService {
  IO.Socket? socket;

  final _socketStreamController = StreamController<SocketEvent>.broadcast();
  Stream<SocketEvent> get eventStream => _socketStreamController.stream;

  String get baseUrl => AppConfig.apiUrl;

  void connect(String userEmail) {

    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      debugPrint("🚫 Skipping Socket Connection: App is in background/isolate");
      return;
    }

    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'email': userEmail},
      'extraHeaders': {'x-user-email': userEmail}
    });

    socket!.connect();

    socket!.onAny((event, data) {
      const validEvents = ['item_added', 'item_updated', 'item_deleted', 'list_created'];

      if (validEvents.contains(event)) {
        debugPrint('📩 Valid Event: $event');
        if (data is Map<String, dynamic>) {
          _socketStreamController.add(SocketEvent(event, data));
        }
      } else {
        debugPrint('⚙️ System Socket Event: $event');
      }
    });

    socket!.onConnect((_) => print('✅ Socket Connected'));
    socket!.onDisconnect((_) => print('❌ Socket Disconnected'));
  }

  void joinGroup(String groupId) {
    if (socket != null && socket!.connected) {
      print('🚀 Joining room: $groupId');
      socket!.emit('join_group', groupId);
    }
  }

  void dispose() {
    _socketStreamController.close();
    socket?.dispose();
  }
}