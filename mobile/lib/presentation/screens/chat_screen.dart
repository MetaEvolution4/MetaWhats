import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/user.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final User? contact;
  final Conversation? conversation;
  final User? currentUser;

  const ChatScreen({super.key, this.contact, this.conversation, this.currentUser});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  User? _currentUser;
  Conversation? _currentConversation;
  List<Message> _messages = [];
  List<User> _contacts = [];
  bool _isLoading = true;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  StreamSubscription<Message>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _messageStatusSub;
  Timer? _pollingTimer;

  // Audio Recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _hasText = false;

  // Presence & Typing
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<Map<String, dynamic>>? _presenceSub;
  bool _isTyping = false;
  Timer? _typingTimer;
  String _presenceStatus = 'Desconectado';
  
  // Replying
  Message? _replyingToMessage;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _messageController.addListener(() {
      final text = _messageController.text.trim();
      setState(() {
        _hasText = text.isNotEmpty;
      });
      _handleTyping(text.isNotEmpty);
    });
    _initChat();
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isLoading && mounted && _currentConversation != null) {
        _pollMessages();
      }
    });
  }

  void _handleTyping(bool isTyping) {
    if (_currentConversation == null) return;
    final socketDs = ref.read(webSocketDatasourceProvider);
    if (isTyping) {
      socketDs.socket?.emit('typing:start', {'conversationId': _currentConversation!.id});
      // Auto stop after 3 seconds of no typing
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        socketDs.socket?.emit('typing:stop', {'conversationId': _currentConversation!.id});
      });
    } else {
      socketDs.socket?.emit('typing:stop', {'conversationId': _currentConversation!.id});
      _typingTimer?.cancel();
    }
  }

  Future<void> _initChat() async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      
      // 1. Resolve Conversation
      if (widget.conversation != null) {
        _currentConversation = widget.conversation;
      } else if (widget.contact != null) {
        // Find or Create Direct Conversation
        _currentConversation = await chatRepo.createDirectConversation(widget.contact!.id);
      } else {
        if (mounted) context.pop();
        return;
      }

      // 2. Load old messages, contacts and current user
      final messages = await chatRepo.getMessages(_currentConversation!.id);
      
      final uniqueMessages = <Message>[];
      final seenIds = <String>{};
      for (var msg in messages) {
        if (!seenIds.contains(msg.id)) {
          seenIds.add(msg.id);
          uniqueMessages.add(msg);
        }
      }

      final contactRepo = ref.read(contactRepositoryProvider);
      final contacts = await contactRepo.getContacts();
      final authRepo = ref.read(authRepositoryProvider);
      final me = await authRepo.getCurrentUser();
      
      // Mark as read
      for (var msg in uniqueMessages) {
        if (msg.senderId != me?.id && msg.status != MessageStatus.read) {
          chatRepo.markAsRead(msg.id);
        }
      }
      
      if (mounted) {
        setState(() {
          _messages = uniqueMessages;
          _contacts = contacts;
          _currentUser = me;
          _isLoading = false;
        });
        _scrollToBottom();
      }

      // 3. Listen to new messages via WebSocket
      _messageSub = chatRepo.onMessageReceived.listen((newMessage) {
        if (newMessage.conversationId == _currentConversation?.id) {
          if (newMessage.senderId != _currentUser?.id) {
            chatRepo.markAsRead(newMessage.id);
          }
          if (mounted) {
            setState(() {
              // Verifica se a mensagem já não foi adicionada manualmente no _sendMessage
              if (!_messages.any((m) => m.id == newMessage.id)) {
                _messages.add(newMessage);
                _scrollToBottom();
              }
            });
          }
        }
      });

      // 4. Listen to message status updates
      _messageStatusSub = chatRepo.onMessageStatus.listen((statusUpdate) {
        final messageId = statusUpdate['messageId'];
        final statusStr = statusUpdate['status'];
        final userId = statusUpdate['userId'];

        if (mounted && messageId != null && statusStr != null) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == messageId);
            if (index != -1) {
              final msg = _messages[index];
              if (msg.senderId != userId) {
                MessageStatus newStatus = msg.status;
                if (statusStr == 'read') newStatus = MessageStatus.read;
                if (statusStr == 'delivered' && msg.status != MessageStatus.read) newStatus = MessageStatus.delivered;
                
                _messages[index] = msg.copyWith(status: newStatus);
              }
            }
          });
        }
      });

      // 5. Listen to typing and presence
      final socketDs = ref.read(webSocketDatasourceProvider);
      _typingSub = socketDs.onTyping.listen((data) {
        if (data['conversationId'] == _currentConversation?.id) {
          if (data['userId'] != _currentUser?.id) {
            if (mounted) {
              setState(() {
                _isTyping = data['isTyping'] == true;
              });
            }
          }
        }
      });

      _presenceSub = socketDs.onPresence.listen((data) {
        if (!(_currentConversation?.isGroup ?? true)) {
          final otherUser = _currentConversation!.participants.firstWhere((p) => p.id != _currentUser?.id);
          if (data['userId'] == otherUser.id) {
            if (mounted) {
              setState(() {
                if (data['status'] == 'online') {
                  _presenceStatus = 'Online';
                } else {
                  _presenceStatus = 'Visto recentemente'; // MVP
                }
              });
            }
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _pollMessages() async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final newMessages = await chatRepo.getMessages(_currentConversation!.id);
      
      bool hasNew = false;
      for (var msg in newMessages) {
        if (!_messages.any((m) => m.id == msg.id)) {
          _messages.add(msg);
          hasNew = true;
          if (msg.senderId != _currentUser?.id && msg.status != MessageStatus.read) {
            chatRepo.markAsRead(msg.id);
          }
        } else {
          // Update status of existing messages
          final index = _messages.indexWhere((m) => m.id == msg.id);
          if (index != -1 && _messages[index].status != msg.status) {
            _messages[index] = msg;
            hasNew = true;
          }
        }
      }
      
      if (hasNew && mounted) {
        setState(() {});
        _scrollToBottom();
      }
    } catch (e) {
      // Ignore polling errors
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _messageSub?.cancel();
    _messageStatusSub?.cancel();
    _typingSub?.cancel();
    _presenceSub?.cancel();
    _typingTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentConversation == null) return;

    final replyId = _replyingToMessage?.id;
    _messageController.clear();
    setState(() {
      _replyingToMessage = null;
    });
    _focusNode.requestFocus();
    
    // Determine recipient user id if direct chat
    String? recipientUserId;
    if (!_currentConversation!.isGroup && widget.contact != null) {
      recipientUserId = widget.contact!.id;
    }

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final sentMsg = await chatRepo.sendMessage(_currentConversation!.id, text, recipientUserId, 'text', replyId);
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == sentMsg.id)) {
            _messages.add(sentMsg);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao enviar: $e')));
      }
    }
  }

  Future<void> _pickAndSendMedia(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile == null || _currentConversation == null) return;

    String? recipientUserId;
    if (!_currentConversation!.isGroup && widget.contact != null) {
      recipientUserId = widget.contact!.id;
    }

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final sentMsg = await chatRepo.sendMediaMessage(
        _currentConversation!.id,
        pickedFile,
        'image',
        recipientUserId,
      );
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == sentMsg.id)) {
            _messages.add(sentMsg);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao enviar mídia: $e')));
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start recording: $e')));
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null && _currentConversation != null) {
        String? recipientUserId;
        if (!_currentConversation!.isGroup && widget.contact != null) {
          recipientUserId = widget.contact!.id;
        }

        final chatRepo = ref.read(chatRepositoryProvider);
        final sentMsg = await chatRepo.sendMediaMessage(
          _currentConversation!.id,
          path,
          'audio',
          recipientUserId,
        );
        if (mounted) {
          setState(() {
            if (!_messages.any((m) => m.id == sentMsg.id)) {
              _messages.add(sentMsg);
            }
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to stop recording: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine display name
    String displayName = 'Chat';
    if (widget.contact != null) {
      displayName = widget.contact!.name ?? widget.contact!.phone;
    } else if (widget.conversation != null) {
      if (widget.conversation!.isGroup) {
        displayName = widget.conversation!.groupName ?? 'Grupo';
      } else {
        // Try to find the other participant
        final otherUsers = widget.conversation!.participants.where((p) => p.id != _currentUser?.id).toList();
        if (otherUsers.isNotEmpty) {
          final otherUser = otherUsers.first;
          final contact = _contacts.where((c) => c.phone == otherUser.phone).firstOrNull;
          if (contact != null && contact.name != null && contact.name!.isNotEmpty) {
            displayName = contact.name!;
          } else {
            displayName = otherUser.name ?? otherUser.phone;
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Deep Premium Black
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [const Color(0xFF00E676), const Color(0xFF00E676).withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, color: Colors.black87, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isTyping ? 'Digitando...' : _presenceStatus, 
                    style: TextStyle(
                      color: _isTyping ? const Color(0xFF00E676) : Colors.white70, 
                      fontSize: 12,
                      fontStyle: _isTyping ? FontStyle.italic : FontStyle.normal,
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white), 
            onPressed: () {
              if (_currentConversation != null && !_currentConversation!.isGroup) {
                try {
                  String? targetUserId;
                  if (widget.contact != null) {
                    targetUserId = widget.contact!.id;
                  } else {
                    final otherUsers = _currentConversation!.participants.where((p) => p.id != _currentUser?.id).toList();
                    if (otherUsers.isNotEmpty) {
                      targetUserId = otherUsers.first.id;
                    } else if (_currentConversation!.participants.isNotEmpty) {
                      targetUserId = _currentConversation!.participants.first.id;
                    }
                  }
                  
                  if (targetUserId != null) {
                    context.push('/call', extra: {
                      'targetUserId': targetUserId,
                      'conversationId': _currentConversation!.id,
                      'isVideo': true,
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário alvo não encontrado')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao ligar: $e')));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não é possível ligar em grupo ainda')));
              }
            }
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white), 
            onPressed: () {
              if (_currentConversation != null && !_currentConversation!.isGroup) {
                try {
                  String? targetUserId;
                  if (widget.contact != null) {
                    targetUserId = widget.contact!.id;
                  } else {
                    final otherUsers = _currentConversation!.participants.where((p) => p.id != _currentUser?.id).toList();
                    if (otherUsers.isNotEmpty) {
                      targetUserId = otherUsers.first.id;
                    } else if (_currentConversation!.participants.isNotEmpty) {
                      targetUserId = _currentConversation!.participants.first.id;
                    }
                  }
                  
                  if (targetUserId != null) {
                    context.push('/call', extra: {
                      'targetUserId': targetUserId,
                      'conversationId': _currentConversation!.id,
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário alvo não encontrado')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao ligar: $e')));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não é possível ligar')));
              }
            }
          ),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: const NetworkImage('https://i.imgur.com/igjrUOE.png'), // Subtle dark pattern
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.9), BlendMode.darken),
                      ),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        
                        // Check if we need a date header
                        bool showDateHeader = false;
                        if (index == 0) {
                          showDateHeader = true;
                        } else {
                          final prevMsg = _messages[index - 1];
                          if (msg.createdAt.year != prevMsg.createdAt.year ||
                              msg.createdAt.month != prevMsg.createdAt.month ||
                              msg.createdAt.day != prevMsg.createdAt.day) {
                            showDateHeader = true;
                          }
                        }

                        // We need to know if the message is from me or the other person
                        // For MVP, we assume if senderId != contact.id, it's mine.
                        // Ideally we check against our own user ID.
                        bool isMe = true;
                        if (widget.contact != null && msg.senderId == widget.contact!.id) {
                          isMe = false;
                        } else if (_currentUser != null && msg.senderId != _currentUser!.id) {
                          isMe = false;
                        }

                        if (showDateHeader) {
                          return Column(
                            children: [
                              _buildDateHeader(msg.createdAt),
                              _buildMessageBubble(msg, isMe),
                            ],
                          );
                        }

                        return _buildMessageBubble(msg, isMe);
                      },
                    ),
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    String text;
    if (msgDate == today) {
      text = 'Hoje';
    } else if (msgDate == yesterday) {
      text = 'Ontem';
    } else {
      text = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe) {
    Message? repliedMsg;
    if (msg.replyToMessageId != null) {
      repliedMsg = _messages.where((m) => m.id == msg.replyToMessageId).firstOrNull;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            // Swipe right to reply
            setState(() {
              _replyingToMessage = msg;
            });
            _focusNode.requestFocus();
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF00E676) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 2),
              blurRadius: 4,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (repliedMsg != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: Colors.white, width: 3)),
                ),
                child: Text(
                  repliedMsg.content,
                  style: TextStyle(color: isMe ? Colors.black87 : Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (msg.type == 'image' && msg.content.startsWith('{'))
              _MediaMessageBubble(message: msg)
            else if (msg.type == 'audio' && msg.content.startsWith('{'))
              _AudioMessageBubble(message: msg, isMe: isMe)
            else
              Text(
                msg.content.isEmpty ? (msg.ciphertext ?? 'VAZIO') : msg.content,
                style: TextStyle(
                  color: isMe ? Colors.black87 : Colors.white,
                  fontSize: 16,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: isMe ? Colors.black54 : Colors.grey,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.status == MessageStatus.sent ? Icons.check : Icons.done_all,
                    size: 15,
                    color: msg.status == MessageStatus.read ? Colors.blue : Colors.black54,
                  ),
                ]
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: const Color(0xFF0A0A0A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: Color(0xFF00E676), width: 4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyingToMessage!.senderId == _currentUser?.id ? 'Você' : 'Contato',
                          style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _replyingToMessage!.content,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                    onPressed: () => setState(() => _replyingToMessage = null),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                        onPressed: () {},
                      ),
                      Expanded(
                        child: _isRecording 
                            ? const Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text('Gravando áudio...', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                              )
                            : TextField(
                                controller: _messageController,
                                focusNode: _focusNode,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Mensagem',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                      ),
                      if (!_isRecording && !_hasText) ...[
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: Colors.grey),
                          onPressed: () => _pickAndSendMedia(ImageSource.gallery),
                        ),
                        IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.grey),
                          onPressed: () => _pickAndSendMedia(ImageSource.camera),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          const SizedBox(width: 8),
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            onTap: _hasText ? _sendMessage : null,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E676),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _hasText ? Icons.send : (_isRecording ? Icons.mic_off : Icons.mic),
                color: Colors.black87,
                size: 24,
              ),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }
}

