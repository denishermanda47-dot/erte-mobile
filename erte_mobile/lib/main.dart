// ERTE - Aplikasi Komunitas RT/RW
// UI Login, Register (3 tahap + upload dokumen kamera), dan Lupa Password.
// Butuh Flutter 3.22+ (WidgetState). Tahap 3 memakai paket `camera` dan
// `permission_handler`: lihat PLATFORM_SETUP.md di folder induk.

import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'auth_session.dart';
import 'forgot_password.dart';
import 'models/document_type.dart';
import 'widgets/document_capture.dart';
import 'core/theme/app_theme.dart' show AppTheme;
import 'features/admin/admin_home_screen.dart' show AdminHomeScreen;
import 'features/splash/splash_screen.dart' show SplashScreen;
import 'features/user/home_screen.dart' show HomeScreen;
import 'providers/auth_provider.dart' show authControllerProvider;
import 'providers/theme_provider.dart'
    show sharedPreferencesProvider, themeModeProvider;
import 'services/hive_service.dart' show HiveService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await HiveService.initialize(); // database lokal dashboard tim
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const ErteApp(),
    ),
  );
}

/* ───────────────────────── Tema & Warna ───────────────────────── */

class AppColors {
  static const primary = Color(0xFF3B82F6);
  static const primaryDark = Color(0xFF2563EB); // hover / pressed
  static const primaryDisabled = Color(0xFF93C5FD);
  static const lightBg = Color(0xFFEFF6FF);
  static const lightBlue = Color(0xFFDBEAFE);
  static const white = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFCBD5E1);
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
}

/// Tema khusus halaman auth (login, register, lupa password): selalu terang
/// dengan gaya input sendiri, terlepas dari tema dashboard tim.
ThemeData buildAuthTheme() {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    scaffoldBackgroundColor: AppColors.white,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIconColor: AppColors.textSecondary,
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary, 2), // fokus: border biru
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 2),
    ),
  );
}

class ErteApp extends ConsumerWidget {
  const ErteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ERTE',
      debugShowCheckedModeBanner: false,
      // Tema dashboard tim (terang/gelap sesuai pengaturan di Profil).
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      // Splash memeriksa sesi: belum login -> LoginPage, sudah login -> dashboard.
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/forgot-password': (_) => const ForgotPasswordPage(),
        '/register-success': (_) => const RegisterSuccessPage(),
      },
    );
  }
}

/* ───────────────────────── Validasi ───────────────────────── */

class Validators {
  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final _phone = RegExp(r'^(08|\+628)\d{8,11}$'); // 08xx / +628xx

  static String? name(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Nama lengkap wajib diisi';
    if (s.length < 3) return 'Nama minimal 3 karakter';
    return null;
  }

  static String? digits16(String? v, String label) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '$label wajib diisi';
    if (!RegExp(r'^\d{16}$').hasMatch(s)) return '$label harus 16 digit angka';
    return null;
  }

  static String? address(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Alamat lengkap wajib diisi';
    if (s.length < 10)
      return 'Tulis alamat selengkapnya (jalan, RT/RW, kelurahan)';
    return null;
  }

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email wajib diisi';
    if (!_email.hasMatch(s)) return 'Format email tidak valid';
    return null;
  }

  static String? phone(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (s.isEmpty) return 'Nomor HP wajib diisi';
    if (!_phone.hasMatch(s)) return 'Gunakan format 08xx atau +628xx';
    return null;
  }

  static String? emailOrPhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email atau nomor HP wajib diisi';
    final p = s.replaceAll(RegExp(r'[\s-]'), '');
    if (!_email.hasMatch(s) && !_phone.hasMatch(p)) {
      return 'Masukkan email atau nomor HP yang valid';
    }
    return null;
  }

  static String? loginPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password wajib diisi';
    if (v.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  static String? newPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password wajib diisi';
    if (v.length < 8) return 'Password minimal 8 karakter';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Password harus mengandung huruf dan angka';
    }
    return null;
  }
}

/* ───────────────────────── Komponen Reusable ───────────────────────── */

