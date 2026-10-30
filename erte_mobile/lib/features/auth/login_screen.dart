import 'package:flutter/material.dart';

import '../../main.dart' show LoginPage;

/// Jembatan: dashboard tim memanggil `LoginScreen` (mis. saat logout).
/// Di proyek gabungan, layar login yang dipakai adalah `LoginPage` milik Anda
/// (login ke API). File ini menggantikan login_screen.dart milik tim.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => const LoginPage();
}
