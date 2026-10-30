import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../models/user_model.dart';
import '../../services/resident_profile_repository.dart';
import '../../services/resident_services_repository.dart';
import '../../services/submission_repository.dart';
import 'resident_profile_screen.dart';

final residentServicesRepositoryProvider = Provider<ResidentServicesRepository>(
  (ref) => ResidentServicesRepository(),
);

enum ResidentServiceShortcut {
  letter,
  dues,
  complaint,
  guests,
  announcements,
  contacts,
}

Future<void> openResidentService(
  BuildContext context, {
  required UserModel user,
  required VoidCallback onOpenHistory,
  required ResidentServiceShortcut service,
}) {
  final page = switch (service) {
    ResidentServiceShortcut.letter => _NewRequestPage(
      user: user,
      onDone: onOpenHistory,
    ),
    ResidentServiceShortcut.dues => _DuesPage(user: user),
    ResidentServiceShortcut.complaint => _NewComplaintPage(
      user: user,
      onDone: onOpenHistory,
    ),
    ResidentServiceShortcut.guests => _GuestVisitsPage(user: user),
    ResidentServiceShortcut.announcements => const _AnnouncementsPage(),
    ResidentServiceShortcut.contacts => const _EmergencyContactsPage(),
  };
  return Navigator.of(context).push(AppPageRoute<void>(builder: (_) => page));
}

class ResidentServicesScreen extends StatelessWidget {
  const ResidentServicesScreen({
    required this.user,
    required this.onOpenHistory,
    super.key,
  });

