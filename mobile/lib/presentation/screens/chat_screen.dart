import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _initChat();
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isLoading && mounted && _currentConversation != null) {
        _pollMessages();
      }
    });
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status atualizado: $statusStr')));
              }
            }
          });
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

    _messageController.clear();
    _focusNode.requestFocus();
    
    // Determine recipient public key if direct chat
    String? recipientPublicKey;
    if (!_currentConversation!.isGroup && widget.contact != null) {
      recipientPublicKey = widget.contact!.publicKey;
    }

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final sentMsg = await chatRepo.sendMessage(_currentConversation!.id, text, recipientPublicKey);
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
                  const Text('Online', style: TextStyle(color: Color(0xFF00E676), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call, color: Colors.white), onPressed: () {}),
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
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
            Text(
              msg.content,
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
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: const Color(0xFF0A0A0A),
      child: Row(
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
                    child: TextField(
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
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.grey),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
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
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black87),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
