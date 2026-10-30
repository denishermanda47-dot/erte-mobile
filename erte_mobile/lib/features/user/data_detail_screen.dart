import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/status_badge.dart';
import '../../models/data_model.dart';
import '../../models/data_status.dart';
import '../../services/letter_pdf_service.dart';

class DataDetailScreen extends StatelessWidget {
  const DataDetailScreen({required this.data, super.key});

  final DataModel data;

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final bytes = await LetterPdfService.generate(data);
      final safeNumber = (data.letterNumber ?? 'surat').replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      final saved = await FilePicker.saveFile(
        fileName: 'surat_pengantar_$safeNumber.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        dialogTitle: 'Simpan surat pengantar',
        allowedExtensions: const ['pdf'],
      );
      if (saved != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF tersimpan: ${saved.path}')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat PDF: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail data')),
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
                        data.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    StatusBadge(status: data.status),
                  ],
                ),
                const SizedBox(height: 20),
                Text(data.description),
                const Divider(height: 32),
                if (data.letterNumber != null)
                  _DetailRow(label: 'Nomor surat', value: data.letterNumber!),
                if (data.attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Lampiran',
                    value: '${data.attachments.length} file persyaratan',
                  ),
                ],
                _DetailRow(
                  label: 'Dikirim',
                  value: DateFormat(
                    'd MMM yyyy, HH:mm',
                    'id_ID',
                  ).format(data.submittedAt),
                ),
                if (data.verifiedAt != null) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Diperiksa',
                    value: DateFormat(
                      'd MMM yyyy, HH:mm',
                      'id_ID',
                    ).format(data.verifiedAt!),
                  ),
                ],
                if (data.verifiedBy != null) ...[
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Diperiksa oleh', value: data.verifiedBy!),
                ],
                if (data.status == DataStatus.rejected) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alasan penolakan',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(data.rejectionReason ?? 'Tidak ada alasan.'),
                      ],
                    ),
                  ),
                  if (data.status == DataStatus.completed &&
                      data.isLetterRequest)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: FilledButton.icon(
                        onPressed: () => _downloadPdf(context),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Unduh surat PDF'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 125,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Expanded(child: Text(value)),
    ],
  );
}
