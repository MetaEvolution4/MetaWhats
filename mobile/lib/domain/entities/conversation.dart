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
    List<User> participants = participantsList.map((p) {
      if (p.containsKey('user')) {
        return User.fromJson(p['user']);
      }
      return User.fromJson(p);
    }).toList();

    return Conversation(
      id: json['id'] ?? '',
      isGroup: json['isGroup'] ?? false,
      groupName: json['groupName'],
      participants: participants,
      lastMessage: json['lastMessage'] != null 
          ? Message.fromJson(json['lastMessage']) 
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }
}
