import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/providers.dart';
import '../../domain/entities/user.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  List<User> _contacts = [];
  bool _isLoading = true;

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

  void _showAddContactModal() {
    final phoneController = TextEditingController();
    final nicknameController = TextEditingController();
    bool isAdding = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (statefulCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(statefulCtx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Novo Contato',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Digite o número e o nome da pessoa que deseja adicionar.',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Número de Telefone (com DDD)',
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: '+55 11 99999-9999',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676), width: 2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nicknameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Nome do Contato',
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: 'João Silva',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676), width: 2)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isAdding
                        ? null
                        : () async {
                            final phone = phoneController.text.trim();
                            final nickname = nicknameController.text.trim();
                            if (phone.isEmpty) return;

                            setModalState(() => isAdding = true);
                            try {
                              final repo = ref.read(contactRepositoryProvider);
                              await repo.addContact(phone, nickname);
                              if (mounted) {
                                Navigator.pop(statefulCtx);
                                _loadContacts();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Contato adicionado com sucesso!')),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isAdding = false);
                              
                              String errorMsg = 'Ocorreu um erro inesperado.';
                              bool isNotFound = false;

                              if (e is DioException && e.response != null) {
                                final data = e.response?.data;
                                if (data is Map) {
                                  errorMsg = data['message']?.toString() ?? e.response?.statusMessage ?? errorMsg;
                                } else {
                                  errorMsg = data?.toString() ?? e.response?.statusMessage ?? errorMsg;
                                }

                                if (e.response?.statusCode == 404 || errorMsg.toLowerCase().contains('not found')) {
                                  isNotFound = true;
                                }
                              } else {
                                errorMsg = e.toString();
                              }

                              if (isNotFound) {
                                // Pops the bottom sheet using its internal context
                                Navigator.pop(statefulCtx);
                                // Show dialog using the outer screen context (this.context) which is never destroyed!
                                showDialog(
                                  context: context, 
                                  builder: (dialogCtx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text('Contato não encontrado', style: TextStyle(color: Colors.white)),
                                    content: Text(
                                      'O número $phone ainda não possui o MetaWhats. Deseja enviar um convite para ele?',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogCtx),
                                        child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(dialogCtx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Convite simulado enviado com sucesso!')),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                                        child: const Text('Convidar', style: TextStyle(color: Colors.black)),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // Pop the bottom sheet so the user can actually see the SnackBar!
                                Navigator.pop(statefulCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro do Servidor: $errorMsg')),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: isAdding
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('Adicionar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showEditContactModal(User contact) {
    final nicknameController = TextEditingController(text: contact.name);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (statefulCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(statefulCtx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Editar Contato',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    contact.phone,
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nicknameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Nome do Contato',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676), width: 2)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final nickname = nicknameController.text.trim();
                            setModalState(() => isSaving = true);
                            try {
                              final repo = ref.read(contactRepositoryProvider);
                              await repo.addContact(contact.phone, nickname);
                              if (mounted) {
                                Navigator.pop(statefulCtx);
                                _loadContacts();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Contato atualizado com sucesso!')),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro: $e')),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('Salvar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Contatos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _contacts.isEmpty
              ? const Center(
                  child: Text('Nenhum contato encontrado', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        tileColor: const Color(0xFF141414),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00E676).withOpacity(0.8),
                                const Color(0xFF00E676).withOpacity(0.4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 28),
                        ),
                        title: Text(contact.name ?? contact.phone, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(contact.name != null ? contact.phone : 'Disponível', style: const TextStyle(color: Colors.grey)),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white54),
                          onPressed: () => _showEditContactModal(contact),
                        ),
                        onTap: () {
                          context.push('/chat', extra: {'contact': contact});
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactModal,
        backgroundColor: const Color(0xFF00E676),
        child: const Icon(Icons.person_add, color: Colors.black),
      ),
    );
  }
}