/// Logo "ERTE" dengan aksen biru.
class ErteLogo extends StatelessWidget {
  const ErteLogo({super.key, this.size = 44, this.light = false});
  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x553B82F6),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.holiday_village_rounded,
            color: Colors.white,
            size: size * 0.58,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'ERTE',
          style: TextStyle(
            fontSize: size * 0.7,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.primaryDark,
          ),
        ),
      ],
    );
  }
}

/// Wrapper halaman auth: gradien biru muda, logo, dan card putih.
/// Desktop (>= 900px): panel brand di kiri, form di kanan.
/// Mobile: logo di atas, card full-width dengan padding nyaman.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.header,
    this.aboveCard,
  });
  final String title;
  final String subtitle;
  final Widget child;

  /// Widget opsional di dalam card, di atas judul (mis. tombol Kembali).
  final Widget? header;

  /// Widget opsional di atas card (mis. step indicator).
  final Widget? aboveCard;

  @override
  Widget build(BuildContext context) {
    final card = _AuthCard(
      title: title,
      subtitle: subtitle,
      header: header,
      child: child,
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (aboveCard != null) ...[aboveCard!, const SizedBox(height: 16)],
        card,
      ],
    );

    return Theme(
      data: buildAuthTheme(),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            // linear-gradient(135deg, #FFFFFF → #DBEAFE)
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.white, AppColors.lightBlue],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                if (wide) {
                  return Row(
                    children: [
                      const Expanded(flex: 5, child: _BrandPanel()),
                      Expanded(
                        flex: 6,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(32),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: content,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ErteLogo(),
                          const SizedBox(height: 24),
                          content,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.header,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24), // rounded-2xl
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F3B82F6),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
          BoxShadow(
            color: Color(0x0F1E293B),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            Align(alignment: Alignment.centerLeft, child: header!),
            const SizedBox(height: 8),
          ],
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

/// Panel brand (hanya tampil di layar lebar).
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(56),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ErteLogo(size: 56),
          const SizedBox(height: 32),
          const Text(
            'Satu akun untuk\nseluruh keluarga di lingkungan RT/RW Anda.',
            style: TextStyle(
              fontSize: 30,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kepala Keluarga mendaftar sekali, lalu menambahkan anggota keluarga setelah akun aktif.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          point(
            Icons.verified_user_outlined,
            'Akun diverifikasi langsung oleh Ketua RT',
          ),
          point(Icons.groups_outlined, 'Kelola data anggota keluarga'),
          point(Icons.campaign_outlined, 'Terima pengumuman warga'),
        ],
      ),
    );
  }
}

/// Input reusable: label di atas, ikon, helper, dan pesan error.
class InputField extends StatelessWidget {
  const InputField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.obscureText = false,
    this.suffix,
    this.helperText,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? minLines;
  final int? maxLength; // jika diisi, counter "0/16" tampil otomatis
  final bool obscureText;
  final Widget? suffix;
  final String? helperText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Semantics: label terhubung ke input untuk screen reader.
        Semantics(
          label: label,
          textField: true,
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            minLines: minLines,
            maxLength: maxLength,
            obscureText: obscureText,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            onChanged: onChanged,
            onFieldSubmitted: onFieldSubmitted,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              helperText: helperText,
              helperMaxLines: 3,
              helperStyle: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
              prefixIcon: icon == null ? null : Icon(icon, size: 20),
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    );
  }
}

/// Input password dengan tombol show/hide.
class PasswordInput extends StatefulWidget {
  const PasswordInput({
    super.key,
    required this.label,
    required this.controller,
    required this.validator,
    this.hint,
    this.onChanged,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
  });
  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return InputField(
      label: widget.label,
      controller: widget.controller,
      hint: widget.hint,
      icon: Icons.lock_outline,
      obscureText: _obscure,
      validator: widget.validator,
      onChanged: widget.onChanged,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: widget.autofillHints,
      keyboardType: TextInputType.visiblePassword,
      suffix: IconButton(
        // tooltip = aria-label untuk tombol ikon
        tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}

enum ButtonVariant { primary, secondary }

/// Tombol reusable (primary / secondary) dengan state loading.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final shape = WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    const padding = WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 16));
    const textStyle = WidgetStatePropertyAll(
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );

    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : Text(label);

    if (variant == ButtonVariant.secondary) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: ButtonStyle(
            shape: shape,
            padding: padding,
            textStyle: textStyle,
            foregroundColor: const WidgetStatePropertyAll(
              AppColors.primaryDark,
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: AppColors.primary),
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.hovered)
                  ? AppColors.lightBg
                  : Colors.transparent,
            ),
          ),
          child: Text(label),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ButtonStyle(
          shape: shape,
          padding: padding,
          textStyle: textStyle,
          elevation: const WidgetStatePropertyAll(0),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          // Hover/pressed: biru sedikit lebih gelap (#2563EB)
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) {
              return loading ? AppColors.primary : AppColors.primaryDisabled;
            }
            if (s.contains(WidgetState.hovered) ||
                s.contains(WidgetState.pressed)) {
              return AppColors.primaryDark;
            }
            return AppColors.primary;
          }),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
      ),
    );
  }
}

