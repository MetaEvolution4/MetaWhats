import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../data/datasources/websocket_datasource.dart';

class WebRTCManager {
  static final WebRTCManager _instance = WebRTCManager._internal();
  factory WebRTCManager() => _instance;
  WebRTCManager._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  WebSocketDatasource? _socket;
  String? _targetUserId;
  String? _conversationId;

  // Configuration for STUN/TURN servers
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
    ]
  };

  // Callbacks for UI
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onAddRemoteStream;
  Function()? onCallEnded;

  void initialize(WebSocketDatasource socket) {
    _socket = socket;
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    if (_socket == null) return;
    
    _socket!.onCallOffer.listen((data) {
      if (data['targetUserId'] != null) {
        // Normally handled by UI to show IncomingCallDialog first
      }
    });

    _socket!.onCallAnswer.listen((data) {
      if (data['answer'] != null) {
        handleAnswer(data['answer'] is Map ? Map<String, dynamic>.from(data['answer']) : {});
      }
    });

    _socket!.onCallIceCandidate.listen((data) {
      if (data['candidate'] != null) {
        handleIceCandidate(data['candidate'] is Map ? Map<String, dynamic>.from(data['candidate']) : {});
      }
    });

    _socket!.onCallEnd.listen((_) {
      handleRemoteEndCall();
    });

    _socket!.onCallReject.listen((_) {
      handleRemoteEndCall();
    });
  }

  Future<void> startCall(String targetUserId, String conversationId, {bool isVideo = false}) async {
    _targetUserId = targetUserId;
    _conversationId = conversationId;
    
    await _initLocalStream(isVideo: isVideo);
    await _createPeerConnection();
    
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    Map<String, dynamic> offerMap = Map<String, dynamic>.from(offer.toMap());
    offerMap['isVideo'] = isVideo; // Injecting inside offer to bypass backend dropping fields

    _socket?.socket?.emit('call:start', {
      'recipientId': targetUserId,
      'conversationId': conversationId,
      'isVideo': isVideo,
      'offer': offerMap,
    });
  }

  Future<void> handleOffer(String callerId, String conversationId, Map<String, dynamic> offerMap, {bool isVideo = false}) async {
    _targetUserId = callerId;
    _conversationId = conversationId;

    await _initLocalStream(isVideo: isVideo);
    await _createPeerConnection();

    await _peerConnection!.setRemoteDescription(RTCSessionDescription(offerMap['sdp'], offerMap['type']));
    
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socket?.socket?.emit('call:answer', {
      'recipientId': callerId,
      'conversationId': _conversationId,
      'answer': answer.toMap(),
    });
  }

  Future<void> handleAnswer(Map<String, dynamic> answerMap) async {
    if (_peerConnection != null) {
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(answerMap['sdp'], answerMap['type']));
    }
  }

  Future<void> handleIceCandidate(Map<String, dynamic> candidateMap) async {
    if (_peerConnection != null) {
      await _peerConnection!.addCandidate(RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      ));
    }
  }

  Future<void> endCall() async {
    if (_targetUserId != null) {
      _socket?.socket?.emit('call:end', {
        'targetUserId': _targetUserId,
      });
    }
    _cleanup();
  }

  void rejectCall(String targetUserId) {
    _socket?.socket?.emit('call:reject', {
      'targetUserId': targetUserId,
    });
    _cleanup();
  }
  
  void handleRemoteEndCall() {
    _cleanup();
  }

  Future<void> _initLocalStream({bool isVideo = false}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideo,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      if (onLocalStream != null) {
        onLocalStream!(_localStream!);
      }
    } catch (e) {
      print('Erro getUserMedia: $e');
      // Continue sem áudio se falhar para não travar o app
    }
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_targetUserId != null) {
        _socket?.socket?.emit('call:ice-candidate', {
          'recipientId': _targetUserId,
          'conversationId': _conversationId,
          'candidate': candidate.toMap(),
        });
      }
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      _remoteStream = stream;
      if (onAddRemoteStream != null) {
        onAddRemoteStream!(stream);
      }
    };

    if (_localStream != null) {
      _peerConnection!.addStream(_localStream!);
    }
  }

  void _cleanup() {
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.dispose();
    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    _targetUserId = null;
    _conversationId = null;
    
    if (onCallEnded != null) {
      onCallEnded!();
    }
  }
}
