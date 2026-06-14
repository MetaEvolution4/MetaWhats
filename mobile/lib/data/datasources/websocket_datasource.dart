import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class WebSocketDatasource {
  IO.Socket? socket;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _callOfferController = StreamController<Map<String, dynamic>>.broadcast();
  final _callAnswerController = StreamController<Map<String, dynamic>>.broadcast();
  final _callIceCandidateController = StreamController<Map<String, dynamic>>.broadcast();
  final _callEndController = StreamController<Map<String, dynamic>>.broadcast();
  final _callRejectController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onMessageStatus => _messageStatusController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onCallOffer => _callOfferController.stream;
  Stream<Map<String, dynamic>> get onCallAnswer => _callAnswerController.stream;
  Stream<Map<String, dynamic>> get onCallIceCandidate => _callIceCandidateController.stream;
  Stream<Map<String, dynamic>> get onCallEnd => _callEndController.stream;
  Stream<Map<String, dynamic>> get onCallReject => _callRejectController.stream;

  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return;

    socket = IO.io(AppConstants.socketUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .enableForceNew()
      .setAuth({'token': token})
      .build());

    socket!.onConnect((_) {
      print('✅ Socket.IO connected!');
    });

    socket!.on('message:new', (data) {
      print('💌 NEW MESSAGE RECEIVED VIA SOCKET: $data');
      _messageController.add(Map<String, dynamic>.from(data));
    });

    socket!.on('message:status', (data) {
      print('💌 MESSAGE STATUS RECEIVED VIA SOCKET: $data');
      _messageStatusController.add(Map<String, dynamic>.from(data));
    });

    socket!.on('presence:online', (data) => _presenceController.add(Map<String, dynamic>.from(data)..[ 'status' ] = 'online'));
    socket!.on('presence:offline', (data) => _presenceController.add(Map<String, dynamic>.from(data)..[ 'status' ] = 'offline'));
    socket!.on('typing:start', (data) => _typingController.add(Map<String, dynamic>.from(data)..[ 'isTyping' ] = true));
    socket!.on('typing:stop', (data) => _typingController.add(Map<String, dynamic>.from(data)..[ 'isTyping' ] = false));

    socket!.on('call:offer', (data) => _callOfferController.add(Map<String, dynamic>.from(data)));
    socket!.on('call:answer', (data) => _callAnswerController.add(Map<String, dynamic>.from(data)));
    socket!.on('call:ice-candidate', (data) => _callIceCandidateController.add(Map<String, dynamic>.from(data)));
    socket!.on('call:end', (data) => _callEndController.add(Map<String, dynamic>.from(data)));
    socket!.on('call:reject', (data) => _callRejectController.add(Map<String, dynamic>.from(data)));

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