/// Indikator kekuatan password (4 segmen).
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.password});
  final String password;

  int get _score {
    if (password.isEmpty) return 0;
    var s = 0;
    if (password.length >= 8) s++;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password))
      s++;
    if (RegExp(r'\d').hasMatch(password)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final score = _score;
    const labels = ['Sangat lemah', 'Lemah', 'Cukup', 'Kuat', 'Sangat kuat'];
    final color = score <= 1
        ? AppColors.error
        : score == 2
        ? AppColors.warning
        : AppColors.success;

    return Semantics(
      label: 'Kekuatan password: ${labels[score]}',
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(4, (i) {
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 5,
                    margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: i < score ? color : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text(
              'Kekuatan password: ${labels[score]}',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Judul section di form register.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: AppColors.border, height: 1)),
        ],
      ),
    );
  }
}

/// Step indicator sederhana: Data KK → Data Akun → Selesai.
class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.current,
    this.labels = const ['Data KK', 'Data Akun', 'Dokumen'],
  });

  /// Indeks langkah aktif (0-based). Nilai >= labels.length berarti semua selesai.
  final int current;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      final done = i < current;
      final active = i == current;
      items.add(
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // aktif = biru, selesai = hijau (centang), belum = abu
                color: done
                    ? AppColors.success
                    : active
                    ? AppColors.primary
                    : AppColors.white,
                border: Border.all(
                  color: done
                      ? AppColors.success
                      : active
                      ? AppColors.primary
                      : AppColors.border,
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              labels[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.primaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
      if (i < labels.length - 1) {
        items.add(
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 20, left: 6, right: 6),
              color: i < current ? AppColors.success : AppColors.border,
            ),
          ),
        );
      }
    }
    return Semantics(
      label:
          'Langkah ${(current + 1).clamp(1, labels.length)} dari ${labels.length}: ${labels[current.clamp(0, labels.length - 1)]}',
      child: ExcludeSemantics(child: Row(children: items)),
    );
  }
}

