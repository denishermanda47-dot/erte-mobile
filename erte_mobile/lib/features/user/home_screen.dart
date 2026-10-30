import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../models/data_status.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/submission_repository.dart';
import '../auth/login_screen.dart';
import 'my_data_screen.dart';
import 'home_widgets.dart';
import 'profile_screen.dart';
import 'resident_services_screen.dart';
import 'resident_profile_screen.dart';
import 'submit_data_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({required this.user, super.key});

  final UserModel user;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  late UserModel _user = widget.user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyReviewUpdates());
  }

  Future<void> _notifyReviewUpdates() async {
    final repository = ref.read(submissionRepositoryProvider);
    final changed = repository.getUnseenReviews(_user.id);
    await repository.markReviewsSeen(_user.id);
    if (!mounted || changed.isEmpty) return;
    final approved = changed.where(
      (item) => item.status == DataStatus.approved,
    );
    final rejected = changed.where(
      (item) => item.status == DataStatus.rejected,
    );
    final completed = changed.where(
      (item) => item.status == DataStatus.completed,
    );
    final summary = <String>[
      if (approved.isNotEmpty) '${approved.length} data disetujui',
      if (completed.isNotEmpty) '${completed.length} surat selesai',
      if (rejected.isNotEmpty) '${rejected.length} data ditolak',
    ].join(', ');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Pembaruan verifikasi: $summary.')));
  }

  Future<void> _openSubmit() async {
    final submitted = await Navigator.of(context).push<bool>(
      AppPageRoute<bool>(builder: (_) => SubmitDataScreen(user: _user)),
    );
    if (submitted == true && mounted) {
      setState(() => _selectedIndex = 2);
    }
  }

  void _openResidentProfile() {
    Navigator.of(context).push<void>(
      AppPageRoute<void>(builder: (_) => ResidentProfileScreen(user: _user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _UserDashboard(
        user: _user,
        onOpenServices: () => setState(() => _selectedIndex = 1),
        onOpenHistory: () => setState(() => _selectedIndex = 2),
        onOpenResidentProfile: _openResidentProfile,
      ),
      ResidentServicesScreen(
        user: _user,
        onOpenHistory: () => setState(() => _selectedIndex = 2),
      ),
      MyDataScreen(user: _user),
      ProfileScreen(user: _user),
    ];

    ref.listen(authControllerProvider, (previous, next) {
      final updated = next.valueOrNull;
      if (updated == null && previous?.valueOrNull != null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          AppPageRoute<void>(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      } else if (updated != null && mounted) {
        setState(() => _user = updated);
      }
    });

    return Scaffold(
      appBar: CustomAppBar(
        greetingName: _user.name,
        notificationCount: 0,
        onNotifications: () => setState(() => _selectedIndex = 2),
        onProfile: () => setState(() => _selectedIndex = 3),
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openSubmit,
              icon: const Icon(Icons.add),
              label: const Text('Kirim data'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Layanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Aktivitas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _UserDashboard extends ConsumerWidget {
  const _UserDashboard({
    required this.user,
    required this.onOpenServices,
    required this.onOpenHistory,
    required this.onOpenResidentProfile,
  });

  final UserModel user;
  final VoidCallback onOpenServices;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenResidentProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(submissionRepositoryProvider);
    return StreamBuilder(
      stream: repository.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Gagal membaca data lokal: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) return const LoadingSkeleton();
        final items = (snapshot.data ?? const [])
            .where((item) => item.userId == user.id)
            .toList();
        final pending = items
            .where((item) => item.status == DataStatus.pending)
            .length;
        return RefreshIndicator(
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 180));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              GreetingCard(name: user.name),
              const SizedBox(height: 24),
              HomeSectionHeader(
                title: 'Akses cepat',
                actionLabel: 'Lihat semua',
                onAction: onOpenServices,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: QuickAccessItem(
                      icon: Icons.people_alt_outlined,
                      label: 'Data warga',
                      color: AppColors.primary,
                      backgroundColor: AppColors.primaryLight,
                      onTap: onOpenResidentProfile,
                    ),
                  ),
                  Expanded(
                    child: QuickAccessItem(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Iuran',
                      color: AppColors.amber,
                      backgroundColor: AppColors.amberLight,
                      onTap: () => openResidentService(
                        context,
                        user: user,
                        onOpenHistory: onOpenHistory,
                        service: ResidentServiceShortcut.dues,
                      ),
                    ),
                  ),
                  Expanded(
                    child: QuickAccessItem(
                      icon: Icons.markunread_mailbox_outlined,
                      label: 'Surat',
                      color: AppColors.purple,
                      backgroundColor: AppColors.purpleLight,
                      onTap: () => openResidentService(
                        context,
                        user: user,
                        onOpenHistory: onOpenHistory,
                        service: ResidentServiceShortcut.letter,
                      ),
                    ),
                  ),
                  Expanded(
                    child: QuickAccessItem(
                      icon: Icons.campaign_outlined,
                      label: 'Lapor',
                      color: AppColors.coral,
                      backgroundColor: AppColors.coralLight,
                      onTap: () => openResidentService(
                        context,
                        user: user,
                        onOpenHistory: onOpenHistory,
                        service: ResidentServiceShortcut.complaint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              HomeSectionHeader(title: 'Informasi lingkungan'),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InfoCard(
                      icon: Icons.people_alt_outlined,
                      title: 'Warga terdaftar',
                      value: '0',
                      subtitle: 'Data lingkungan',
                      color: AppColors.primary,
                      iconBackground: AppColors.primaryLight,
                      onTap: onOpenResidentProfile,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InfoCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Status iuran',
                      value: null,
                      subtitle: 'Belum ada data',
                      color: AppColors.amber,
                      iconBackground: AppColors.amberLight,
                      statusColor: Theme.of(context).colorScheme.outline,
                      onTap: () => openResidentService(
                        context,
                        user: user,
                        onOpenHistory: onOpenHistory,
                        service: ResidentServiceShortcut.dues,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              HomeSectionHeader(
                title: 'Pengumuman terbaru',
                actionLabel: 'Lihat semua',
                onAction: () => openResidentService(
                  context,
                  user: user,
                  onOpenHistory: onOpenHistory,
                  service: ResidentServiceShortcut.announcements,
                ),
              ),
              const SizedBox(height: 10),
              const EmptyAnnouncementCard(),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  onTap: onOpenHistory,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(
                      Icons.pending_actions_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'Aktivitas pengajuan',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '$pending pengajuan menunggu · ${items.length} total',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
