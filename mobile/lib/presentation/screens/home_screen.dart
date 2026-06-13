import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../domain/entities/conversation.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _connectSocket();
  }

  Future<void> _loadData() async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final convs = await chatRepo.getConversations();
      if (mounted) {
        setState(() {
          _conversations = convs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _connectSocket() {
    final socketDs = ref.read(webSocketDatasourceProvider);
    socketDs.connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('MetaWhats', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              ref.read(webSocketDatasourceProvider).disconnect();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
        : _conversations.isEmpty
            ? const Center(
                child: Text('Nenhuma conversa ainda', style: TextStyle(color: Colors.grey)),
              )
            : ListView.builder(
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conv = _conversations[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF00E676),
                      child: Icon(Icons.person, color: Colors.black),
                    ),
                    title: Text(conv.id, style: const TextStyle(color: Colors.white)),
                    subtitle: const Text('Última mensagem', style: TextStyle(color: Colors.grey)),
                    onTap: () {
                      // Navigate to chat (To be implemented)
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF00E676),
        child: const Icon(Icons.chat, color: Colors.black),
      ),
    );
  }
}