  final UserModel user;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    children: [
      Text(
        'Layanan warga',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'Pilih layanan. Data demo disimpan lokal di perangkat ini.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 18),
      _ServiceCard(
        icon: Icons.badge_outlined,
        title: 'Data warga',
        subtitle: 'Lengkapi data sesuai KTP dan Kartu Keluarga',
        color: const Color(0xFF147D86),
        onTap: () => _open(context, ResidentProfileScreen(user: user)),
      ),
      _ServiceCard(
        icon: Icons.description_outlined,
        title: 'Surat pengantar',
        subtitle: 'Ajukan surat domisili, SKCK, usaha, dan lainnya',
        color: AppColors.primary,
        onTap: () =>
            _open(context, _NewRequestPage(user: user, onDone: onOpenHistory)),
      ),
      _ServiceCard(
        icon: Icons.campaign_outlined,
        title: 'Pengaduan lingkungan',
        subtitle: 'Laporkan masalah agar dapat ditinjau admin',
        color: const Color(0xFFAA6C20),
        onTap: () => _open(
          context,
          _NewComplaintPage(user: user, onDone: onOpenHistory),
        ),
      ),
      _ServiceCard(
        icon: Icons.payments_outlined,
        title: 'Iuran warga',
        subtitle: 'Lihat tagihan dan catat pembayaran demo',
        color: const Color(0xFF355B9A),
        onTap: () => _open(context, _DuesPage(user: user)),
      ),
      _ServiceCard(
        icon: Icons.doorbell_outlined,
        title: 'Daftarkan tamu',
        subtitle: 'Catat kunjungan tamu ke rumah Anda',
        color: const Color(0xFF8154A5),
        onTap: () => _open(context, _GuestVisitsPage(user: user)),
      ),
      _ServiceCard(
        icon: Icons.notifications_active_outlined,
        title: 'Pengumuman RT',
        subtitle: 'Informasi kegiatan dan layanan warga',
        color: const Color(0xFF147D86),
        onTap: () => _open(context, const _AnnouncementsPage()),
      ),
      _ServiceCard(
        icon: Icons.phone_in_talk_outlined,
        title: 'Kontak penting',
        subtitle: 'Hubungi layanan darurat atau pengurus RT',
        color: const Color(0xFFB34343),
        onTap: () => _open(context, const _EmergencyContactsPage()),
      ),
    ],
  );

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(AppPageRoute<void>(builder: (_) => page));
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _NewRequestPage extends ConsumerStatefulWidget {
  const _NewRequestPage({required this.user, required this.onDone});
  final UserModel user;
  final VoidCallback onDone;

  @override
  ConsumerState<_NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends ConsumerState<_NewRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final List<String> _attachments = [];
  String? _requestType;
  bool _saving = false;

  static const _requestTypes = [
    'Surat Pengantar RT/RW (Umum)',
    'Surat Keterangan Domisili',
    'Surat Keterangan Tidak Mampu (SKTM)',
    'Surat Pengantar SKCK',
    'Surat Pengantar Nikah (N1-N4)',
    'Surat Keterangan Usaha (SKU)',
    'Surat Keterangan Kelahiran',
    'Surat Keterangan Kematian',
  ];

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ajukan surat')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Pilih jenis surat dan jelaskan keperluannya. Pengajuan masuk ke antrean verifikasi admin.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _requestType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Jenis surat',
              prefixIcon: Icon(Icons.description_outlined),
            ),
            items: _requestTypes
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(
                      type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) =>
                value == null ? 'Pilih jenis surat terlebih dahulu.' : null,
            onChanged: (value) => setState(() => _requestType = value),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _description,
            label: 'Keterangan / tujuan penggunaan',
            hint: 'Contoh: persyaratan administrasi pekerjaan.',
            icon: Icons.notes_outlined,
            minLines: 4,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) =>
                AppValidators.minLength(value, length: 8, label: 'Keterangan'),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.attach_file_outlined),
                  title: const Text('Lampiran persyaratan'),
                  subtitle: Text(
                    '${_attachments.length}/3 file · gambar atau PDF',
                  ),
                  trailing: IconButton(
                    tooltip: 'Tambah lampiran',
                    onPressed: _attachments.length == 3 || _saving
                        ? null
                        : _pickAttachments,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ),
                ..._attachments.asMap().entries.map(
                  (entry) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(
                      entry.value.split(RegExp(r'[/\\]')).last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Hapus lampiran',
                      onPressed: _saving
                          ? null
                          : () => setState(
                              () => _attachments.removeAt(entry.key),
                            ),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          CustomButton(
            label: 'Kirim pengajuan',
            icon: Icons.send_outlined,
            isLoading: _saving,
            onPressed: _submit,
          ),
        ],
      ),
    ),
  );

  Future<void> _pickAttachments() async {
    final selected = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (selected.isEmpty || !mounted) return;
    if (_attachments.length + selected.length > 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 3 file lampiran.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final paths = <String>[];
      for (final file in selected) {
        final path = file.path;
        if (path == null) {
          throw StateError('File ${file.name} tidak dapat dibaca.');
        }
        paths.add(
          await ref
              .read(residentServicesRepositoryProvider)
              .storeLetterAttachment(userId: widget.user.id, sourcePath: path),
        );
      }
      if (!mounted) return;
      setState(() => _attachments.addAll(paths));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambahkan lampiran: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = ref
        .read(residentProfileRepositoryProvider)
        .getProfile(widget.user.id);
    if (profile == null) {
      final openProfile = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Lengkapi data warga'),
          content: const Text(
            'Data sesuai KTP/KK wajib dilengkapi sebelum mengajukan surat.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Nanti'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Lengkapi data'),
            ),
          ],
        ),
      );
      if (openProfile == true && mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ResidentProfileScreen(user: widget.user),
          ),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(submissionRepositoryProvider)
          .submitData(
            user: widget.user,
            title: _requestType!,
            description: _description.text,
            attachments: _attachments,
            isLetterRequest: true,
            applicantDetails: {
              'NIK': profile.nik,
              'No. KK': profile.familyCardNumber,
              'Nama lengkap': profile.fullName,
              'Tempat, tanggal lahir':
                  '${profile.birthPlace}, ${DateFormat('dd/MM/yyyy').format(profile.birthDate)}',
              'Jenis kelamin': profile.gender,
              'Agama': profile.religion,
              'Status perkawinan': profile.maritalStatus,
              'Pekerjaan': profile.occupation,
              'Alamat':
                  '${profile.address}, RT ${profile.rt}/RW ${profile.rw}',
              'No. HP': profile.phoneNumber,
              'Hubungan keluarga': profile.familyRelationship,
            },
          );
      if (!mounted) return;
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan surat dikirim ke antrean verifikasi.'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim pengajuan: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _NewComplaintPage extends ConsumerStatefulWidget {
  const _NewComplaintPage({required this.user, required this.onDone});
  final UserModel user;
  final VoidCallback onDone;

  @override
  ConsumerState<_NewComplaintPage> createState() => _NewComplaintPageState();
}

