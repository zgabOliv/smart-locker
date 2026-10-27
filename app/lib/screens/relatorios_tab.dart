import 'package:flutter/material.dart';
import '../services/locker_service.dart';
import 'admin_screen.dart';

class RelatoriosTab extends StatefulWidget {
  const RelatoriosTab({super.key});
  @override
  State<RelatoriosTab> createState() => _RelatoriosTabState();
}

class _RelatoriosTabState extends State<RelatoriosTab> {
  final svc = LockerService();
  late Future<List<Map>> _f = svc.acessos();
  String _filtro = '';

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Filtrar por armário, prontuário ou ação',
                border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => setState(() => _filtro = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => setState(() => _f = svc.acessos()),
            child: FutureBuilder<List<Map>>(
              future: _f,
              builder: (_, s) {
                if (s.hasError) return Center(child: Text('Erro: ${s.error}'));
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                final l = s.data!
                    .where((e) => '${e['armario']} ${e['prontuario']} ${e['acao']}'.toLowerCase().contains(_filtro))
                    .toList();
                if (l.isEmpty) {
                  return ListView(children: const [SizedBox(height: 120), Center(child: Text('Nenhum registro.'))]);
                }
                return ListView.separated(
                  itemCount: l.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = l[i];
                    return ListTile(
                      dense: true,
                      title: Text('${e['acao']}  •  ${e['armario'] ?? "-"}'),
                      subtitle: Text('${dataHora(e['dataHora'])}  |  Prontuário: ${e['prontuario'] ?? "-"}  |  Operador: ${e['operador'] ?? "-"}'),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ]);
}