/* ───────────────────────── Halaman Login ───────────────────────── */

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // State management sederhana: controller + setState.
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _remember = false;
  bool _loading = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      // API login: POST /api/auth/login, field "email" dan "password".
      final result = await ApiService.login(
        _idCtrl.text.trim(),
        _passCtrl.text,
      );
      final data = result['data'] as Map<String, dynamic>;
      AuthSession.token = data['token']?.toString();
      AuthSession.user = data['user'] as Map<String, dynamic>?;
      final apiUser = AuthSession.user ?? const <String, dynamic>{};
      final roles = ((apiUser['roles'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();

      // Teruskan ke dashboard tim: simpan pengguna ke state aplikasi.
      final user = await ProviderScope.containerOf(context)
          .read(authControllerProvider.notifier)
          .loginFromApi(
            id: '${apiUser['id']}',
            name: apiUser['name']?.toString() ?? '',
            email: apiUser['email']?.toString() ?? _idCtrl.text.trim(),
            roles: roles,
            rememberMe: _remember,
          );
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
              user.isAdmin ? const AdminHomeScreen() : HomeScreen(user: user),
        ),
        (_) => false,
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e, st) {
      debugPrint('LOGIN ERROR: $e\n$st');
      _showError('Tidak dapat terhubung ke server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Selamat datang kembali',
      subtitle: 'Masuk untuk melihat kabar terbaru dari lingkungan Anda.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputField(
                label: 'Email atau Nomor HP',
                controller: _idCtrl,
                hint: 'nama@email.com atau 08123456789',
                icon: Icons.person_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: Validators.emailOrPhone,
              ),
              const SizedBox(height: 16),
              PasswordInput(
                label: 'Password',
                controller: _passCtrl,
                hint: 'Masukkan password',
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                validator: Validators.loginPassword,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => setState(() => _remember = !_remember),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _remember,
                          activeColor: AppColors.primary,
                          onChanged: (v) =>
                              setState(() => _remember = v ?? false),
                        ),
                        const Text(
                          'Ingat saya',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/forgot-password'),
                    child: const Text('Lupa password?'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppButton(label: 'Masuk', loading: _loading, onPressed: _submit),
              const SizedBox(height: 20),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Belum punya akun? ',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    InkWell(
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/register'),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Daftar di sini',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── Halaman Register (3 tahap) ───────────────────────── */

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Satu form per tahap form; tahap 3 (dokumen) tidak memakai Form.
  final _kkFormKey = GlobalKey<FormState>();
  final _akunFormKey = GlobalKey<FormState>();

  // Semua data disimpan di State induk, jadi tidak hilang saat pengguna
  // bolak-balik antar tahap.
  final _nameCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _kkCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _rtCtrl = TextEditingController();
  final _rwCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  int _step = 0; // 0 = Data KK, 1 = Data Akun, 2 = Dokumen
  bool _agreed = false;
  bool _loading = false;

  // Foto dokumen: HANYA di memori (bytes). Tidak dikirim, tidak disimpan
  // ke galeri/disk, hilang saat halaman ini ditutup.
  Uint8List? _ktpPhoto;
  Uint8List? _kkPhoto;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _nikCtrl,
      _kkCtrl,
      _addressCtrl,
      _rtCtrl,
      _rwCtrl,
      _phoneCtrl,
      _emailCtrl,
      _passCtrl,
      _confirmCtrl,
    ]) {
      c.dispose();
    }
    _ktpPhoto = null;
    _kkPhoto = null;
    super.dispose();
  }

  /* ── Validitas per tahap (menentukan tombol "Lanjut" aktif) ── */

  bool get _kkValid =>
      Validators.name(_nameCtrl.text) == null &&
      Validators.digits16(_nikCtrl.text, 'NIK') == null &&
      Validators.digits16(_kkCtrl.text, 'No. KK') == null &&
      Validators.address(_addressCtrl.text) == null;

  bool get _akunValid =>
      Validators.phone(_phoneCtrl.text) == null &&
      Validators.email(_emailCtrl.text) == null &&
      Validators.newPassword(_passCtrl.text) == null &&
      _confirmCtrl.text == _passCtrl.text &&
      _confirmCtrl.text.isNotEmpty &&
      _agreed;

  bool get _docsReady => _ktpPhoto != null && _kkPhoto != null;

  /* ── Navigasi antar tahap ── */

  void _goToStep(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
  }

  void _handleNext() {
    if (_step == 0) {
      if (!_kkFormKey.currentState!.validate()) return;
      // TODO: integrasi API simpan data KK di sini
      _goToStep(1);
    } else if (_step == 1) {
      if (!_akunFormKey.currentState!.validate()) return;
      // TODO: integrasi API simpan data akun di sini
      _goToStep(2);
    }
  }

  void _handleBack() {
    if (_step == 0) {
      _goToLogin();
    } else {
      _goToStep(_step - 1);
    }
  }

  void _goToLogin() {
    // TODO: navigasi ke login (sesuaikan dengan router aplikasi)
    Navigator.pushReplacementNamed(context, '/login');
  }

  /// "Kirim Pendaftaran" (mock): tidak ada data/foto yang dikirim.
  Future<void> _handleSubmit() async {
    if (!_docsReady) return;
    setState(() => _loading = true);

    // TODO: integrasi API kirim seluruh data registrasi di sini
    await Future.delayed(const Duration(milliseconds: 800)); // simulasi
    if (!mounted) return;
    setState(() => _loading = false);

    // Step 4: halaman sukses (layar terpisah).
    Navigator.pushReplacementNamed(
      context,
      '/register-success',
      arguments: RegistrationSummary(
        name: _nameCtrl.text.trim(),
        kkNumber: _kkCtrl.text.trim(),
      ),
    );
  }

  /* ── Build ── */

  static const _titles = [
    'Data Kepala Keluarga',
    'Data Akun',
    'Upload Dokumen',
  ];
  static const _subtitles = [
    'Isi sesuai KTP dan Kartu Keluarga.',
    'Buat akun untuk masuk ke ERTE.',
    'Foto KTP dan KK Anda untuk verifikasi oleh Ketua RT.',
  ];

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: _titles[_step],
      subtitle: _subtitles[_step],
      // Step indicator di atas card.
      aboveCard: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: StepIndicator(current: _step),
      ),
      // Tombol Kembali di kiri atas card (tahap 1 → login).
      header: TextButton.icon(
        onPressed: _loading ? null : _handleBack,
        icon: const Icon(Icons.arrow_back, size: 18),
        label: Text(_step == 0 ? 'Kembali ke login' : 'Kembali'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 36),
        ),
      ),
      child: switch (_step) {
        0 => _buildKkForm(),
        1 => _buildAkunForm(),
        _ => _buildDocsStep(),
      },
    );
  }

  /* ── Tahap 1: Data Kepala Keluarga ── */
  Widget _buildKkForm() {
    return Form(
      key: _kkFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputField(
            label: 'Nama Lengkap',
            controller: _nameCtrl,
            hint: 'Sesuai KTP',
            icon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            helperText: 'Isi dengan nama Kepala Keluarga sesuai KTP. Anggota keluarga lain dapat ditambahkan setelah akun aktif.',
            validator: Validators.name,
          ),
          const SizedBox(height: 16),
          InputField(
            label: 'NIK',
            controller: _nikCtrl,
            hint: '16 digit angka',
            icon: Icons.credit_card_outlined,
            keyboardType: TextInputType.number,
            maxLength: 16, // menampilkan counter "0/16"
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            validator: (v) => Validators.digits16(v, 'NIK'),
          ),
          const SizedBox(height: 16),
          InputField(
            label: 'Nomor Kartu Keluarga',
            controller: _kkCtrl,
            hint: '16 digit angka',
            icon: Icons.groups_outlined,
            keyboardType: TextInputType.number,
            maxLength: 16,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            validator: (v) => Validators.digits16(v, 'No. KK'),
          ),
          const SizedBox(height: 16),
          InputField(
            label: 'Alamat Lengkap',
            controller: _addressCtrl,
            hint: 'Alamat sesuai KK',
            icon: Icons.home_outlined,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            autofillHints: const [AutofillHints.fullStreetAddress],
            validator: Validators.address,
          ),
          const SizedBox(height: 16),
          // RT/RW opsional, dua input kecil sejajar, angka saja.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InputField(
                  label: 'RT (opsional)',
                  controller: _rtCtrl,
                  hint: '001',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InputField(
                  label: 'RW (opsional)',
                  controller: _rwCtrl,
                  hint: '002',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // "Lanjut" hanya aktif jika isian tahap ini valid.
          ListenableBuilder(
            listenable: Listenable.merge([
              _nameCtrl,
              _nikCtrl,
              _kkCtrl,
              _addressCtrl,
            ]),
            builder: (_, __) => AppButton(
              label: 'Lanjut',
              onPressed: _kkValid ? _handleNext : null,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Sudah punya akun? ',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                InkWell(
                  onTap: _goToLogin,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Masuk',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ── Tahap 2: Data Akun ── */
  Widget _buildAkunForm() {
    return Form(
      key: _akunFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputField(
            label: 'Nomor HP Aktif',
            controller: _phoneCtrl,
            hint: '08xxxxxxxxxx',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: Validators.phone,
          ),
          const SizedBox(height: 16),
          InputField(
            label: 'Email Aktif',
            controller: _emailCtrl,
            hint: 'nama@email.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: Validators.email,
          ),
          const SizedBox(height: 16),
          PasswordInput(
            label: 'Password',
            controller: _passCtrl,
            hint: 'Minimal 8 karakter, huruf dan angka',
            textInputAction: TextInputAction.next,
            validator: Validators.newPassword,
            onChanged: (_) => setState(() {}), // perbarui indikator & checklist
          ),
          PasswordStrengthIndicator(password: _passCtrl.text),
          const SizedBox(height: 12),
          // Checklist visual (bukan gate).
          PasswordChecklist(password: _passCtrl.text),
          const SizedBox(height: 16),
          PasswordInput(
            label: 'Konfirmasi Password',
            controller: _confirmCtrl,
            hint: 'Ulangi password',
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Konfirmasi password wajib diisi';
              }
              if (v != _passCtrl.text) return 'Konfirmasi password tidak sama';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Checkbox S&K: FormField agar ikut validasi form.
          FormField<bool>(
            initialValue: _agreed,
            validator: (v) => v == true ? null : 'Anda harus menyetujui Syarat & Ketentuan dan Kebijakan Privasi',
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: field.value,
                      activeColor: AppColors.primary,
                      isError: field.hasError,
                      semanticLabel:
                          'Setuju Syarat dan Ketentuan serta Kebijakan Privasi',
                      onChanged: (v) {
                        setState(() => _agreed = v ?? false);
                        field.didChange(_agreed);
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.textPrimary,
                            ),
                            children: [
                              const TextSpan(text: 'Saya menyetujui '),
                              TextSpan(
                                text: 'Syarat & Ketentuan',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                                // TODO: navigasi ke halaman S&K
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {},
                              ),
                              const TextSpan(text: ' dan '),
                              TextSpan(
                                text: 'Kebijakan Privasi',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                                // TODO: navigasi ke halaman Kebijakan Privasi
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {},
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: Text(
                      field.errorText!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ListenableBuilder(
            listenable: Listenable.merge([
              _phoneCtrl,
              _emailCtrl,
              _passCtrl,
              _confirmCtrl,
            ]),
            builder: (_, __) => AppButton(
              label: 'Lanjut',
              onPressed: _akunValid ? _handleNext : null,
            ),
          ),
        ],
      ),
    );
  }

  /* ── Tahap 3: Upload Dokumen (KTP & KK) ── */
  Widget _buildDocsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DocumentCapture(
          documentType: DocumentType.ktp,
          photo: _ktpPhoto,
          onChanged: (bytes) {
            if (mounted) setState(() => _ktpPhoto = bytes);
          },
        ),
        const SizedBox(height: 16),
        DocumentCapture(
          documentType: DocumentType.kk,
          photo: _kkPhoto,
          onChanged: (bytes) {
            if (mounted) setState(() => _kkPhoto = bytes);
          },
        ),
        const SizedBox(height: 24),
        // Nonaktif sampai kedua dokumen terisi.
        AppButton(
          label: 'Kirim Pendaftaran',
          loading: _loading,
          onPressed: _docsReady ? _handleSubmit : null,
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Kembali',
          variant: ButtonVariant.secondary,
          onPressed: _loading ? null : _handleBack,
        ),
      ],
    );
  }
}

/* ───────────────────────── Halaman Sukses (Step 4) ───────────────────────── */

/// Ringkasan registrasi yang diteruskan ke halaman sukses (hanya di memori).
class RegistrationSummary {
  const RegistrationSummary({required this.name, required this.kkNumber});
  final String name;
  final String kkNumber;

  /// Nomor KK disamarkan sebagian demi privasi.
  String get maskedKk => kkNumber.length == 16
      ? '${kkNumber.substring(0, 4)}••••••••${kkNumber.substring(12)}'
      : kkNumber;
}

class RegisterSuccessPage extends StatelessWidget {
  const RegisterSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final summary = args is RegistrationSummary ? args : null;

    return AuthLayout(
      title: 'Pendaftaran Berhasil!',
      subtitle: 'Akun Anda sedang menunggu verifikasi oleh Ketua RT. Anda akan menerima notifikasi setelah akun aktif.',
      aboveCard: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: StepIndicator(current: 3), // semua tahap selesai
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Semantics(
              label: 'Berhasil',
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1F22C55E),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 64,
                  color: AppColors.success,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (summary != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _SummaryRow(label: 'Kepala Keluarga', value: summary.name),
                  const SizedBox(height: 10),
                  _SummaryRow(label: 'Nomor KK', value: summary.maskedKk),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hourglass_top_rounded,
                              size: 14,
                              color: Color(0xFF92400E),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Menunggu Verifikasi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          // Tidak login otomatis.
          AppButton(
            label: 'Kembali ke Login',
            onPressed: () {
              // TODO: navigasi ke halaman login
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
