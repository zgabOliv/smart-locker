import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/armario.dart';
import '../services/locker_service.dart';
import 'relatorios_tab.dart';
import 'usuarios_tab.dart';

String dataHora(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '-';
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)} ${p(d.hour)}:${p(d.minute)}';
}

Future<bool> confirmar(BuildContext c, String msg) async =>
    await showDialog<bool>(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmar')),
        ],
      ),
    ) ??
    false;

void aviso(BuildContext c, String msg) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg.replaceFirst('Exception: ', ''))));

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _aba = 0;
  @override
  Widget build(BuildContext context) {
    const titulos = ['Armários', 'Usuários', 'Relatórios de acesso'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titulos[_aba]),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: LockerService().logout)],
      ),
      body: IndexedStack(index: _aba, children: const [ArmariosTab(), UsuariosTab(), RelatoriosTab()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.lock), label: 'Armários'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Usuários'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Relatórios'),
        ],
      ),
    );
  }
}

class ArmariosTab extends StatefulWidget {
  const ArmariosTab({super.key});
  @override
  State<ArmariosTab> createState() => _ArmariosTabState();
}

class _ArmariosTabState extends State<ArmariosTab> {
  final svc = LockerService();
  late final Stream<List<Armario>> _s = svc.todos().asBroadcastStream();
  StreamSubscription? _sub;
  final _alertados = <String>{};
  final _abertos = <String>{};
  bool _primeira = true;

  @override
  void initState() {
    super.initState();
    // Notificação dentro do app: avisa quando um armário NOVO entra em alerta ou bateria baixa
    _sub = _s.listen((lista) {
      final agora = lista.where((a) => a.alerta || a.bateriaBaixa).map((a) => '${a.id}|${a.alerta}').toSet();
      final novos = agora.difference(_alertados);
      _alertados..clear()..addAll(agora);
      final abertos = lista.where((a) => a.portaAberta).map((a) => a.id).toSet();
      final novosAbertos = abertos.difference(_abertos);
      _abertos..clear()..addAll(abertos);
      if (_primeira) { _primeira = false; return; }
      if (novos.isNotEmpty && mounted) {
        HapticFeedback.heavyImpact();
        final a = lista.firstWhere((x) => novos.first.startsWith('${x.id}|'));
        aviso(context, '⚠ ${a.id}: ${a.rotulo}');
      }
      if (novosAbertos.isNotEmpty && mounted) {
        final a = lista.firstWhere((x) => x.id == novosAbertos.first);
        aviso(context, '🔓 ${a.id} foi aberto${a.dono != null ? " (dono: ${a.dono})" : ""}');
      }
    }, onError: (_) {});
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  Future<void> _novo() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Novo armário'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Código (ex: armario_05)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true) return;
    try { await svc.criarArmario(ctrl.text); if (mounted) aviso(context, 'Armário cadastrado.'); }
    catch (e) { if (mounted) aviso(context, '$e'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _novo, icon: const Icon(Icons.add), label: const Text('Armário')),
        body: StreamBuilder<List<Armario>>(
          stream: _s,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('Erro: ${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final lista = s.data!;
            if (lista.isEmpty) return const Center(child: Text('Nenhum armário cadastrado.'));
            int c(StatusArmario st) => lista.where((a) => a.status == st).length;
            final alertas = lista.where((a) => a.alerta || a.bateriaBaixa).toList();
            return Column(children: [
              if (alertas.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: Colors.red.shade50,
                  padding: const EdgeInsets.all(10),
                  child: Text('⚠ ${alertas.map((a) => '${a.id} (${a.alerta ? "arrombamento" : "bateria baixa"})').join(', ')}',
                      style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600)),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(spacing: 8, children: [
                  _chip(Colors.green, 'Normal ${c(StatusArmario.normal)}'),
                  _chip(Colors.amber, 'Atenção ${c(StatusArmario.atencao)}'),
                  _chip(Colors.blue, 'Aberto ${c(StatusArmario.aberto)}'),
                  _chip(Colors.red, 'Alerta ${c(StatusArmario.alerta)}'),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final a = lista[i];
                    return Card(
                      shape: RoundedRectangleBorder(
                          side: BorderSide(color: a.cor, width: 2), borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.lock, color: a.cor),
                            const SizedBox(width: 8),
                            Text(a.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Spacer(),
                            Text(a.rotulo, style: TextStyle(color: a.cor, fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 6),
                          Text('Dono: ${a.dono ?? "-"}  •  Bateria: ${a.bateria}%'),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.lock_open),
                              label: const Text('Abrir'),
                              onPressed: () async {
                                if (await confirmar(context, 'Abrir ${a.id} em emergência?')) {
                                  try { await svc.abrir(a.id); } catch (e) { if (mounted) aviso(context, '$e'); }
                                }
                              },
                            ),
                            if (a.alerta)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.notifications_off),
                                label: const Text('Resetar alerta'),
                                onPressed: () => svc.resetarAlerta(a.id),
                              ),
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Excluir'),
                              onPressed: () async {
                                if (await confirmar(context, 'Excluir ${a.id}?')) {
                                  try { await svc.excluirArmario(a.id); } catch (e) { if (mounted) aviso(context, '$e'); }
                                }
                              },
                            ),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ]);
          },
        ),
      );

  Widget _chip(Color c, String t) => Chip(
      avatar: CircleAvatar(backgroundColor: c, radius: 6), label: Text(t), visualDensity: VisualDensity.compact);
}
