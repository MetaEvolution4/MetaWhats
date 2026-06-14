import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/webrtc/webrtc_manager.dart';

class CallScreen extends StatefulWidget {
  final String targetUserId;
  final String conversationId;
  final Map<String, dynamic>? incomingOffer;
  
  const CallScreen({
    super.key, 
    required this.targetUserId, 
    required this.conversationId,
    this.incomingOffer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRTCManager _rtcManager = WebRTCManager();
  bool _isMuted = false;
  bool _isSpeaker = false;

  @override
  void initState() {
    super.initState();
    _rtcManager.onCallEnded = () {
      if (mounted) {
        context.pop();
      }
    };
    
    if (widget.incomingOffer != null) {
      _rtcManager.handleOffer(widget.targetUserId, widget.conversationId, widget.incomingOffer!);
    } else {
      _rtcManager.startCall(widget.targetUserId, widget.conversationId);
    }
  }

  @override
  void dispose() {
    _rtcManager.endCall();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    // In a full implementation, we would extract the audio track from _rtcManager._localStream and set track.enabled = !_isMuted
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeaker = !_isSpeaker;
    });
    // Not directly supported without native code or specific flutter_webrtc speakerphone routing
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
        child: Column(
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
              widget.incomingOffer != null ? 'Conectado' : 'Chamando...',
              style: const TextStyle(color: Color(0xFF00E676), fontSize: 16),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  color: _isMuted ? Colors.white : Colors.white24,
                  onPressed: _toggleMute,
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
                  onPressed: _toggleSpeaker,
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, Color iconColor = Colors.black87, required VoidCallback onPressed, double size = 56}) {
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
