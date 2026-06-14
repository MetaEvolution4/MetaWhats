import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class WebSocketDatasource {
  IO.Socket? socket;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return;

    socket = IO.io(AppConstants.socketUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .setAuth({'token': token})
      .build());

    socket!.onConnect((_) {
      print('✅ Socket.IO connected!');
    });

    socket!.on('message:new', (data) {
      print('💌 NEW MESSAGE RECEIVED VIA SOCKET: $data');
      _messageController.add(Map<String, dynamic>.from(data));
    });

    socket!.onDisconnect((_) => print('❌ Socket.IO disconnected!'));
    
    socket!.connect();
  }

  void sendMessage(Map<String, dynamic> payload) {
    if (socket != null && socket!.connected) {
      socket!.emit('sendMessage', payload);
    } else {
      print('⚠️ Socket is not connected, cannot send message.');
    }
  }

  void disconnect() {
    socket?.disconnect();
  }
}
