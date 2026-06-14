import '../entities/message.dart';
import '../entities/conversation.dart';

abstract class ChatRepository {
  Future<List<Conversation>> getConversations();
  Future<Conversation> createDirectConversation(String userId);
  Future<List<Message>> getMessages(String conversationId);
  // O conteúdo aqui deve ser o texto original, a implementação cuida da criptografia
  Future<Message> sendMessage(String conversationId, String content, String? recipientPublicKey);
  Stream<Message> get onMessageReceived;
}
