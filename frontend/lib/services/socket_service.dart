import 'dart:async';
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
    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {'x-user-email': userEmail}
    });

    socket!.connect();

    socket!.onAny((event, data) {
      if (data is Map<String, dynamic>) {
        _socketStreamController.add(SocketEvent(event, data));
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