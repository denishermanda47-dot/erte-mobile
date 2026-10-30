import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../models/data_model.dart';
import '../../models/data_status.dart';
import '../../providers/auth_provider.dart';
import '../../services/resident_profile_repository.dart';
import '../../services/submission_repository.dart';
import '../auth/login_screen.dart';
import 'resident_directory_screen.dart';
import 'verification_screen.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _selectedIndex = 0;
  late final Stream<List<DataModel>> _submissionStream = ref
      .read(submissionRepositoryProvider)
      .watchAll();

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Keluar dari akun admin?',
      message: 'Sesi admin di perangkat ini akan diakhiri.',
      confirmLabel: 'Keluar',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(authControllerProvider.notifier).logout();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal keluar: $error')));
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      AppPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authControllerProvider).valueOrNull;
    final pages = [
      _AdminDashboard(
        name: admin?.name ?? 'Admin',
        onOpenVerifications: () => setState(() => _selectedIndex = 1),
        onOpenResidents: () => setState(() => _selectedIndex = 2),
      ),
      const VerificationScreen(),
      const ResidentDirectoryScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_selectedIndex) {
          0 => 'Panel admin',
          1 => 'Verifikasi pengajuan',
          _ => 'Data warga',
        }),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: StreamBuilder(
        stream: _submissionStream,
        builder: (context, snapshot) {
          final pending = (snapshot.data ?? const [])
              .where((item) => item.status.isAwaitingReview)
              .length;
          return NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard),
                label: 'Ringkasan',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: pending > 0,
                  label: Text('$pending'),
                  child: const Icon(Icons.fact_check_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: pending > 0,
                  label: Text('$pending'),
                  child: const Icon(Icons.fact_check),
                ),
                label: 'Verifikasi',
              ),
              const NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Data warga',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminDashboard extends ConsumerWidget {
  const _AdminDashboard({
    required this.name,
    required this.onOpenVerifications,
    required this.onOpenResidents,
  });

  final String name;
  final VoidCallback onOpenVerifications;
  final VoidCallback onOpenResidents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(submissionRepositoryProvider);
    final residentCount = ref
        .watch(residentProfileRepositoryProvider)
        .getAllResidents()
        .length;
    return StreamBuilder(
      stream: repository.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Gagal membaca database lokal: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const LoadingSkeleton();
        }
        final items = snapshot.data!;
        final pending = items
            .where((item) => item.status.isAwaitingReview)
            .length;
        final approved = items
            .where((item) => item.status == DataStatus.approved)
            .length;
        final rejected = items
            .where((item) => item.status == DataStatus.rejected)
            .length;
        final completed = items
            .where((item) => item.status == DataStatus.completed)
            .length;
        return RefreshIndicator(
          onRefresh: () async {
            repository.getAllData();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Halo, $name',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kelola pengajuan warga yang tersimpan lokal di perangkat.',
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    label: 'Menunggu',
                    value: pending,
                    icon: Icons.pending_actions,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  _Metric(
                    label: 'Selesai',
                    value: completed,
                    icon: Icons.verified_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _Metric(
                    label: 'Ditolak',
                    value: rejected,
                    icon: Icons.cancel_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  _Metric(
                    label: 'Disetujui',
                    value: approved,
                    icon: Icons.pending_actions,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  _Metric(
                    label: 'Total data',
                    value: items.length,
                    icon: Icons.inbox_outlined,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onOpenVerifications,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text('Buka verifikasi ($pending)'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onOpenResidents,
                icon: const Icon(Icons.people_outline),
                label: Text('Lihat data warga ($residentCount)'),
              ),
              const SizedBox(height: 24),
              Text(
                'Pengajuan terbaru',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Belum ada pengajuan',
                  message: 'Data baru dari warga akan muncul di perangkat ini.',
                )
              else
                ...items
                    .take(4)
                    .map(
                      (item) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.description_outlined),
                          ),
                          title: Text(item.title),
                          subtitle: Text(item.userName),
                          trailing: Text(item.status.label),
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 52) / 2;
    return SizedBox(
      width: width.clamp(145, 260),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label),
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
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
