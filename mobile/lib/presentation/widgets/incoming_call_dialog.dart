import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class IncomingCallDialog extends StatelessWidget {
  final String callerId;
  final String conversationId;
  final Map<String, dynamic> offer;

  const IncomingCallDialog({
    super.key,
    required this.callerId,
    required this.conversationId,
    required this.offer,
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
            const Text(
              'Chamada de Áudio',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Contato $callerId',
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
