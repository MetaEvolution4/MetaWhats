import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const VerifyOtpScreen({super.key, required this.phone});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    if (_codeController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite os 6 dígitos')));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.verifyOtp(widget.phone, _codeController.text);
      
      // Gera e salva as chaves E2EE no dispositivo
      final encryption = ref.read(encryptionServiceProvider);
      await encryption.initKeypair();
      
      if (mounted) context.go('/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Verificar código', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Enviamos um SMS para ${widget.phone}\nInsira o código de 6 dígitos',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: Colors.white, fontSize: 32, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676), width: 2)),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Verificar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
