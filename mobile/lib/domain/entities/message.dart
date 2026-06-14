enum MessageStatus { sending, sent, delivered, read, failed }

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content; // Plaintext (after decryption)
  final String? ciphertext; // Raw ciphertext from backend
  final int? cipherType;
  final String? nonce;
  final MessageStatus status;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.ciphertext,
    this.cipherType,
    this.nonce,
    this.status = MessageStatus.sent,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? json['message_id'] ?? '',
      conversationId: json['conversationId'] ?? json['conversation_id'] ?? '',
      senderId: json['senderId'] ?? json['sender_id'] ?? '',
      content: json['content'] ?? '',
      ciphertext: json['ciphertext'],
      cipherType: json['cipherType'] ?? json['cipher_type'],
      nonce: json['nonce'],
      status: _parseStatus(json),
      createdAt: (json['createdAt'] != null || json['created_at'] != null)
          ? DateTime.parse(json['createdAt'] ?? json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'content': content,
      'ciphertext': ciphertext,
      'cipherType': cipherType,
      'nonce': nonce,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Método auxiliar para criar uma cópia da mensagem com conteúdo decifrado
  Message copyWith({
    String? content,
    MessageStatus? status,
  }) {
    return Message(
      id: this.id,
      conversationId: this.conversationId,
      senderId: this.senderId,
      content: content ?? this.content,
      nonce: this.nonce,
      status: status ?? this.status,
      createdAt: this.createdAt,
    );
  }

  static MessageStatus _parseStatus(Map<String, dynamic> json) {
    if (json['statuses'] != null && json['statuses'] is List) {
      final statuses = json['statuses'] as List;
      final senderId = json['senderId'] ?? json['sender_id'];
      
      bool isRead = false;
      bool isDelivered = false;
      
      for (var s in statuses) {
        if (s['user_id'] != senderId) {
          if (s['status'] == 'read') isRead = true;
          if (s['status'] == 'delivered') isDelivered = true;
        }
      }
      
      if (isRead) return MessageStatus.read;
      if (isDelivered) return MessageStatus.delivered;
    }
    
    return MessageStatus.values.firstWhere(
      (e) => e.toString().split('.').last == (json['status'] ?? 'sent'),
      orElse: () => MessageStatus.sent,
    );
  }
}
