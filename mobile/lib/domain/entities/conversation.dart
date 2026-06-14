import 'user.dart';
import 'message.dart';

class Conversation {
  final String id;
  final bool isGroup;
  final String? groupName;
  final List<User> participants;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.isGroup,
    this.groupName,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // Trata a estrutura aninhada que o Prisma retorna (conversation.participants[].user)
    var participantsList = json['participants'] as List? ?? [];
    List<User> participants = [];
    for (var p in participantsList) {
      try {
        if (p is Map<String, dynamic>) {
          if (p.containsKey('user') && p['user'] != null) {
            participants.add(User.fromJson(p['user']));
          } else if (p.containsKey('phone') && p['phone'] != null) {
            participants.add(User.fromJson(p));
          }
        }
      } catch (e) {
        // Ignora participantes incompletos que o backend pode retornar no createDirect
      }
    }

    return Conversation(
      id: json['id'] ?? '',
      isGroup: json['isGroup'] ?? false,
      groupName: json['groupName'],
      participants: participants,
      lastMessage: (json['messages'] != null && json['messages'].isNotEmpty)
          ? Message.fromJson(json['messages'][0])
          : (json['lastMessage'] != null ? Message.fromJson(json['lastMessage']) : null),
      unreadCount: json['unreadCount'] ?? 0,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }
}