class _NewComplaintPageState extends ConsumerState<_NewComplaintPage> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  String? _category;
  bool _saving = false;

  static const _categories = [
    'Sampah dan kebersihan',
    'Keamanan lingkungan',
    'Jalan dan fasilitas umum',
    'Ketertiban warga',
    'Lainnya',
  ];

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengaduan lingkungan')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Pengaduan akan terlihat oleh admin pada daftar verifikasi lokal.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Kategori pengaduan',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: _categories
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            validator: (value) =>
                value == null ? 'Pilih kategori pengaduan.' : null,
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _description,
            label: 'Ceritakan masalahnya',
            hint: 'Tuliskan lokasi dan informasi yang membantu.',
            icon: Icons.edit_note,
            minLines: 4,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) =>
                AppValidators.minLength(value, length: 10, label: 'Pengaduan'),
          ),
          const SizedBox(height: 20),
          CustomButton(
            label: 'Kirim pengaduan',
            icon: Icons.send_outlined,
            isLoading: _saving,
            onPressed: _submit,
          ),
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(submissionRepositoryProvider)
          .submitData(
            user: widget.user,
            title: 'Pengaduan: $_category',
            description: _description.text,
          );
      if (!mounted) return;
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaduan berhasil dikirim ke admin.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pengaduan gagal dikirim: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DuesPage extends ConsumerStatefulWidget {
  const _DuesPage({required this.user});
  final UserModel user;

  @override
  ConsumerState<_DuesPage> createState() => _DuesPageState();
}

class _DuesPageState extends ConsumerState<_DuesPage> {
  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(residentServicesRepositoryProvider);
    final dues = repository.getMonthlyDues(widget.user.id);
    final outstanding = dues.where((item) => !item.isPaid).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Iuran warga')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Simulasi lokal. Tombol bayar hanya mencatat status demo di perangkat ini, tidak memproses uang.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$outstanding bulan belum dicatat lunas dari riwayat yang ditampilkan.',
          ),
          const SizedBox(height: 12),
          ...dues.map((item) {
            final month = DateFormat('MMMM yyyy', 'id_ID').format(item.month);
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    item.isPaid ? Icons.check : Icons.payments_outlined,
                  ),
                ),
                title: Text(
                  month,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(item.amount)} · ${item.isPaid ? 'Lunas' : 'Belum dibayar'}',
                ),
                trailing: item.isPaid
                    ? const Icon(Icons.verified, color: Colors.green)
                    : TextButton(
                        onPressed: () => _markPaid(item),
                        child: const Text('Catat lunas'),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _markPaid(MonthlyDues dues) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Catat iuran lunas?',
      message:
          'Ini hanya simulasi untuk demo. Tidak ada pembayaran uang sungguhan.',
      confirmLabel: 'Catat lunas',
    );
    if (!confirmed || !mounted) return;
    await ref
        .read(residentServicesRepositoryProvider)
        .markDuesPaid(widget.user.id, dues.month);
    if (mounted) setState(() {});
  }
}

class _GuestVisitsPage extends ConsumerStatefulWidget {
  const _GuestVisitsPage({required this.user});
  final UserModel user;

