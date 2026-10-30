import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/resident_profile_repository.dart';

class ResidentDirectoryScreen extends ConsumerWidget {
  const ResidentDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => StreamBuilder(
    stream: ref.read(residentProfileRepositoryProvider).watchResidents(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('Gagal membaca data warga: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final residents = snapshot.data!;
      if (residents.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Belum ada data warga yang dilengkapi.'),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: residents.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final record = residents[index];
          final profile = record.profile;
          return Card(
            child: ExpansionTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(
                profile.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('NIK ${profile.nik} · ${profile.phoneNumber}'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _detail('No. KK', profile.familyCardNumber),
                _detail(
                  'Tempat, tanggal lahir',
                  '${profile.birthPlace}, ${profile.birthDate.day}/${profile.birthDate.month}/${profile.birthDate.year}',
                ),
                _detail('Jenis kelamin', profile.gender),
                _detail('Agama', profile.religion),
                _detail('Status perkawinan', profile.maritalStatus),
                _detail('Pekerjaan', profile.occupation),
                _detail('Hubungan keluarga', profile.familyRelationship),
                _detail('Alamat', profile.address),
                _detail('RT/RW', '${profile.rt}/${profile.rw}'),
                _detail('Akun', record.user.username),
                _documentTile(context, 'Foto KTP', profile.ktpPhotoPath),
                _documentTile(
                  context,
                  'Foto Kartu Keluarga',
                  profile.familyCardPhotoPath,
                ),
              ],
            ),
          );
        },
      );
    },
  );

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  Widget _documentTile(BuildContext context, String label, String path) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.image_outlined),
        title: Text(label),
        subtitle: const Text('Ketuk untuk melihat dokumen'),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  const SizedBox(height: 12),
                  Flexible(
                    child:
                        path.startsWith('data:image/') &&
                            path.contains(';base64,')
                        ? Image.memory(
                            base64Decode(path.substring(path.indexOf(',') + 1)),
                            errorBuilder: (context, error, stackTrace) =>
                                const Text('Dokumen tidak dapat dibuka.'),
                          )
                        : Image.file(
                            File(path),
                            errorBuilder: (context, error, stackTrace) =>
                                const Text('Dokumen tidak dapat dibuka.'),
                          ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
