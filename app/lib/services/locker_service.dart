import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/armario.dart';

class Perfil {
  final String role; // 'admin' ou 'aluno'
  final String nome;
  final String? armario;
  Perfil(this.role, this.nome, this.armario);
}

/// Endereço da API. Emulador Android = 10.0.2.2; PC (Windows) = localhost.
/// Para outro endereço: --dart-define=API_URL=http://IP_DO_PC:5000
const _apiEnv = String.fromEnvironment('API_URL');
String get apiUrl => _apiEnv.isNotEmpty
    ? _apiEnv
    : (defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:5000' : 'http://localhost:5000');

class LockerService {
  static final LockerService _i = LockerService._();
  factory LockerService() => _i;
  LockerService._();

  final _store = const FlutterSecureStorage();
  final sessao = ValueNotifier<Perfil?>(null);
  String? _token;

  Map<String, String> get _h =>
      {'Content-Type': 'application/json', if (_token != null) 'Authorization': 'Bearer $_token'};

  Perfil _perfil(Map m) =>
      Perfil(m['perfil'], m['nome'], (m['armario'] as String).isEmpty ? null : m['armario']);

  Future<void> restaurar() async {
    _token = await _store.read(key: 'token');
    final p = await _store.read(key: 'perfil');
    if (_token != null && p != null) sessao.value = _perfil(jsonDecode(p));
  }

  Future<void> login(String prontuario, String senha) async {
    final r = await http.post(Uri.parse('$apiUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prontuario': prontuario.trim(), 'senha': senha}))
        .timeout(const Duration(seconds: 40));
    if (r.statusCode == 401) throw Exception('credenciais');
    if (r.statusCode != 200) throw Exception('A API respondeu com erro ${r.statusCode}.');
    final m = jsonDecode(r.body);
    _token = m['token'];
    await _store.write(key: 'token', value: _token);
    await _store.write(key: 'perfil', value: r.body);
    sessao.value = _perfil(m);
  }

  Future<void> logout() async {
    _token = null;
    await _store.deleteAll();
    sessao.value = null;
  }

  Future<dynamic> _get(String path) async {
    final r = await http.get(Uri.parse('$apiUrl$path'), headers: _h);
    if (r.statusCode == 401) { await logout(); throw Exception('sessão expirada'); }
    if (r.statusCode != 200) throw Exception('Erro ${r.statusCode}');
    return jsonDecode(r.body);
  }

  /// POST/DELETE. Em caso de erro, lança a mensagem enviada pela API.
  Future<void> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$apiUrl$path'))..headers.addAll(_h);
    if (body != null) req.body = jsonEncode(body);
    final r = await http.Response.fromStream(await req.send());
    if (r.statusCode >= 300) {
      final msg = r.body.replaceAll('"', '');
      throw Exception(msg.isNotEmpty && r.statusCode < 500 ? msg : 'Erro ${r.statusCode}');
    }
  }

  /// "Tempo real" por polling (a cada 5 s).
  Stream<T> _poll<T>(Future<T> Function() f) async* {
    while (true) {
      yield await f();
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Stream<List<Armario>> todos() => _poll(() async =>
      ((await _get('/armarios')) as List).map((e) => Armario.fromMap(e)).toList());
  Stream<Armario?> um(String id) => _poll(() async => Armario.fromMap(await _get('/armarios/$id')));

  Future<void> abrir(String id, {bool nfc = false}) =>
      _send('POST', '/armarios/$id/abrir${nfc ? '?via=nfc' : ''}');
  Future<void> resetarAlerta(String id) => _send('POST', '/armarios/$id/resetar-alerta');
  Future<void> criarArmario(String codigo) => _send('POST', '/armarios', {'codigo': codigo.trim()});
  Future<void> excluirArmario(String codigo) => _send('DELETE', '/armarios/$codigo');

  Future<List<Map>> usuarios() async => ((await _get('/usuarios')) as List).cast<Map>();
  Future<void> criarUsuario(String prontuario, String nome, String curso, String armario, String senha) =>
      _send('POST', '/usuarios', {
        'prontuario': prontuario.trim(), 'nome': nome.trim(), 'curso': curso.trim(),
        'armario': armario.trim().isEmpty ? null : armario.trim(), 'senha': senha,
      });

  Future<List<Map>> acessos() async => ((await _get('/acessos')) as List).cast<Map>();
}
