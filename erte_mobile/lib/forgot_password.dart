// ERTE - Alur Lupa Password / Reset Password (UI-only, semua aksi MOCK).
//
// Tidak ada API, permintaan jaringan, token, penyimpanan lokal, atau
// pengiriman OTP sungguhan. Semua perpindahan step disimulasikan lewat state
// lokal. Cari teks "TODO: integrasi API" untuk menemukan titik yang nanti
// perlu disambungkan ke backend.
//
// File ini memakai komponen dari main.dart (AuthLayout, InputField,
// PasswordInput, AppButton, PasswordStrengthIndicator, StepIndicator, dll.)
// supaya tampilannya konsisten dengan halaman Login & Register.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';

enum VerifyMethod { email, phone }

/* ───────────────────────── Validasi khusus alur ini ───────────────────────── */

class _ForgotValidators {
  /// Nomor HP Indonesia: hanya angka, 10–14 digit, diawali 08 atau 628.
  static String? phone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Nomor HP wajib diisi';
    if (!RegExp(r'^\d+$').hasMatch(s))
      return 'Nomor HP hanya boleh berisi angka';
    if (s.length < 10 || s.length > 14) return 'Nomor HP harus 10–14 digit';
    if (!(s.startsWith('08') || s.startsWith('628'))) {
      return 'Gunakan format Indonesia, contoh 08123456789';
    }
    return null;
  }

  /// NIK opsional: kosong boleh, kalau diisi harus 16 digit angka.
  static String? optionalNik(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^\d{16}$').hasMatch(s)) return 'NIK harus 16 digit angka';
    return null;
  }
}

