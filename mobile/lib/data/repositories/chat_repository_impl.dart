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
  final SignalManager signalManager = SignalManager();

  ChatRepositoryImpl(this.api, this.socket, this.localDb);

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
        if (msg.ciphertext != null && msg.ciphertext!.isNotEmpty && msg.content.isEmpty) {
          try {
            final plainText = await signalManager.decryptMessage(msg.senderId, msg.ciphertext!, msg.cipherType ?? 3);
            msg = msg.copyWith(content: plainText);
          } catch (e) {
            print('Error decrypting message on sync: $e');
            msg = msg.copyWith(content: '🔒 Mensagem Criptografada');
          }
        }
        await localDb.insertMessage(msg);
      }
      
      // Se não temos banco local (ex: web), retornamos os remotos decifrados
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
  Future<Message> sendMessage(String conversationId, String content, [String? recipientUserId]) async {
    String? finalCiphertext;
    int cipherType = 3;

    if (recipientUserId != null) {
      try {
        finalCiphertext = await signalManager.encryptMessage(recipientUserId, content);
        // Em um app real, o PreKeyWhisperMessage usaria tipo 1 e trocaria para 3 depois. Usamos 3 para WhisperMessage.
      } catch (e) {
        print('Erro de E2EE: $e. Tentaremos pegar a chave do servidor primeiro se a sessão não existir');
        try {
          // Fallback: Busca prekey do servidor e tenta processar a bundle
          final bundleRes = await api.dio.get('/devices/bundle/$recipientUserId');
          if (bundleRes.data != null) {
            await signalManager.processPreKeyBundle(recipientUserId, bundleRes.data);
            finalCiphertext = await signalManager.encryptMessage(recipientUserId, content);
            cipherType = 1; // 1 = PreKeyWhisperMessage (Signal protocol initialization)
          }
        } catch (innerE) {
          print('Falha final no E2EE: $innerE');
        }
      }
    }

    // Criamos a mensagem a ser enviada
    final messagePayload = {
      'conversationId': conversationId,
      'ciphertext': finalCiphertext,
      'cipher_type': cipherType,
      'type': 'text',
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
    return socket.onMessage.asyncMap((data) async {
      var msg = Message.fromJson(data);
      if (msg.ciphertext != null && msg.ciphertext!.isNotEmpty && msg.content.isEmpty) {
        try {
          final plainText = await signalManager.decryptMessage(msg.senderId, msg.ciphertext!, msg.cipherType ?? 3);
          msg = msg.copyWith(content: plainText);
        } catch (e) {
          print('Socket E2EE decryption failed: $e');
          msg = msg.copyWith(content: '🔒 Mensagem Criptografada');
        }
      }
      return msg;
    });
  }

  @override
  Stream<Map<String, dynamic>> get onMessageStatus {
    return socket.onMessageStatus;
  }
}
