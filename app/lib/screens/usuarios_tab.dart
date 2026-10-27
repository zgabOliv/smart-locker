import 'package:flutter/material.dart';
import '../services/locker_service.dart';
import 'admin_screen.dart';

class UsuariosTab extends StatefulWidget {
  const UsuariosTab({super.key});
  @override
  State<UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<UsuariosTab> {
  final svc = LockerService();
  late Future<List<Map>> _f = svc.usuarios();
  void _recarregar() => setState(() => _f = svc.usuarios());

  Future<void> _novo() async {
    final pr = TextEditingController(), nome = TextEditingController(), curso = TextEditingController();
    final arm = TextEditingController(), senha = TextEditingController();
    InputDecoration d(String l) => InputDecoration(labelText: l);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Novo usuário'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: pr, decoration: d('Prontuário')),
            TextField(controller: nome, decoration: d('Nome')),
            TextField(controller: curso, decoration: d('Curso')),
            TextField(controller: arm, decoration: d('Código do armário (ex: armario_01)')),
            TextField(controller: senha, obscureText: true, decoration: d('Senha de acesso ao app')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await svc.criarUsuario(pr.text, nome.text, curso.text, arm.text, senha.text);
      if (mounted) aviso(context, 'Usuário cadastrado.');
      _recarregar();
    } catch (e) {
      if (mounted) aviso(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _novo, icon: const Icon(Icons.person_add), label: const Text('Usuário')),
        body: RefreshIndicator(
          onRefresh: () async => _recarregar(),
          child: FutureBuilder<List<Map>>(
            future: _f,
            builder: (_, s) {
              if (s.hasError) return Center(child: Text('Erro: ${s.error}'));
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final l = s.data!;
              if (l.isEmpty) return ListView(children: const [SizedBox(height: 120), Center(child: Text('Nenhum usuário.'))]);
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: l.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final u = l[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text('${u['nome']}'),
                    subtitle: Text('${u['prontuario']} • ${u['curso'] ?? ""}\nArmário: ${u['armario'] ?? "-"}'),
                    isThreeLine: true,
                    trailing: Text('${u['status'] ?? ""}'),
                  );
                },
              );
            },
          ),
        ),
      );
}