/* ───────────────────────── Halaman (4 step) ───────────────────────── */

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.demoTooManyAttempts = false});

  /// Mock: set true untuk melihat state "Terlalu banyak percobaan" di Step 2.
  /// Nanti bisa dikendalikan dari respons backend.
  final bool demoTooManyAttempts;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const _otpValiditySeconds = 5 * 60; // 04:59 → tampilan saja
  static const _resendCooldownSeconds = 60;

  // State alur
  int _step = 1; // 1..4
  VerifyMethod _method = VerifyMethod.email;

  // Form & controller (state lokal saja, tidak disimpan ke mana pun)
  final _identityKey = GlobalKey<FormState>();
  final _passKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // OTP
  String _otp = '';
  String? _otpError;
  int _otpResetKey = 0; // dinaikkan agar kotak OTP dikosongkan
  late bool _tooManyAttempts = widget.demoTooManyAttempts;

  // Timer (visual saja, tidak memengaruhi validasi)
  Timer? _timer;
  int _otpSeconds = _otpValiditySeconds;
  int _resendSeconds = _resendCooldownSeconds;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [
      _emailCtrl,
      _phoneCtrl,
      _nikCtrl,
      _newPassCtrl,
      _confirmCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /* ── Timer ── */

  void _startTimers() {
    _otpSeconds = _otpValiditySeconds;
    _resendSeconds = _resendCooldownSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_otpSeconds > 0) _otpSeconds--;
        if (_resendSeconds > 0) _resendSeconds--;
        if (_otpSeconds == 0 && _resendSeconds == 0) _stopTimers();
      });
    });
  }

  void _stopTimers() {
    _timer?.cancel();
    _timer = null;
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /* ── Handler placeholder (mudah diganti saat integrasi) ── */

  /// Pindah step. Dipakai semua handler mock di bawah.
  void _setStep(int step) {
    FocusScope.of(context).unfocus();
    _stopTimers();
    if (step == 2) {
      _otp = '';
      _otpError = null;
      _otpResetKey++;
      _startTimers();
    }
    setState(() => _step = step);
  }

  void _handleSendCode() {
    if (!_identityKey.currentState!.validate()) return;
    // TODO: integrasi API kirim OTP di sini
    _setStep(2);
  }

  void _handleVerifyOtp() {
    if (_otp.isEmpty) {
      setState(() => _otpError = 'Kode verifikasi wajib diisi');
      return;
    }
    if (_otp.length < 6) {
      setState(() => _otpError = 'Masukkan 6 digit kode');
      return;
    }
    // TODO: integrasi API verifikasi OTP di sini
    // Mode demo: 6 digit apa saja dianggap valid.
    _setStep(3);
  }

  void _handleResendOtp() {
    if (_resendSeconds > 0) return;
    // TODO: integrasi API kirim ulang OTP
    setState(() {
      _otp = '';
      _otpError = null;
      _otpResetKey++;
    });
    _startTimers();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        content: Text('Mode demo: tidak ada kode yang benar-benar dikirim.'),
      ),
    );
  }

  void _handleResetPassword() {
    if (!_passKey.currentState!.validate()) return;
    // TODO: integrasi API reset password di sini
    // Password tidak disimpan di mana pun; kosongkan dari memori form.
    _newPassCtrl.clear();
    _confirmCtrl.clear();
    _setStep(4);
  }

  void _goToLogin() {
    // TODO: navigasi ke halaman login (sesuaikan dengan router aplikasi)
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _handleBack() => _setStep(_step - 1);

  /* ── Build ── */

  String get _destination => _method == VerifyMethod.email
      ? _emailCtrl.text.trim()
      : _phoneCtrl.text.trim();

  @override
  Widget build(BuildContext context) {
    late final String title;
    late final String subtitle;
    switch (_step) {
      case 1:
        title = 'Lupa Password?';
        subtitle = 'Masukkan data akun Anda untuk menerima kode verifikasi.';
      case 2:
        title = 'Masukkan Kode Verifikasi';
        subtitle = 'Kode 6 digit telah dikirim ke $_destination.';
      case 3:
        title = 'Buat Password Baru';
        subtitle = 'Password minimal 8 karakter, kombinasi huruf dan angka.';
      default:
        title = 'Password Berhasil Diubah';
        subtitle = 'Silakan masuk kembali dengan password baru Anda.';
    }

    return AuthLayout(
      title: title,
      subtitle: subtitle,
      // Step indicator di atas card (Step 4 tidak masuk indikator).
      aboveCard: _step <= 3
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: StepIndicator(
                current: _step - 1,
                labels: const ['Verifikasi', 'Kode OTP', 'Password Baru'],
              ),
            )
          : null,
      // Tombol Kembali di kiri atas card untuk Step 2 dan 3.
      header: (_step == 2 || _step == 3)
          ? TextButton.icon(
              onPressed: _handleBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Kembali'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
            )
          : null,
      child: switch (_step) {
        1 => _buildIdentityStep(),
        2 => _buildOtpStep(),
        3 => _buildNewPasswordStep(),
        _ => _buildSuccessStep(),
      },
    );
  }

  /* ── Step 1: Verifikasi identitas ── */

  Widget _buildIdentityStep() {
    return Form(
      key: _identityKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MethodTabs(
            value: _method,
            onChanged: (m) => setState(() => _method = m),
          ),
          const SizedBox(height: 16),
          // Key berbeda agar state validasi tidak terbawa saat ganti tab.
          if (_method == VerifyMethod.email)
            InputField(
              key: const ValueKey('field-email'),
              label: 'Email',
              controller: _emailCtrl,
              hint: 'nama@email.com',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
            )
          else
            InputField(
              key: const ValueKey('field-phone'),
              label: 'Nomor HP / WhatsApp',
              controller: _phoneCtrl,
              hint: '08xxxxxxxxxx',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(14),
              ],
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: _ForgotValidators.phone,
            ),
          const SizedBox(height: 16),
          InputField(
            label: 'NIK (opsional, untuk verifikasi tambahan)',
            controller: _nikCtrl,
            hint: '16 digit angka',
            icon: Icons.credit_card_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
            textInputAction: TextInputAction.done,
            validator: _ForgotValidators.optionalNik,
          ),
          const SizedBox(height: 24),
          AppButton(label: 'Kirim Kode Verifikasi', onPressed: _handleSendCode),
          const SizedBox(height: 12),
          const Text(
            'Jika data cocok, kode akan dikirim. Demi keamanan, kami tidak mengonfirmasi apakah akun terdaftar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Ingat password? ',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                InkWell(
                  onTap: _goToLogin,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Masuk di sini',
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

  /* ── Step 2: Verifikasi OTP ── */

  Widget _buildOtpStep() {
    final expired = _otpSeconds == 0;
    final canResend = _resendSeconds == 0 && !_tooManyAttempts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // State statis "Terlalu banyak percobaan" (toggle via props/mock state).
        if (_tooManyAttempts) ...[
          const AlertBox(
            type: AlertType.error,
            message: 'Terlalu banyak percobaan. Silakan coba lagi beberapa saat lagi.',
          ),
          const SizedBox(height: 16),
        ],
        const Text(
          'Kode Verifikasi',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        OtpInput(
          key: ValueKey('otp-$_otpResetKey'),
          autofocus: !_tooManyAttempts,
          enabled: !_tooManyAttempts,
          hasError: _otpError != null,
          onChanged: (v) => setState(() {
            _otp = v;
            _otpError = null;
          }),
        ),
        if (_otpError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _otpError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 16,
              color: expired ? AppColors.error : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                expired
                    ? 'Kode sudah kedaluwarsa. Kirim ulang kode baru.'
                    : 'Kode berlaku selama ${_fmt(_otpSeconds)}',
                style: TextStyle(
                  fontSize: 13,
                  color: expired ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Mode demo: masukkan 6 digit apa saja untuk melanjutkan.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Verifikasi',
          onPressed: _tooManyAttempts ? null : _handleVerifyOtp,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: canResend ? _handleResendOtp : null,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              disabledForegroundColor: AppColors.textSecondary,
            ),
            child: Text(
              _resendSeconds > 0
                  ? 'Kirim ulang dalam ${_fmt(_resendSeconds)}'
                  : 'Kirim Ulang Kode',
            ),
          ),
        ),
      ],
    );
  }

  /* ── Step 3: Password baru ── */

  Widget _buildNewPasswordStep() {
    return Form(
      key: _passKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PasswordInput(
            label: 'Password Baru',
            controller: _newPassCtrl,
            hint: 'Minimal 8 karakter, huruf dan angka',
            textInputAction: TextInputAction.next,
            validator: Validators.newPassword,
            onChanged: (_) => setState(() {}), // perbarui indikator & checklist
          ),
          PasswordStrengthIndicator(password: _newPassCtrl.text),
          const SizedBox(height: 12),
          PasswordChecklist(password: _newPassCtrl.text),
          const SizedBox(height: 16),
          PasswordInput(
            label: 'Konfirmasi Password Baru',
            controller: _confirmCtrl,
            hint: 'Ulangi password baru',
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleResetPassword(),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Konfirmasi password wajib diisi';
              }
              if (v != _newPassCtrl.text)
                return 'Konfirmasi password tidak sama';
              return null;
            },
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Simpan Password Baru',
            onPressed: _handleResetPassword,
          ),
        ],
      ),
    );
  }

  /* ── Step 4: Sukses ── */

  Widget _buildSuccessStep() {
    return Column(
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
        const SizedBox(height: 28),
        // Tidak login otomatis.
        AppButton(label: 'Kembali ke Login', onPressed: _goToLogin),
      ],
    );
  }
}

