import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/webrtc/webrtc_manager.dart';

class IncomingCallDialog extends StatelessWidget {
  final String callerId;
  final String callerName;
  final String conversationId;
  final Map<String, dynamic> offer;
  final bool isVideo;

  const IncomingCallDialog({
    super.key,
    required this.callerId,
    required this.callerName,
    required this.conversationId,
    required this.offer,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFF1E1E1E),
              child: Icon(Icons.person, size: 40, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            Text(
              isVideo ? 'Chamada de Vídeo' : 'Chamada de Áudio',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              callerName,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    // Reject
                    WebRTCManager().rejectCall(callerId);
                    context.pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // Accept
                    context.pop();
                    context.push('/call', extra: {
                      'targetUserId': callerId,
                      'conversationId': conversationId,
                      'offer': offer,
                      'isVideo': isVideo,
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call, color: Colors.black87, size: 32),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
