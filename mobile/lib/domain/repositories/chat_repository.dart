import 'package:image_picker/image_picker.dart';
import '../entities/message.dart';
import '../entities/conversation.dart';

abstract class ChatRepository {
  Future<List<Conversation>> getConversations();
  Future<Conversation> createDirectConversation(String userId);
  Future<Conversation> createGroupConversation(String title, List<String> userIds);
  Future<List<Message>> getMessages(String conversationId);
  // O conteúdo aqui deve ser o texto original, a implementação cuida da criptografia
  Future<Message> sendMessage(String conversationId, String content, [String? recipientUserId, String messageType = 'text', String? replyToMessageId]);
  Future<Message> sendMediaMessage(String conversationId, XFile file, String type, [String? recipientUserId, String? replyToMessageId]);
  Future<List<int>> downloadAndDecryptMedia(String innerPayloadJson);
  Future<void> markAsRead(String messageId);
  Future<void> markAsDelivered(String messageId);
  Stream<Message> get onMessageReceived;
  Stream<Map<String, dynamic>> get onMessageStatus;
}
