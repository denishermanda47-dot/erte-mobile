import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/document_type.dart';

/// Kartu upload: placeholder "Belum ada foto" atau pratinjau foto hasil capture.
/// Foto hanya berupa bytes di memori (state lokal), tidak dikirim ke mana pun.
class UploadCard extends StatelessWidget {
  const UploadCard({
    super.key,
    required this.documentType,
    required this.photo,
    required this.onCapture,
    required this.onRemove,
  });

  final DocumentType documentType;
  final Uint8List? photo;
  final VoidCallback onCapture;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo != null;
    final label = documentType.label;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPhoto ? AppColors.success : AppColors.border,
          width: hasPhoto ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Foto $label',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (hasPhoto)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 4),
                    // "Foto siap", bukan "terunggah": belum dikirim ke mana pun.
                    Text(
                      'Foto siap',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: documentType.aspect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: AppColors.lightBg,
                alignment: Alignment.center,
                child: hasPhoto
                    ? Image.memory(
                        photo!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        semanticLabel: 'Pratinjau foto $label',
                      )
                    : const _Placeholder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: hasPhoto ? 'Ganti Foto' : 'Ambil Foto',
            onPressed: onCapture,
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 8),
            AppButton(
              label: 'Hapus',
              variant: ButtonVariant.secondary,
              onPressed: onRemove,
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Gunakan pencahayaan cukup, hindari pantulan cahaya.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 56,
              color: Color(0xFF93C5FD),
            ),
            SizedBox(height: 8),
            Text(
              'Belum ada foto',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Pastikan dokumen terlihat utuh dan terbaca',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
