enum MessageStatus { sending, sent, delivered, read, failed }

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content; // Pode estar cifrado ou decifrado dependendo do momento
  final String? nonce;  // Vetor de inicialização essencial para decriptar AES-GCM
  final MessageStatus status;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.nonce,
    this.status = MessageStatus.sent,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      content: json['content'] ?? '',
      nonce: json['nonce'],
      status: MessageStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'content': content,
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
}
