class ApiConfig {
  /// Alamat dasar API (sampai "/api", TANPA garis miring di akhir).
  /// Link trycloudflare.com bersifat sementara: kalau berubah, ganti di sini
  /// atau jalankan dengan:
  ///   flutter run --dart-define=API_BASE_URL=https://alamat-baru.trycloudflare.com/api
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://intervention-causing-departments-table.trycloudflare.com/api',
  );
}
