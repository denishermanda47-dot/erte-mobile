import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/resident_profile.dart';
import '../models/user_model.dart';
import 'hive_service.dart';

final residentProfileRepositoryProvider = Provider<ResidentProfileRepository>(
  (ref) => ResidentProfileRepository(),
);

class ResidentRecord {
  const ResidentRecord({required this.user, required this.profile});

  final UserModel user;
  final ResidentProfile profile;
}

class ResidentProfileRepository {
  ResidentProfile? getProfile(String userId) {
    final raw = HiveService.session.get(_profileKey(userId));
    if (raw == null) return null;
    final decoded = jsonDecode(raw as String);
    if (decoded is! Map) {
      throw FormatException('Data profil warga "$userId" tidak valid.');
    }
    return ResidentProfile.fromJson(Map<String, dynamic>.from(decoded));
  }

  List<ResidentProfile> getAllProfiles() => HiveService.users.values
      .map((user) => getProfile(user.id))
      .whereType<ResidentProfile>()
      .toList();

  List<ResidentRecord> getAllResidents() =>
      HiveService.users.values
          .where((user) => !user.isAdmin)
          .map((user) {
            final profile = getProfile(user.id);
            return profile == null
                ? null
                : ResidentRecord(user: user, profile: profile);
          })
          .whereType<ResidentRecord>()
          .toList()
        ..sort((a, b) => a.profile.fullName.compareTo(b.profile.fullName));

  Stream<List<ResidentRecord>> watchResidents() async* {
    yield getAllResidents();
    await for (final _ in HiveService.session.watch()) {
      yield getAllResidents();
    }
  }

  Future<void> saveProfile(String userId, ResidentProfile profile) async {
    _validateProfile(profile);
    final duplicate = HiveService.users.values.any((user) {
      if (user.id == userId) return false;
      return getProfile(user.id)?.nik == profile.nik;
    });
    if (duplicate) {
      throw ArgumentError.value(profile.nik, 'nik', 'NIK sudah terdaftar.');
    }
    await HiveService.session.put(
      _profileKey(userId),
      jsonEncode(profile.toJson()),
    );
  }

  void _validateProfile(ResidentProfile profile) {
    if (!RegExp(r'^\d{16}$').hasMatch(profile.nik)) {
      throw ArgumentError.value(profile.nik, 'nik', 'NIK harus 16 digit.');
    }
    if (!RegExp(r'^\d{16}$').hasMatch(profile.familyCardNumber)) {
      throw ArgumentError.value(
        profile.familyCardNumber,
        'familyCardNumber',
        'Nomor KK harus 16 digit.',
      );
    }
    if (profile.fullName.trim().length < 3) {
      throw ArgumentError.value(
        profile.fullName,
        'fullName',
        'Nama minimal 3 karakter.',
      );
    }
    if (!RegExp(r'^08\d{8,11}$').hasMatch(profile.phoneNumber)) {
      throw ArgumentError.value(
        profile.phoneNumber,
        'phoneNumber',
        'Nomor HP harus berformat 08xx dan berisi 10-13 digit.',
      );
    }
    if (profile.birthDate.isAfter(DateTime.now())) {
      throw ArgumentError.value(
        profile.birthDate,
        'birthDate',
        'Tanggal lahir tidak boleh di masa depan.',
      );
    }
    final requiredValues = [
      profile.birthPlace,
      profile.gender,
      profile.religion,
      profile.maritalStatus,
      profile.occupation,
      profile.address,
      profile.rt,
      profile.rw,
      profile.familyRelationship,
      profile.ktpPhotoPath,
      profile.familyCardPhotoPath,
    ];
    if (requiredValues.any((value) => value.trim().isEmpty)) {
      throw ArgumentError('Semua data warga dan foto KTP/KK wajib diisi.');
    }
  }

  Future<String> storeDocument({required XFile file}) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw ArgumentError.value(file.name, 'file', 'File dokumen kosong.');
    }
    final mimeType = _imageMimeType(file);
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  String _imageMimeType(XFile file) {
    final mimeType = file.mimeType;
    if (mimeType != null && mimeType.startsWith('image/')) return mimeType;

    final extension = file.name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'bmp' => 'image/bmp',
      _ => throw FormatException(
        'Format gambar "${file.name}" tidak didukung.',
      ),
    };
  }

  String _profileKey(String userId) => 'residentProfile:$userId';
}
