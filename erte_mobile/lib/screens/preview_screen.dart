import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../main.dart';

/// Pratinjau hasil capture. Foto hanya ada di memori (tidak ke galeri).
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({
    super.key,
    required this.bytes,
    required this.title,
    required this.onUse,
    required this.onRetake,
    required this.onDiscard,
  });

  final Uint8List bytes;
  final String title;
  final VoidCallback onUse; // "Gunakan Foto Ini"
  final VoidCallback onRetake; // "Foto Ulang"
  final VoidCallback onDiscard; // "Hapus" (batal)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onDiscard,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hapus'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            // Bisa di-zoom untuk memeriksa teks terbaca.
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  semanticLabel: 'Hasil foto $title',
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(label: 'Gunakan Foto Ini', onPressed: onUse),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Foto Ulang',
                    variant: ButtonVariant.secondary,
                    onPressed: onRetake,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
