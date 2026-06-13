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
  Future<List<Message>> getMessages(String conversationId) async {
    // Tenta buscar as mensagens do banco local primeiro para ser instantâneo
    List<Message> localMessages = await localDb.getMessages(conversationId);
    
    // Opcional: Buscar novas mensagens na API para sincronização
    try {
      final response = await api.dio.get('/messages/$conversationId');
      final List data = response.data;
      List<Message> remoteMessages = data.map((json) => Message.fromJson(json)).toList();
      
      // Salva ou atualiza as mensagens remotas no banco local (ignorando conflitos ou substituindo)
      for (var msg in remoteMessages) {
        await localDb.insertMessage(msg);
      }
      
      // Busca novamente do banco local ordenado
      localMessages = await localDb.getMessages(conversationId);
    } catch (e) {
      print('Erro ao sincronizar mensagens: $e');
    }

    return localMessages;
  }

  @override
  Future<Message> sendMessage(String conversationId, String content, String? recipientPublicKey) async {
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
      'nonce': finalNonce,
    };

    // Envia via Socket.IO
    socket.sendMessage(messagePayload);

    // Opcionalmente podemos criar uma mensagem fake com status 'sending' 
    // enquanto o servidor não confirma, mas para o MVP, vamos aguardar a confirmação do servidor.
    // Como a API REST pode ser usada como fallback:
    final response = await api.dio.post('/messages', data: messagePayload);
    final sentMessage = Message.fromJson(response.data);
    
    // Salva localmente a mensagem DECIFRADA para o remetente não perder o histórico
    final localCopy = sentMessage.copyWith(content: content);
    await localDb.insertMessage(localCopy);

    return localCopy;
  }

  @override
  Stream<Message> get onMessageReceived {
    return socket.onMessage.map((data) {
      return Message.fromJson(data);
    });
  }
}
