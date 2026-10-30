import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/confirm_dialog.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../models/user_model.dart';
import '../../services/submission_repository.dart';

class SubmitDataScreen extends ConsumerStatefulWidget {
  const SubmitDataScreen({required this.user, super.key});

  final UserModel user;

  @override
  ConsumerState<SubmitDataScreen> createState() => _SubmitDataScreenState();
}

class _SubmitDataScreenState extends ConsumerState<SubmitDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Kirim data?',
      message: 'Data akan disimpan di perangkat ini dengan status menunggu verifikasi admin.',
      confirmLabel: 'Kirim data',
    );
    if (!confirmed || !mounted) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(submissionRepositoryProvider)
          .submitData(
            user: widget.user,
            title: _title.text,
            description: _description.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data berhasil dikirim, menunggu verifikasi admin.'),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Data gagal disimpan: $error')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kirim data')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Sampaikan kebutuhan Anda',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Data tersimpan lokal di perangkat ini dan baru aktif setelah disetujui admin.',
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _title,
              label: 'Judul data',
              hint: 'Contoh: Permohonan surat pengantar',
              icon: Icons.short_text,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) =>
                  AppValidators.minLength(value, length: 3, label: 'Judul'),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _description,
              label: 'Keterangan',
              hint: 'Jelaskan informasi yang perlu diverifikasi.',
              minLines: 5,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => AppValidators.minLength(
                value,
                length: 8,
                label: 'Keterangan',
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              label: 'Kirim untuk verifikasi',
              icon: Icons.send_rounded,
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    ),
  );
}
