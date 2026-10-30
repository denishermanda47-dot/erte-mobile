import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/document_type.dart';
import '../screens/camera_screen.dart';
import '../screens/guidance_screen.dart';
import 'upload_card.dart';

/// Komponen upload dokumen lengkap: kartu → panduan → kamera → pratinjau.
///
/// Foto disimpan oleh pemanggil (state RegisterPage) hanya di memori,
/// jadi tidak hilang saat pengguna bolak-balik antar tahap, dan hilang saat
/// alur ditutup. Tidak ada penyimpanan ke galeri/disk dan tidak ada upload.
class DocumentCapture extends StatelessWidget {
  const DocumentCapture({
    super.key,
    required this.documentType,
    required this.photo,
    required this.onChanged,
  });

  final DocumentType documentType;
  final Uint8List? photo;
  final ValueChanged<Uint8List?> onChanged;

  Future<void> _startCapture(BuildContext context) async {
    final navigator = Navigator.of(context);

    // 1) Layar panduan sebelum kamera.
    final proceed = await navigator.push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GuidanceScreen(documentType: documentType),
      ),
    );
    if (proceed != true) return;

    // 2) Kamera live → pratinjau → "Gunakan Foto Ini" mengembalikan bytes.
    final bytes = await navigator.push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CameraScreen(documentType: documentType),
      ),
    );
    if (bytes != null) onChanged(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return UploadCard(
      documentType: documentType,
      photo: photo,
      onCapture: () => _startCapture(context),
      onRemove: () => onChanged(null),
    );
  }
}
