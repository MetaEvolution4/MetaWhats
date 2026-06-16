import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/webrtc/webrtc_manager.dart';

class CallScreen extends StatefulWidget {
  final String targetUserId;
  final String conversationId;
  final Map<String, dynamic>? incomingOffer;
  final bool isVideo;
  
  const CallScreen({
    super.key, 
    required this.targetUserId, 
    required this.conversationId,
    this.incomingOffer,
    this.isVideo = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRTCManager _rtcManager = WebRTCManager();
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoEnabled = true;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isLocalRendererInitialized = false;
  bool _isRemoteRendererInitialized = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    
    _rtcManager.onCallEnded = () {
      if (mounted) {
        context.pop();
      }
    };
    
    _rtcManager.onLocalStream = (stream) {
      if (widget.isVideo && mounted) {
        _localRenderer.srcObject = stream;
        setState(() {});
      }
    };

    _rtcManager.onAddRemoteStream = (stream) {
      if (widget.isVideo && mounted) {
        _remoteRenderer.srcObject = stream;
        setState(() {});
      }
    };

    if (widget.incomingOffer != null) {
      _rtcManager.handleOffer(widget.targetUserId, widget.conversationId, widget.incomingOffer!, isVideo: widget.isVideo);
    } else {
      _rtcManager.startCall(widget.targetUserId, widget.conversationId, isVideo: widget.isVideo);
    }
  }

  Future<void> _initRenderers() async {
    if (widget.isVideo) {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      if (mounted) {
        setState(() {
          _isLocalRendererInitialized = true;
          _isRemoteRendererInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _rtcManager.onCallEnded = null;
    _rtcManager.onLocalStream = null;
    _rtcManager.onAddRemoteStream = null;
    _rtcManager.endCall();
    
    if (widget.isVideo) {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    }
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleVideo() {
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeaker = !_isSpeaker;
    });
  }

  void _endCall() {
    _rtcManager.endCall();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: widget.isVideo ? _buildVideoLayout() : _buildAudioLayout(),
      ),
    );
  }

  Widget _buildAudioLayout() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const CircleAvatar(
          radius: 60,
          backgroundColor: Color(0xFF1E1E1E),
          child: Icon(Icons.person, size: 60, color: Colors.white54),
        ),
        const SizedBox(height: 24),
        const Text(
          'Chamada de Áudio',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          widget.incomingOffer != null || _remoteRenderer.srcObject != null ? 'Conectado' : 'Chamando...',
          style: const TextStyle(color: Color(0xFF00E676), fontSize: 16),
        ),
        const Spacer(),
        _buildControls(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildVideoLayout() {
    return Stack(
      children: [
        // Remote Video (Full Screen)
        if (_isRemoteRendererInitialized && _remoteRenderer.srcObject != null)
          Positioned.fill(
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          )
        else
          Container(
            color: const Color(0xFF1E1E1E),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00E676)),
                  SizedBox(height: 16),
                  Text('Aguardando vídeo...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
          
        // Local Video (PiP)
        if (_isLocalRendererInitialized && _isVideoEnabled)
          Positioned(
            right: 16,
            bottom: 120,
            width: 100,
            height: 150,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 2),
                color: Colors.black,
              ),
              clipBehavior: Clip.antiAlias,
              child: RTCVideoView(
                _localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
          
        // Header
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Chamada de Vídeo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),

        // Controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: _buildControls(),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          color: _isMuted ? Colors.white : Colors.white24,
          iconColor: _isMuted ? Colors.black87 : Colors.white,
          onPressed: _toggleMute,
        ),
        if (widget.isVideo)
          _buildActionButton(
            icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            color: _isVideoEnabled ? Colors.white24 : Colors.white,
            iconColor: _isVideoEnabled ? Colors.white : Colors.black87,
            onPressed: _toggleVideo,
          ),
        _buildActionButton(
          icon: Icons.call_end,
          color: Colors.redAccent,
          iconColor: Colors.white,
          onPressed: _endCall,
          size: 64,
        ),
        _buildActionButton(
          icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
          color: _isSpeaker ? Colors.white : Colors.white24,
          iconColor: _isSpeaker ? Colors.black87 : Colors.white,
          onPressed: _toggleSpeaker,
        ),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required Color iconColor, required VoidCallback onPressed, double size = 56}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}
