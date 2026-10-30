import 'package:flutter/material.dart';

import '../main.dart';
import '../models/document_type.dart';

/// Panduan singkat sebelum kamera dibuka.
/// Mengembalikan `true` bila pengguna lanjut, `false` bila dibatalkan.
class GuidanceScreen extends StatelessWidget {
  const GuidanceScreen({super.key, required this.documentType});
  final DocumentType documentType;

  static const _items = <(bool, String)>[
    (true, 'Dokumen terlihat utuh, tidak terpotong.'),
    (true, 'Teks terbaca jelas.'),
    (true, 'Pencahayaan cukup.'),
    (true, 'Tidak ada pantulan.'),
    (false, 'Jangan blur.'),
    (false, 'Jangan foto dari layar lain.'),
  ];

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Panduan Foto ${documentType.label}',
      subtitle: 'Perhatikan hal berikut agar dokumen mudah diverifikasi.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (ok, text) in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                label: ok ? 'Lakukan: $text' : 'Hindari: $text',
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        ok ? Icons.check_circle : Icons.cancel,
                        size: 22,
                        color: ok ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Mengerti, Mulai Kamera',
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Batal',
            variant: ButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
