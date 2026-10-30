/// Penyimpan sesi login sementara (hanya di memori).
/// Hilang saat app ditutup. Nanti bisa diganti flutter_secure_storage
/// agar login bertahan setelah app ditutup.
class AuthSession {
  static String? token;
  static Map<String, dynamic>? user;

  static bool get isLoggedIn => token != null;

  /// Header untuk endpoint yang butuh login: Authorization: Bearer <token>.
  static Map<String, String> get authHeaders => {
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static void clear() {
    token = null;
    user = null;
  }
}