class _MediaMessageBubble extends StatelessWidget {
  final Message message;
  const _MediaMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.mediaPayload == null || message.mediaPayload!['public_url'] == null) {
      return const SizedBox(
        width: 150,
        height: 150,
        child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    }

    final publicUrl = message.mediaPayload!['public_url'];
    // For Web/Mobile, we can use simple Image.network with the API base URL
    final imageUrl = '${AppConstants.baseUrl}$publicUrl';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: 250,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox(
            width: 150,
            height: 150,
            child: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
          );
        },
        errorBuilder: (context, error, stackTrace) => const SizedBox(
          width: 150,
          height: 150,
          child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
        ),
      ),
    );
  }
}

class _AudioMessageBubble extends ConsumerStatefulWidget {
  final Message message;
  final bool isMe;
  const _AudioMessageBubble({required this.message, required this.isMe});

  @override
  ConsumerState<_AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends ConsumerState<_AudioMessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _loadMedia();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  Future<void> _loadMedia() async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final bytes = await chatRepo.downloadAndDecryptMedia(widget.message.content);
      
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/audio_${widget.message.id}.m4a');
      await file.writeAsBytes(bytes);
      
      if (mounted) {
        setState(() {
          _localPath = file.path;
          _isLoading = false;
        });
        await _audioPlayer.setSourceDeviceFile(_localPath!);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 150,
        height: 40,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
      );
    }

    if (_localPath == null) {
      return const Text('🎵 Erro ao carregar áudio', style: TextStyle(color: Colors.red));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: widget.isMe ? Colors.black87 : Colors.white),
          onPressed: () {
            if (_isPlaying) {
              _audioPlayer.pause();
            } else {
              _audioPlayer.play(DeviceFileSource(_localPath!));
            }
          },
        ),
        Slider(
          value: _position.inSeconds.toDouble(),
          min: 0,
          max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1,
          onChanged: (val) {
            _audioPlayer.seek(Duration(seconds: val.toInt()));
          },
          activeColor: widget.isMe ? Colors.black87 : const Color(0xFF00E676),
          inactiveColor: widget.isMe ? Colors.black26 : Colors.white24,
        ),
        Text(
          '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}',
          style: TextStyle(color: widget.isMe ? Colors.black87 : Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
