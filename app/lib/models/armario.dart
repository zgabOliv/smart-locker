import 'package:flutter/material.dart';

enum StatusArmario { normal, atencao, aberto, alerta }

class Armario {
  final String id;
  final String? dono;
  final int bateria;
  final DateTime? ultimoAcesso;
  final String statusPorta;
  final bool alerta;

  Armario({required this.id, this.dono, required this.bateria, this.ultimoAcesso,
      required this.statusPorta, required this.alerta});

  factory Armario.fromMap(Map m) => Armario(
        id: m['id'].toString(),
        dono: m['dono']?.toString(),
        bateria: (m['bateria'] ?? 0) as int,
        ultimoAcesso: DateTime.tryParse(m['ultimoAcesso']?.toString() ?? ''),
        statusPorta: (m['statusPorta'] ?? 'fechada').toString(),
        alerta: m['alerta'] == true,
      );

  // Mesmas regras do app desktop
  int get diasInativo =>
      ultimoAcesso == null ? 0 : DateTime.now().toUtc().difference(ultimoAcesso!.toUtc()).inDays;
  bool get inativo => diasInativo > 5;
  bool get portaAberta => statusPorta == 'aberta' || statusPorta == 'abrir_agora';
  bool get bateriaBaixa => bateria < 20;

  StatusArmario get status {
    if (alerta) return StatusArmario.alerta;
    if (portaAberta) return StatusArmario.aberto;
    if (inativo || bateriaBaixa) return StatusArmario.atencao;
    return StatusArmario.normal;
  }

  Color get cor => switch (status) {
        StatusArmario.alerta => Colors.red,
        StatusArmario.aberto => Colors.blue,
        StatusArmario.atencao => Colors.amber,
        StatusArmario.normal => Colors.green,
      };

  String get rotulo => switch (status) {
        StatusArmario.alerta => 'Alerta de arrombamento',
        StatusArmario.aberto => 'Porta aberta',
        StatusArmario.atencao => bateriaBaixa ? 'Bateria baixa' : 'Inativo há $diasInativo dias',
        StatusArmario.normal => 'Normal',
      };
}
