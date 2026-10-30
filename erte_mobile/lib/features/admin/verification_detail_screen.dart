import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/status_badge.dart';
import '../../models/data_model.dart';
import '../../models/data_status.dart';
import '../../providers/auth_provider.dart';
import '../../services/submission_repository.dart';

class VerificationDetailScreen extends ConsumerStatefulWidget {
  const VerificationDetailScreen({required this.data, super.key});

  final DataModel data;

  @override
  ConsumerState<VerificationDetailScreen> createState() =>
      _VerificationDetailScreenState();
}

class _VerificationDetailScreenState
    extends ConsumerState<VerificationDetailScreen> {
  bool _processing = false;

  Future<void> _approve() async {
    final admin = ref.read(authControllerProvider).valueOrNull;
    if (admin == null) return;
    setState(() => _processing = true);
    try {
      await ref
          .read(submissionRepositoryProvider)
          .approveData(widget.data.id, admin.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil disetujui.')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Persetujuan gagal: $error')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _startProcessing() async {
    final admin = ref.read(authControllerProvider).valueOrNull;
    if (admin == null) return;
    setState(() => _processing = true);
    try {
      await ref
          .read(submissionRepositoryProvider)
          .startProcessing(widget.data.id, admin.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan mulai diproses.')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses pengajuan: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _complete() async {
    final admin = ref.read(authControllerProvider).valueOrNull;
    if (admin == null) return;
    setState(() => _processing = true);
    try {
      await ref
          .read(submissionRepositoryProvider)
          .completeData(widget.data.id, admin.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan ditandai selesai.')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan pengajuan: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tolak pengajuan'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonController,
            minLines: 2,
            maxLines: 5,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Alasan penolakan',
              hintText: 'Jelaskan data yang perlu diperbaiki.',
              alignLabelWithHint: true,
            ),
            validator: (value) =>
                value?.trim().isNotEmpty == true ? null : 'Alasan wajib diisi.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, reasonController.text.trim());
              }
            },
            child: const Text('Tolak data'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;
    final admin = ref.read(authControllerProvider).valueOrNull;
    if (admin == null) return;
    setState(() => _processing = true);
    try {
      await ref
          .read(submissionRepositoryProvider)
          .rejectData(widget.data.id, admin.name, reason);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Data berhasil ditolak.')));
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Penolakan gagal: $error')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _openAttachment(String path) async {
    final uri = Uri.file(path);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka lampiran: $path')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail verifikasi')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.data.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    StatusBadge(status: widget.data.status),
                  ],
                ),
                const SizedBox(height: 20),
                Text(widget.data.description),
                const Divider(height: 32),
                _Info(label: 'Nama warga', value: widget.data.userName),
                if (widget.data.letterNumber != null)
                  _Info(label: 'Nomor surat', value: widget.data.letterNumber!),
                ...widget.data.applicantDetails.entries.map(
                  (entry) => _Info(label: entry.key, value: entry.value),
                ),
                if (widget.data.attachments.isNotEmpty)
                  ...widget.data.attachments.asMap().entries.map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.attach_file),
                      title: Text('Lampiran ${entry.key + 1}'),
                      subtitle: Text(
                        entry.value.split(RegExp(r'[/\\]')).last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openAttachment(entry.value),
                    ),
                  ),
                _Info(
                  label: 'Tanggal kirim',
                  value: DateFormat(
                    'd MMM yyyy, HH:mm',
                    'id_ID',
                  ).format(widget.data.submittedAt),
                ),
                if (widget.data.rejectionReason != null)
                  _Info(
                    label: 'Alasan penolakan',
                    value: widget.data.rejectionReason!,
                  ),
              ],
            ),
          ),
        ),
        if (widget.data.status == DataStatus.pending) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _reject,
                  icon: const Icon(Icons.close),
                  label: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _processing ? null : _startProcessing,
                  icon: const Icon(Icons.sync),
                  label: const Text('Mulai proses'),
                ),
              ),
            ],
          ),
        ],
        if (widget.data.status == DataStatus.processing) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _reject,
                  icon: const Icon(Icons.close),
                  label: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _processing ? null : _approve,
                  icon: _processing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Setujui'),
                ),
              ),
            ],
          ),
        ],
        if (widget.data.status == DataStatus.approved) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _processing ? null : _complete,
            icon: const Icon(Icons.task_alt),
            label: const Text('Tandai selesai'),
          ),
        ],
      ],
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
