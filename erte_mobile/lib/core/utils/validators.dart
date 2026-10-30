abstract final class AppValidators {
  static String? required(String? value, {String label = 'Kolom'}) =>
      value?.trim().isNotEmpty == true ? null : '$label wajib diisi.';

  static String? minLength(
    String? value, {
    required int length,
    required String label,
  }) => (value?.trim().length ?? 0) >= length
      ? null
      : '$label minimal $length karakter.';

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email wajib diisi.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Format email tidak valid.';
    }
    return null;
  }

  static String? emailOrPhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email atau nomor HP wajib diisi.';
    if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return null;
    final phone = text.replaceAll(RegExp(r'[\s-]'), '');
    if (RegExp(r'^(08\d{8,11}|\+628\d{8,11})$').hasMatch(phone)) {
      return null;
    }
    return 'Masukkan email atau nomor HP yang valid.';
  }
}
