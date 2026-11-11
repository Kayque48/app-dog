import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Endereço da API. No emulador Android, "10.0.2.2" aponta para o computador.
/// Para outro endereço: flutter run --dart-define=API_URL=http://192.168.0.10:3000
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

class ApiException implements Exception {
  ApiException(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}

/// Cliente HTTP da API do All Love. Guarda o token de login no aparelho.
class Api {
  Api._();
  static final Api instance = Api._();

  String? _token;
  bool get loggedIn => _token != null;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<void> _saveToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('token');
    } else {
      await prefs.setString('token', token);
    }
  }

  /// Converte "/uploads/x.jpg" em URL completa. As fotos de exemplo (Unsplash) já vêm completas.
  static String? imageUrl(String? path) {
    if (path == null) return null;
    return path.startsWith('http') ? path : '$apiUrl$path';
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final uri = Uri.parse('$apiUrl/api$path');
    final request = http.Request(method, uri)..headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);
    late http.Response res;
    try {
      res = await http.Response.fromStream(await request.send());
    } catch (_) {
      throw ApiException('Não foi possível conectar ao servidor', 0);
    }
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      // Sessão expirada ou conta bloqueada: apaga o token.
      if (res.statusCode == 401) _saveToken(null);
      throw ApiException(
        data is Map && data['error'] != null ? data['error'] : 'Erro ${res.statusCode}',
        res.statusCode,
      );
    }
    return data;
  }

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body ?? {});
  Future<dynamic> put(String path, Object body) => _send('PUT', path, body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Envia uma imagem e devolve o caminho dela no servidor.
  Future<String> upload(String filePath) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiUrl/api/uploads'))
      ..headers['Authorization'] = 'Bearer $_token'
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    final res = await http.Response.fromStream(await req.send());
    return _decode(res)['url'];
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await post('/auth/login', {'email': email, 'password': password});
    await _saveToken(data['token']);
    return data['user'];
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    final data = await post('/auth/register', body);
    await _saveToken(data['token']);
    return data['user'];
  }

  Future<void> logout() async {
    try {
      await post('/auth/logout');
    } catch (_) {}
    await _saveToken(null);
  }

  void forgetToken() => _saveToken(null);
}

/// Busca o endereço pelo CEP (ViaCEP). Devolve null se não encontrar.
Future<Map<String, dynamic>?> lookupCep(String cep) async {
  final digits = cep.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 8) return null;
  try {
    final res = await http.get(Uri.parse('https://viacep.com.br/ws/$digits/json/'));
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic> && data['erro'] == null) return data;
  } catch (_) {}
  return null;
}