  @override
  ConsumerState<_GuestVisitsPage> createState() => _GuestVisitsPageState();
}

class _GuestVisitsPageState extends ConsumerState<_GuestVisitsPage> {
  @override
  Widget build(BuildContext context) {
    final visits = ref
        .watch(residentServicesRepositoryProvider)
        .getGuestVisits(widget.user.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Daftarkan tamu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _register,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Daftarkan tamu'),
      ),
      body: visits.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Belum ada tamu yang dicatat. Tekan tombol untuk mendaftarkan kunjungan.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: visits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final visit = visits[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(visit.name),
                    subtitle: Text(
                      '${visit.purpose}\n${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(visit.createdAt)}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }

  Future<void> _register() async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final purpose = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Daftarkan tamu'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama tamu'),
                validator: (value) =>
                    AppValidators.minLength(value, length: 2, label: 'Nama'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: purpose,
                decoration: const InputDecoration(
                  labelText: 'Tujuan kunjungan',
                ),
                validator: (value) =>
                    AppValidators.minLength(value, length: 3, label: 'Tujuan'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      try {
        await ref
            .read(residentServicesRepositoryProvider)
            .registerGuest(
              userId: widget.user.id,
              name: name.text,
              purpose: purpose.text,
            );
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kunjungan tamu berhasil dicatat.')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Tamu gagal dicatat: $error')));
        }
      }
    }
    name.dispose();
    purpose.dispose();
  }
}

class _AnnouncementsPage extends StatelessWidget {
  const _AnnouncementsPage();

  static final _items = [
    (
      title: 'Kerja bakti lingkungan',
      body:
          'Minggu, pukul 07.00. Berkumpul di pos RT dan membawa alat kebersihan.',
      date: DateTime(2026, 10, 25),
      icon: Icons.cleaning_services_outlined,
    ),
    (
      title: 'Jadwal posyandu',
      body:
          'Pelayanan posyandu di balai warga pada Sabtu pekan pertama pukul 09.00.',
      date: DateTime(2026, 10, 18),
      icon: Icons.health_and_safety_outlined,
    ),
    (
      title: 'Pemeliharaan saluran air',
      body:
          'Mohon tidak memarkir kendaraan di akses jalan selama pekerjaan berlangsung.',
      date: DateTime(2026, 10, 12),
      icon: Icons.water_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengumuman RT')),
    body: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(child: Icon(item.icon)),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${item.body}\n\n${DateFormat('d MMMM yyyy', 'id_ID').format(item.date)}',
              ),
            ),
            isThreeLine: true,
          ),
        );
      },
    ),
  );
}

class _EmergencyContactsPage extends StatelessWidget {
  const _EmergencyContactsPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kontak penting')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: const ListTile(
            leading: Icon(Icons.warning_amber_rounded),
            title: Text(
              'Jika ada keadaan darurat yang mengancam keselamatan, hubungi layanan darurat setempat.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ContactTile(
          title: 'Layanan darurat nasional',
          subtitle: '112',
          phone: '112',
          icon: Icons.emergency_outlined,
        ),
        _ContactTile(
          title: 'Pos keamanan lingkungan',
          subtitle: 'Nomor demo: 021-555-0103',
          phone: '0215550103',
          icon: Icons.local_police_outlined,
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Nomor pengurus pada layar ini adalah contoh. Pastikan nomor layanan lokal benar sebelum digunakan.',
          ),
        ),
      ],
    ),
  );
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.title,
    required this.subtitle,
    required this.phone,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String phone;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: IconButton(
        tooltip: 'Telepon $title',
        icon: const Icon(Icons.call_outlined),
        onPressed: () async {
          final uri = Uri(scheme: 'tel', path: phone);
          try {
            if (await launchUrl(uri)) return;
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Aplikasi telepon tidak tersedia di perangkat ini.',
                ),
              ),
            );
          } catch (error) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Kontak tidak dapat dibuka: $error')),
            );
          }
        },
      ),
    ),
  );
}
