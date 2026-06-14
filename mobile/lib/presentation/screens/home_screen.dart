import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/user.dart';
import 'package:dio/dio.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  User? _currentUser;
  List<Conversation> _conversations = [];
  List<User> _contacts = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _connectSocket();
    
    // Fallback à prova de falhas: Polling a cada 10 segundos
    // Garante que mesmo se o WebSocket do Cloudflare cair ou o navegador suspender,
    // os Ticks e as mensagens vão funcionar!
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isLoading && mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final chatRepo = ref.read(chatRepositoryProvider);
      final contactRepo = ref.read(contactRepositoryProvider);
      
      final me = await authRepo.getCurrentUser();
      final convs = await chatRepo.getConversations();
      final contactsList = await contactRepo.getContacts();
      
      if (mounted) {
        setState(() {
          _currentUser = me;
          _conversations = convs;
          _contacts = contactsList;
          _isLoading = false;
        });
      }

      // NOVO: Garantir que o polling também marque como entregue!
      for (var conv in convs) {
        if (conv.lastMessage != null) {
          final msg = conv.lastMessage!;
          // Se a mensagem não é minha e o status está apenas como "sent", avisa que entregou!
          if (msg.senderId != me?.id && msg.status == MessageStatus.sent) {
            chatRepo.markAsDelivered(msg.id);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (e is DioException && e.response?.statusCode == 401) {
          final authRepo = ref.read(authRepositoryProvider);
          authRepo.logout().then((_) {
            context.go('/login');
          });
        }
      }
    }
  }

  StreamSubscription<Message>? _messageSub;

  void _connectSocket() {
    final socketDs = ref.read(webSocketDatasourceProvider);
    socketDs.connect();
    
    final chatRepo = ref.read(chatRepositoryProvider);
    _messageSub = chatRepo.onMessageReceived.listen((message) {
      // Reload conversations when a new message arrives
      _loadData();
      
      // Mark as delivered if we received it
      if (message.senderId != _currentUser?.id) {
        chatRepo.markAsDelivered(message.id);
      }
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Deep premium black
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 140.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              title: const Text(
                'Mensagens',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF00E676).withOpacity(0.15),
                      const Color(0xFF0A0A0A),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white70),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
                onPressed: () {},
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) async {
                  if (value == 'logout') {
                    await ref.read(authRepositoryProvider).logout();
                    ref.read(webSocketDatasourceProvider).disconnect();
                    if (mounted) context.go('/login');
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: Text('Meu Perfil', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Text('Configurações', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Sair', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF00E676), strokeWidth: 2),
              ),
            )
          else if (_conversations.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1A1A),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E676).withOpacity(0.1),
                            blurRadius: 40,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                      child: const Icon(Icons.chat_bubble_outline, size: 50, color: Color(0xFF00E676)),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Nenhuma conversa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Toque no botão abaixo para\niniciar um bate-papo seguro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final conv = _conversations[index];
                  
                  String title = 'Contato';
                  if (conv.isGroup) {
                    title = conv.groupName ?? 'Grupo';
                  } else {
                    try {
                      final otherUser = conv.participants.firstWhere((p) => p.id != _currentUser?.id);
                      // Check if it's in contacts
                      final contact = _contacts.where((c) => c.phone == otherUser.phone).firstOrNull;
                      if (contact != null && contact.name != null && contact.name!.isNotEmpty) {
                        title = contact.name!;
                      } else {
                        title = otherUser.name ?? otherUser.phone;
                      }
                    } catch (e) {
                      title = 'Desconhecido';
                    }
                  }

                  String subtitle = 'Toque para abrir a conversa';
                  if (conv.lastMessage != null) {
                    subtitle = conv.lastMessage!.content;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: InkWell(
                      onTap: () {
                        context.push('/chat', extra: {
                          'conversation': conv,
                          'currentUser': _currentUser,
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.02)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00E676),
                                    const Color(0xFF00E676).withOpacity(0.6),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.person, color: Colors.black87, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        _formatTime(conv.updatedAt),
                                        style: const TextStyle(color: Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _conversations.length,
              ),
            ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E676).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            context.push('/contacts');
          },
          backgroundColor: const Color(0xFF00E676),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.chat_bubble, color: Colors.black, size: 26),
        ),
      ),
    );
  }
}
