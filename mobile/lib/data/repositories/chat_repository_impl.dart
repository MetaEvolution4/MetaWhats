import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../domain/entities/message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/api_datasource.dart';
import '../datasources/websocket_datasource.dart';
import '../datasources/local_db_datasource.dart';
import '../../core/encryption.dart';
import '../../core/encryption/media_encryption_manager.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ApiDatasource api;
  final WebSocketDatasource socket;
  final LocalDbDatasource localDb;
  ChatRepositoryImpl(this.api, this.socket, this.localDb);

  @override
  Future<List<Conversation>> getConversations() async {
    final response = await api.dio.get('/conversations');
    final List data = response.data;
    List<Conversation> convs = data.map((json) => Conversation.fromJson(json)).toList();

    // Decrypt last messages for preview
    for (var i = 0; i < convs.length; i++) {
      var conv = convs[i];
      if (conv.lastMessage != null) {
        var msg = conv.lastMessage!;
        if (msg.ciphertext != null && msg.ciphertext!.isNotEmpty && msg.content.isEmpty) {
          try {
            String content = '';
            if (conv.isGroup) {
              final groupKeyBase64 = await localDb.getGroupKey(conv.id);
              if (groupKeyBase64 != null) {
                final payload = jsonDecode(msg.ciphertext!);
                final mediaManager = MediaEncryptionManager();
                content = await mediaManager.decryptString(payload['ct'], groupKeyBase64, payload['iv']);
              }
            } else {
              content = msg.ciphertext ?? '';
              if (msg.type == 'group_key_distribution') {
                 content = '🔑 Group Key Received';
              }
            }
            if (content.isNotEmpty) {
              conv = Conversation(
                id: conv.id,
                isGroup: conv.isGroup,
                groupName: conv.groupName,
                participants: conv.participants,
                lastMessage: msg.copyWith(content: content),
                unreadCount: conv.unreadCount,
                updatedAt: conv.updatedAt,
              );
              convs[i] = conv;
            }
          } catch (e) {
            print('Error decrypting last message for conv ${conv.id}: $e');
          }
        }
      }
    }
    return convs;
  }

  @override
  Future<Conversation> createDirectConversation(String userId) async {
    final response = await api.dio.post('/conversations/direct', data: {
      'userId': userId,
    });
    return Conversation.fromJson(response.data);
  }

  @override
  Future<Conversation> createGroupConversation(String title, List<String> userIds) async {
    final response = await api.dio.post('/conversations/group', data: {
      'title': title,
      'userIds': userIds,
    });
    final group = Conversation.fromJson(response.data);

    // E2EE: Generate Group AES Key
    final mediaManager = MediaEncryptionManager(); // Reusing the AES utils we made
    final groupKeyBase64 = mediaManager.generateRandomKeyBase64(); // We need to add this method

    // Store the group key locally
    await localDb.saveGroupKey(group.id, groupKeyBase64); // We need to add this method

    // Distribute key to all participants individually
    for (final userId in userIds) {
      try {
        final groupKeyPayload = jsonEncode({
          'groupId': group.id,
          'groupKey': groupKeyBase64,
        });
        
        // We use the 1:1 Signal session to encrypt the group key for the recipient
        await sendMessage(group.id, groupKeyPayload, userId, 'group_key_distribution');
      } catch (e) {
        print('Error distributing group key to user $userId: $e');
      }
    }

    return group;
  }

  @override
  Future<List<Message>> getMessages(String conversationId) async {
    List<Message> localMessages = await localDb.getMessages(conversationId);
    List<Message> remoteMessages = [];

    try {
      final response = await api.dio.get('/conversations/$conversationId/messages');
      final List data = response.data;
      remoteMessages = data.map((json) => Message.fromJson(json)).toList();

      for (int i = 0; i < remoteMessages.length; i++) {
        var msg = remoteMessages[i];
        if (!localMessages.any((m) => m.id == msg.id)) {
          // Decrypt if needed
          if (msg.ciphertext != null && msg.ciphertext!.isNotEmpty && msg.content.isEmpty) {
            try {
              if (msg.cipherType == 4) {
                // Decrypt Group Message
                final groupKey = await localDb.getGroupKey(msg.conversationId);
                if (groupKey != null) {
                  final payload = jsonDecode(msg.ciphertext!);
                  final mediaManager = MediaEncryptionManager();
                  final plainText = await mediaManager.decryptString(payload['ct'], groupKey, payload['iv']);
                  msg = msg.copyWith(content: plainText);
                } else {
                  msg = msg.copyWith(content: '🔒 Waiting for Group Key');
                }
              } else {
                // Decrypt 1:1 Message (Signal)
                final plainText = msg.ciphertext ?? '';
                
                if (msg.type == 'group_key_distribution') {
                  // Save the group key
                  final payload = jsonDecode(plainText);
                  await localDb.saveGroupKey(payload['groupId'], payload['groupKey']);
                  msg = msg.copyWith(content: '🔑 Group Key Received', type: 'system');
                } else {
                  msg = msg.copyWith(content: plainText);
                }
              }
            } catch (e) {
              print('Error decrypting message on sync: $e');
              msg = msg.copyWith(content: '🔒 Mensagem Criptografada');
            }
          }
          
          remoteMessages[i] = msg; // Update the list with the decrypted message
          
          try {
            await localDb.insertMessage(msg);
          } catch (e) {
            // Ignore insert errors on Web
          }
        }
      }
      
      // Se não temos banco local (ex: web), retornamos os remotos decifrados
      if (localMessages.isEmpty && remoteMessages.isNotEmpty) {
        return remoteMessages;
      }

      localMessages = await localDb.getMessages(conversationId);
    } catch (e) {
      print('Erro ao sincronizar mensagens: $e');
    }

    // Retorna localMessages se tivermos banco, senao os remotos decifrados
    return localMessages.isNotEmpty ? localMessages : remoteMessages;
  }

  @override
  Future<Message> sendMessage(String conversationId, String content, [String? recipientUserId, String messageType = 'text', String? replyToMessageId, String? mediaId]) async {
    String finalCiphertext = '';
    int cipherType = 3;

    if (recipientUserId != null) {
      finalCiphertext = content;
    } else {
      // É um grupo: Usa a Symmetric Group Key
      final groupKey = await localDb.getGroupKey(conversationId);
      if (groupKey != null) {
        final mediaManager = MediaEncryptionManager();
        final encResult = await mediaManager.encryptString(content, groupKey);
        
        // Empacota o ciphertext e o IV no finalCiphertext (formato JSON)
        final groupPayload = {
          'ct': encResult['ciphertext'],
          'iv': encResult['ivBase64'],
        };
        finalCiphertext = jsonEncode(groupPayload);
        cipherType = 4; // 4 = Group Symmetric Message
      } else {
        print('Erro: Group Key não encontrada localmente. Mensagem será enviada em texto puro (não recomendado).');
        finalCiphertext = content;
        cipherType = 0;
      }
    }

    final messagePayload = {
      'conversationId': conversationId,
      'ciphertext': finalCiphertext,
      'cipher_type': cipherType,
      'type': messageType,
      'replyToMessageId': replyToMessageId,
      'mediaId': mediaId,
    };

    socket.sendMessage(messagePayload);

    // Opcionalmente podemos criar uma mensagem fake com status 'sending' 
    // enquanto o servidor não confirma, mas para o MVP, vamos aguardar a confirmação do servidor.
    // Como a API REST pode ser fallback:
    final response = await api.dio.post('/conversations/$conversationId/messages', data: messagePayload);
    final sentMessage = Message.fromJson(response.data);
    
    // Salva localmente a mensagem DECIFRADA para o remetente não perder o histórico
    final localCopy = sentMessage.copyWith(content: content, type: messageType);
    try {
      await localDb.insertMessage(localCopy);
    } catch (e) {
      // Ignora erro no web
    }

    return localCopy;
  }

  @override
  Future<Message> sendMediaMessage(String conversationId, XFile file, String type, [String? recipientUserId, String? replyToMessageId]) async {
    // Para o Passo 2: Upload direto sem criptografia E2EE (A ser adicionado no Passo 4)
    final bytes = await file.readAsBytes();
    final fileName = file.name;
    
    // 1. Fazer upload do binário
    final mediaId = await api.uploadMedia(bytes, fileName);

    // 2. Enviar mensagem avisando o backend do mediaId
    return await sendMessage(conversationId, 'Arquivo de Mídia', recipientUserId, type, replyToMessageId, mediaId);
  }
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
  Future<List<int>> downloadAndDecryptMedia(String innerPayloadJson) async {
    final payload = jsonDecode(innerPayloadJson);
    final String mediaId = payload['mediaId'];
    final String keyBase64 = payload['keyBase64'];
    final String ivBase64 = payload['ivBase64'];

    // 1. Download do binário criptografado
    final encryptedBytes = await api.downloadMedia(mediaId);

    // 2. Decriptar localmente
    final mediaManager = MediaEncryptionManager();
    final decryptedBytes = await mediaManager.decryptBytes(encryptedBytes, keyBase64, ivBase64);

    return decryptedBytes;
  }

  @override
  Stream<Message> get onMessageReceived {
    return socket.onMessage.asyncMap((data) async {
      var msg = Message.fromJson(data);
      if (msg.ciphertext != null && msg.ciphertext!.isNotEmpty && msg.content.isEmpty) {
        try {
          if (msg.cipherType == 4) {
            // Decrypt Group Message
            final groupKey = await localDb.getGroupKey(msg.conversationId);
            if (groupKey != null) {
              final payload = jsonDecode(msg.ciphertext!);
              final mediaManager = MediaEncryptionManager();
              final plainText = await mediaManager.decryptString(payload['ct'], groupKey, payload['iv']);
              msg = msg.copyWith(content: plainText);
            } else {
              msg = msg.copyWith(content: '🔒 Waiting for Group Key');
            }
          } else {
            // Decrypt 1:1 Message
            final plainText = msg.ciphertext ?? '';
            
            if (msg.type == 'group_key_distribution') {
              final payload = jsonDecode(plainText);
              await localDb.saveGroupKey(payload['groupId'], payload['groupKey']);
              msg = msg.copyWith(content: '🔑 Group Key Received', type: 'system');
            } else {
              msg = msg.copyWith(content: plainText);
            }
          }
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
