import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../models/armario.dart';
import '../services/locker_service.dart';

class AlunoScreen extends StatefulWidget {
  final Perfil perfil;
  const AlunoScreen({super.key, required this.perfil});
  @override
  State<AlunoScreen> createState() => _AlunoScreenState();
}

class _AlunoScreenState extends State<AlunoScreen> {
  final svc = LockerService();
  bool? _nfcOk; // null = verificando
  String _msg = 'Aproxime o celular da etiqueta NFC do seu armário.';
  Color _cor = Colors.grey;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _iniciarNfc();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession().catchError((_) {});
    super.dispose();
  }

  Future<void> _iniciarNfc() async {
    bool ok = false;
    try { ok = await NfcManager.instance.isAvailable(); } catch (_) {}
    if (!mounted) return;
    setState(() => _nfcOk = ok);
    if (!ok) return;
    NfcManager.instance.startSession(onDiscovered: (tag) async {
      await _tratar(_lerCodigo(tag));
    });
  }

  /// Lê o texto gravado na etiqueta (registro NDEF do tipo Texto).
  String? _lerCodigo(NfcTag tag) {
    final recs = Ndef.from(tag)?.cachedMessage?.records;
    if (recs == null || recs.isEmpty) return null;
    final p = recs.first.payload;
    if (p.isEmpty) return null;
    final langLen = p[0] & 0x3F;
    if (p.length <= 1 + langLen) return null;
    return utf8.decode(p.sublist(1 + langLen)).trim();
  }

  Future<void> _tratar(String? codigo) async {
    if (_ocupado || !mounted) return;
    final meu = widget.perfil.armario;
    void res(String m, Color c) { if (mounted) setState(() { _msg = m; _cor = c; }); }
    if (codigo == null) return res('Etiqueta sem dados. Não é de um armário.', Colors.orange);
    if (codigo != meu) {
      HapticFeedback.heavyImpact();
      return res('Esta etiqueta é de outro armário ($codigo). Acesso negado.', Colors.red);
    }
    _ocupado = true;
    try {
      await svc.abrir(codigo, nfc: true);
      HapticFeedback.mediumImpact();
      res('Armário aberto com sucesso!', Colors.green);
    } catch (e) {
      res('Não foi possível abrir: ${e.toString().replaceFirst("Exception: ", "")}', Colors.red);
    } finally {
      _ocupado = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final meu = widget.perfil.armario;
    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${widget.perfil.nome.split(" ").first}'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: svc.logout)],
      ),
      body: meu == null
          ? const Center(child: Text('Você ainda não possui um armário.'))
          : StreamBuilder<Armario?>(
              stream: svc.um(meu),
              builder: (_, s) {
                final a = s.data;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    const SizedBox(height: 12),
                    Icon(a?.portaAberta == true ? Icons.lock_open : Icons.lock, size: 88, color: a?.cor ?? Colors.grey),
                    const SizedBox(height: 8),
                    Text(meu, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    if (a != null) ...[
                      Text(a.rotulo, style: TextStyle(color: a.cor, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Bateria: ${a.bateria}%'),
                    ],
                    const SizedBox(height: 28),
                    Card(
                      color: _cor.withOpacity(0.10),
                      shape: RoundedRectangleBorder(
                          side: BorderSide(color: _cor, width: 2), borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          Icon(Icons.nfc, size: 64, color: _cor),
                          const SizedBox(height: 12),
                          Text(_nfcOk == null ? 'Verificando NFC...' : _nfcOk! ? _msg : 'Este aparelho não tem NFC (ou está desligado).',
                              textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                          if (_nfcOk == false) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.touch_app),
                              label: const Text('Simular aproximação (demonstração)'),
                              onPressed: () => _tratar(meu),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