/* ───────────────────────── Komponen khusus alur ini ───────────────────────── */

/// Tab pilihan metode verifikasi: Email / Nomor HP/WhatsApp.
class _MethodTabs extends StatelessWidget {
  const _MethodTabs({required this.value, required this.onChanged});
  final VerifyMethod value;
  final ValueChanged<VerifyMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(VerifyMethod m, IconData icon, String label) {
      final selected = value == m;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: 'Verifikasi lewat $label',
          child: ExcludeSemantics(
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x1A1E293B),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.primaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          tab(VerifyMethod.email, Icons.mail_outline, 'Email'),
          tab(VerifyMethod.phone, Icons.phone_outlined, 'Nomor HP/WhatsApp'),
        ],
      ),
    );
  }
}

/// Input OTP 6 kotak.
///
/// Di balik 6 kotak ada SATU TextField transparan (numeric, maxLength 6,
/// autofill one-time-code). Cara ini membuat paste, backspace, dan autofill
/// SMS bekerja andal, sementara kotak yang aktif bergeser otomatis setiap
/// satu digit diketik.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    this.length = 6,
    this.onChanged,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = false,
  });
  final int length;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _ctrl.text;
    final active = (widget.enabled && _focus.hasFocus)
        ? text.length.clamp(0, widget.length - 1)
        : -1;

    return Semantics(
      label: 'Kode verifikasi ${widget.length} digit',
      textField: true,
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 8.0;
          final boxW =
              ((c.maxWidth - gap * (widget.length - 1)) / widget.length).clamp(
                36.0,
                52.0,
              );

          final boxes = <Widget>[];
          for (var i = 0; i < widget.length; i++) {
            final isActive = i == active;
            final borderColor = widget.hasError
                ? AppColors.error
                : isActive
                ? AppColors.primary
                : AppColors.border;
            boxes.add(
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: boxW,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.enabled ? AppColors.white : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: borderColor,
                    width: (isActive || widget.hasError) ? 2 : 1,
                  ),
                ),
                child: Text(
                  i < text.length ? text[i] : '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            );
            if (i < widget.length - 1) boxes.add(const SizedBox(width: gap));
          }

          return SizedBox(
            height: 56,
            child: Stack(
              children: [
                ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: boxes,
                  ),
                ),
                // TextField transparan yang menangkap input & tap.
                Positioned.fill(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    cursorColor: Colors.transparent,
                    style: const TextStyle(color: Colors.transparent),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: widget.onChanged,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Checklist visual syarat password (bukan penghalang submit).
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    Widget row(bool ok, String text) {
      return Semantics(
        label: '$text: ${ok ? "terpenuhi" : "belum terpenuhi"}',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  ok ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: ok ? AppColors.success : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: ok
                        ? const Color(0xFF15803D)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(password.length >= 8, 'Minimal 8 karakter'),
        row(RegExp(r'[A-Za-z]').hasMatch(password), 'Mengandung huruf'),
        row(RegExp(r'\d').hasMatch(password), 'Mengandung angka'),
      ],
    );
  }
}

enum AlertType { error, info, success }

/// Kotak pesan untuk error / info / sukses.
class AlertBox extends StatelessWidget {
  const AlertBox({
    super.key,
    required this.message,
    this.type = AlertType.info,
  });
  final String message;
  final AlertType type;

  @override
  Widget build(BuildContext context) {
    late final Color fg;
    late final Color bg;
    late final Color border;
    late final IconData icon;
    switch (type) {
      case AlertType.error:
        fg = const Color(0xFFB91C1C);
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFECACA);
        icon = Icons.error_outline;
      case AlertType.success:
        fg = const Color(0xFF15803D);
        bg = const Color(0xFFF0FDF4);
        border = const Color(0xFFBBF7D0);
        icon = Icons.check_circle_outline;
      case AlertType.info:
        fg = AppColors.primaryDark;
        bg = AppColors.lightBg;
        border = const Color(0xFFBFDBFE);
        icon = Icons.info_outline;
    }

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 13, height: 1.4, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// UI-only. Sambungkan handler di titik TODO untuk mengaktifkan alur:
//   _handleSendCode, _handleVerifyOtp, _handleResendOtp, _handleResetPassword.
