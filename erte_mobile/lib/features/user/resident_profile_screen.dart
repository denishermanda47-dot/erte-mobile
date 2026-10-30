import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/utils/validators.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../models/resident_profile.dart';
import '../../models/user_model.dart';
import '../../providers/resident_occupation_provider.dart';
import '../../services/resident_profile_repository.dart';

class ResidentProfileScreen extends ConsumerStatefulWidget {
  const ResidentProfileScreen({required this.user, super.key});

  final UserModel user;

  @override
  ConsumerState<ResidentProfileScreen> createState() =>
      _ResidentProfileScreenState();
}

class _ResidentProfileScreenState extends ConsumerState<ResidentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _nik = TextEditingController();
  final _familyCard = TextEditingController();
  final _name = TextEditingController();
  final _birthPlace = TextEditingController();
  final _address = TextEditingController();
  final _rt = TextEditingController();
  final _rw = TextEditingController();
  final _phone = TextEditingController();
  String? _gender;
  String? _religion;
  String? _maritalStatus;
  String? _familyRelationship;
  DateTime? _birthDate;
  String? _ktpPath;
  String? _familyCardPath;
  bool _loading = true;
  bool _saving = false;

  static const _religions = [
    'Islam',
    'Kristen',
    'Katolik',
    'Hindu',
    'Buddha',
    'Konghucu',
    'Lainnya',
  ];
  static const _maritalStatuses = [
    'Belum kawin',
    'Kawin',
    'Cerai hidup',
    'Cerai mati',
  ];
  static const _familyRelationships = [
    'Kepala Keluarga',
    'Istri',
    'Anak',
    'Orang Tua',
    'Famili lain',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nik.dispose();
    _familyCard.dispose();
    _name.dispose();
    _birthPlace.dispose();
    _address.dispose();
    _rt.dispose();
    _rw.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _loadProfile() {
    final profile = ref
        .read(residentProfileRepositoryProvider)
        .getProfile(widget.user.id);
    if (profile != null) {
      _nik.text = profile.nik;
      _familyCard.text = profile.familyCardNumber;
      _name.text = profile.fullName;
      _birthPlace.text = profile.birthPlace;
      if (residentOccupationOptions.contains(profile.occupation)) {
        ref.read(residentOccupationProvider(widget.user.id).notifier).state =
            profile.occupation;
      }
      _address.text = profile.address;
      _rt.text = profile.rt;
      _rw.text = profile.rw;
      _phone.text = profile.phoneNumber;
      _gender = profile.gender;
      _religion = profile.religion;
      _maritalStatus = profile.maritalStatus;
      _familyRelationship = profile.familyRelationship;
      _birthDate = profile.birthDate;
      _ktpPath = profile.ktpPhotoPath;
      _familyCardPath = profile.familyCardPhotoPath;
    } else {
      _name.text = widget.user.name;
      _nik.text = widget.user.nik ?? '';
      _familyCard.text = widget.user.familyCardNumber ?? '';
      _address.text = widget.user.address ?? '';
      _phone.text = widget.user.phoneNumber ?? '';
    }
    _loading = false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Data warga')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Lengkapi data sesuai KTP dan Kartu Keluarga.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                _sectionTitle(context, 'Identitas'),
                CustomTextField(
                  controller: _nik,
                  label: 'NIK (16 digit)',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      _validateDigits(value, label: 'NIK', length: 16),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _familyCard,
                  label: 'Nomor Kartu Keluarga (16 digit)',
                  icon: Icons.groups_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      _validateDigits(value, label: 'Nomor KK', length: 16),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _name,
                  label: 'Nama lengkap',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      AppValidators.minLength(value, length: 3, label: 'Nama'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _birthPlace,
                        label: 'Tempat lahir',
                        icon: Icons.location_city_outlined,
                        validator: (value) => AppValidators.required(
                          value,
                          label: 'Tempat lahir',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectBirthDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          _birthDate == null
                              ? 'Tanggal lahir'
                              : DateFormat('dd/MM/yyyy').format(_birthDate!),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_birthDate == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text(
                      'Tanggal lahir wajib dipilih.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 14),
                _dropdown(
                  label: 'Jenis kelamin',
                  value: _gender,
                  values: const ['Laki-laki', 'Perempuan'],
                  onChanged: (value) => setState(() => _gender = value),
                ),
                const SizedBox(height: 14),
                _dropdown(
                  label: 'Agama',
                  value: _religion,
                  values: _religions,
                  onChanged: (value) => setState(() => _religion = value),
                ),
                const SizedBox(height: 14),
                _dropdown(
                  label: 'Status perkawinan',
                  value: _maritalStatus,
                  values: _maritalStatuses,
                  onChanged: (value) => setState(() => _maritalStatus = value),
                ),
                const SizedBox(height: 14),
                _occupationDropdown(),
                const SizedBox(height: 14),
                _dropdown(
                  label: 'Hubungan dalam keluarga',
                  value: _familyRelationship,
                  values: _familyRelationships,
                  onChanged: (value) =>
                      setState(() => _familyRelationship = value),
                ),
                const SizedBox(height: 24),
                _sectionTitle(context, 'Alamat dan kontak'),
                CustomTextField(
                  controller: _address,
                  label: 'Alamat lengkap',
                  icon: Icons.home_outlined,
                  minLines: 2,
                  maxLines: 3,
                  validator: (value) => AppValidators.minLength(
                    value,
                    length: 8,
                    label: 'Alamat',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _rt,
                        label: 'RT',
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            AppValidators.required(value, label: 'RT'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        controller: _rw,
                        label: 'RW',
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            AppValidators.required(value, label: 'RW'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _phone,
                  label: 'Nomor HP (08xx)',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
                const SizedBox(height: 24),
                _sectionTitle(context, 'Dokumen wajib'),
                _documentPicker(
                  label: 'Foto KTP',
                  path: _ktpPath,
                  onPressed: () => _pickDocument('ktp'),
                ),
                const SizedBox(height: 10),
                _documentPicker(
                  label: 'Foto Kartu Keluarga',
                  path: _familyCardPath,
                  onPressed: () => _pickDocument('kk'),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  label: 'Simpan data warga',
                  icon: Icons.save_outlined,
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
  );

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _occupationDropdown() {
    final occupation = ref.watch(residentOccupationProvider(widget.user.id));
    return DropdownButtonFormField<String>(
      initialValue: occupation,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Pekerjaan',
        hintText: 'Pilih Pekerjaan',
        prefixIcon: Icon(Icons.work_outline),
      ),
      items: residentOccupationOptions
          .map(
            (option) =>
                DropdownMenuItem<String>(value: option, child: Text(option)),
          )
          .toList(),
      validator: (value) => value == null ? 'Pekerjaan wajib dipilih' : null,
      onChanged: (value) {
        ref.read(residentOccupationProvider(widget.user.id).notifier).state =
            value;
      },
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: values
        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
        .toList(),
    validator: (selected) => selected == null ? '$label wajib dipilih.' : null,
    onChanged: onChanged,
  );

  Widget _documentPicker({
    required String label,
    required String? path,
    required VoidCallback onPressed,
  }) => Card(
    child: ListTile(
      leading: const Icon(Icons.document_scanner_outlined),
      title: Text(label),
      subtitle: Text(path == null ? 'Belum diunggah' : 'Dokumen tersimpan'),
      trailing: IconButton(
        tooltip: 'Pilih $label',
        onPressed: onPressed,
        icon: const Icon(Icons.upload_file_outlined),
      ),
    ),
  );

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickDocument(String kind) async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      final path = await ref
          .read(residentProfileRepositoryProvider)
          .storeDocument(file: image);
      if (!mounted) return;
      setState(() {
        if (kind == 'ktp') {
          _ktpPath = path;
        } else {
          _familyCardPath = path;
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih dokumen: $error')),
        );
      }
    }
  }

  String? _validateDigits(
    String? value, {
    required String label,
    required int length,
  }) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d+$').hasMatch(text) || text.length != length) {
      return '$label harus berupa $length digit angka.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^08\d{8,11}$').hasMatch(text)) {
      return 'Nomor HP harus berformat 08xx dan berisi 10-13 digit.';
    }
    return null;
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    if (!valid || _birthDate == null) return;
    if (_ktpPath == null || _familyCardPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto KTP dan KK wajib diunggah.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = ResidentProfile(
        nik: _nik.text.trim(),
        familyCardNumber: _familyCard.text.trim(),
        fullName: _name.text.trim(),
        birthPlace: _birthPlace.text.trim(),
        birthDate: _birthDate!,
        gender: _gender!,
        religion: _religion!,
        maritalStatus: _maritalStatus!,
        occupation: ref.read(residentOccupationProvider(widget.user.id))!,
        address: _address.text.trim(),
        rt: _rt.text.trim(),
        rw: _rw.text.trim(),
        phoneNumber: _phone.text.trim(),
        familyRelationship: _familyRelationship!,
        ktpPhotoPath: _ktpPath!,
        familyCardPhotoPath: _familyCardPath!,
      );
      await ref
          .read(residentProfileRepositoryProvider)
          .saveProfile(widget.user.id, profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data warga berhasil disimpan di perangkat.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan data warga: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
