import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  static const _timeout = Duration(seconds: 20);

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Ambil pesan error paling berguna dari balasan server
  /// (bentuk balasan: {"status":"error","message":"...","errors":{...}}).
  static String _errorMessage(Map<String, dynamic> body, int code) {
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      if (first != null) return first.toString();
    }
    final msg = body['message']?.toString() ?? '';
    if (msg.isNotEmpty) return msg;
    if (code == 401) return 'Email atau password salah.';
    if (code == 429) return 'Terlalu banyak percobaan. Coba lagi nanti.';
    return 'Terjadi kesalahan ($code).';
  }

  /// Sukses (2xx) → Map balasan. Gagal → ApiException berisi pesan server.
  static Map<String, dynamic> _parse(http.Response res) {
    var body = <String, dynamic>{};
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      // Balasan bukan JSON (mis. halaman error tunnel): pakai pesan umum.
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(_errorMessage(body, res.statusCode),
        statusCode: res.statusCode);
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data, {
    Map<String, String> extraHeaders = const {},
  }) async {
    final res = await http
        .post(
          _uri(path),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            ...extraHeaders,
          },
          body: jsonEncode(data),
        )
        .timeout(_timeout);
    return _parse(res);
  }

  /* ── Login (endpoint terverifikasi: POST /api/auth/login) ──
     Balasan sukses: { status, message, data: { user: {...}, token } } */
  static Future<Map<String, dynamic>> login(String email, String password) =>
      _post('/auth/login', {'email': email, 'password': password});

  // Endpoint register dan lupa password belum ada di sini: path dan nama
  // field-nya belum terverifikasi dari backend.
}
