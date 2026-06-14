import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../domain/entities/user.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  List<User> _contacts = [];
  Set<String> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final repo = ref.read(contactRepositoryProvider);
      final contacts = await repo.getContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _createGroup() async {
    final title = _groupNameController.text.trim();
    if (title.isEmpty || _selectedUserIds.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final group = await chatRepo.createGroupConversation(title, _selectedUserIds.toList());
      
      if (mounted) {
        // Here we should also generate a Group Key and send it to all participants.
        // For MVP, we will do a simpler approach: the group is created.
        // E2EE for groups is part of phase 3 or next iterations if this is enough for now.
        context.pushReplacement('/chat', extra: {'conversation': group});
      }
      
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Novo Grupo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF141414),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            IconButton(
              icon: _isCreating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF00E676), strokeWidth: 2)) : const Icon(Icons.check, color: Color(0xFF00E676)),
              onPressed: _isCreating ? null : _createGroup,
            )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _groupNameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nome do Grupo',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676), width: 2)),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Participantes', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                : ListView.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final isSelected = _selectedUserIds.contains(contact.id);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? const Color(0xFF00E676) : const Color(0xFF1E1E1E),
                          child: Icon(Icons.person, color: isSelected ? Colors.black : Colors.white),
                        ),
                        title: Text(contact.name ?? contact.phone, style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedUserIds.remove(contact.id);
                            } else {
                              _selectedUserIds.add(contact.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}
