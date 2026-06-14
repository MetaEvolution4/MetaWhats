import 'dart:async';
import '../../domain/entities/message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/api_datasource.dart';
import '../datasources/websocket_datasource.dart';
import '../datasources/local_db_datasource.dart';
import '../../core/encryption.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ApiDatasource api;
  final WebSocketDatasource socket;
  final LocalDbDatasource localDb;
  final EncryptionService encryption;

  ChatRepositoryImpl(this.api, this.socket, this.localDb, this.encryption);

  @override
  Future<List<Conversation>> getConversations() async {
    final response = await api.dio.get('/conversations');
    final List data = response.data;
    return data.map((json) => Conversation.fromJson(json)).toList();
  }

  @override
  Future<Conversation> createDirectConversation(String userId) async {
    final response = await api.dio.post('/conversations/direct', data: {
      'userId': userId,
    });
    return Conversation.fromJson(response.data);
  }

  @override
  Future<List<Message>> getMessages(String conversationId) async {
    List<Message> localMessages = await localDb.getMessages(conversationId);
    List<Message> remoteMessages = [];
    
    try {
      final response = await api.dio.get('/conversations/$conversationId/messages');
      final List data = response.data;
      remoteMessages = data.map((json) => Message.fromJson(json)).toList();
      
      for (var msg in remoteMessages) {
        await localDb.insertMessage(msg);
      }
      
      // Se não temos banco local (ex: web), retornamos os remotos
      if (localMessages.isEmpty && remoteMessages.isNotEmpty) {
        return remoteMessages;
      }

      localMessages = await localDb.getMessages(conversationId);
    } catch (e) {
      print('Erro ao sincronizar mensagens: $e');
    }

    // Retorna localMessages se tivermos banco, senao os remotos (que podem ser vazios tb)
    return localMessages.isNotEmpty ? localMessages : remoteMessages;
  }

  @override
  Future<Message> sendMessage(String conversationId, String content, [String? recipientPublicKey]) async {
    String finalContent = content;
    String? finalNonce;

    // Se temos a chave pública do destinatário, criptografamos com AES-GCM
    if (recipientPublicKey != null) {
      final sharedSecret = await encryption.deriveSharedSecret(recipientPublicKey);
      final encryptedData = await encryption.encryptMessage(content, sharedSecret);
      finalContent = encryptedData.cipherText;
      finalNonce = encryptedData.nonce;
    }

    // Criamos a mensagem a ser enviada
    final messagePayload = {
      'conversationId': conversationId,
      'content': finalContent,
      'type': 'text',
      'nonce': finalNonce,
    };

    // Envia via Socket.IO
    socket.sendMessage(messagePayload);

    // Opcionalmente podemos criar uma mensagem fake com status 'sending' 
    // enquanto o servidor não confirma, mas para o MVP, vamos aguardar a confirmação do servidor.
    // Como a API REST pode ser usada como fallback:
    final response = await api.dio.post('/conversations/$conversationId/messages', data: messagePayload);
    final sentMessage = Message.fromJson(response.data);
    
    // Salva localmente a mensagem DECIFRADA para o remetente não perder o histórico
    final localCopy = sentMessage.copyWith(content: content);
    await localDb.insertMessage(localCopy);

    return localCopy;
  }

  @override
  Future<void> markAsRead(String messageId) async {
    try {
      await api.dio.post('/messages/$messageId/read');
    } catch (e) {
      print('Erro ao marcar como lida: $e');
    }
  }

  @override
  Future<void> markAsDelivered(String messageId) async {
    try {
      await api.dio.post('/messages/$messageId/delivered');
    } catch (e) {
      print('Erro ao marcar como entregue: $e');
    }
  }

  @override
  Stream<Message> get onMessageReceived {
    return socket.onMessage.map((data) {
      return Message.fromJson(data);
    });
  }

  @override
  Stream<Map<String, dynamic>> get onMessageStatus {
    return socket.onMessageStatus;
  }
}
