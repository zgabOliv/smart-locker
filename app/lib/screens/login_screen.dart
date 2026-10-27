import 'package:flutter/material.dart';
import '../services/locker_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _prontuario = TextEditingController();
  final _senha = TextEditingController();
  bool _ver = false, _carregando = false;
  String? _erro;

  Future<void> _entrar() async {
    setState(() { _carregando = true; _erro = null; });
    try {
      await LockerService().login(_prontuario.text, _senha.text);
    } catch (e) {
      setState(() => _erro = e.toString().contains('credenciais')
          ? 'Prontuário ou senha incorretos.'
          : 'Não consegui falar com a API ($apiUrl). Ela está rodando? O celular está na mesma rede?');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(children: [
                const Icon(Icons.lock, size: 64, color: Color(0xFF006400)),
                const SizedBox(height: 8),
                const Text('Smart Locker IFSP',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _prontuario,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(labelText: 'Prontuário', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _senha,
                  obscureText: !_ver,
                  onSubmitted: (_) => _entrar(),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _ver = !_ver),
                    ),
                  ),
                ),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_erro!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _carregando ? null : _entrar,
                    child: _carregando
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Entrar'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
