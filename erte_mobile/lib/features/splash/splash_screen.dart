import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_route.dart';
import '../../features/admin/admin_home_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/user/home_screen.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeIn,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1,
  ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutBack));
  Object? _error;

  @override
  void initState() {
    super.initState();
    _openApp();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  Future<void> _openApp() async {
    final minimumDisplay = Future<void>.delayed(
      const Duration(milliseconds: 900),
    );
    await ref.read(authControllerProvider.notifier).bootstrap();
    await minimumDisplay;
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (auth.hasError) {
      setState(() => _error = auth.error);
      return;
    }
    final user = auth.valueOrNull;
    Navigator.of(context).pushReplacement(
      AppPageRoute<void>(
        builder: (_) => user == null
            ? const LoginScreen()
            : user.isAdmin
            ? const AdminHomeScreen()
            : HomeScreen(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -110,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -190,
            left: -130,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.045),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: 'app-logo',
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primaryGradientStart,
                              AppColors.primaryGradientEnd,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.holiday_village_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'ERTE',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Layanan warga, lebih dekat.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 34),
                    if (_error == null)
                      SizedBox(
                        width: 210,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: const LinearProgressIndicator(
                                minHeight: 5,
                                backgroundColor: AppColors.primaryLight,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Menyiapkan layanan...',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 26,
                      ),
                      const SizedBox(height: 8),
                      const Text('Gagal membuka data aplikasi.'),
                      TextButton(
                        onPressed: () {
                          setState(() => _error = null);
                          _openApp();
                        },
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
