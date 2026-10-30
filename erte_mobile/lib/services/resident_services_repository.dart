import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'hive_service.dart';

class GuestVisit {
  const GuestVisit({
    required this.id,
    required this.name,
    required this.purpose,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String purpose;
  final DateTime createdAt;

  factory GuestVisit.fromJson(Map<String, dynamic> json) => GuestVisit(
    id: json['id'] as String,
    name: json['name'] as String,
    purpose: json['purpose'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'purpose': purpose,
    'createdAt': createdAt.toIso8601String(),
  };
}

class MonthlyDues {
  const MonthlyDues({
    required this.month,
    required this.amount,
    required this.isPaid,
  });

  final DateTime month;
  final int amount;
  final bool isPaid;
}

class ResidentServicesRepository {
  static const _monthlyDuesAmount = 25000;

  Future<String> storeLetterAttachment({
    required String userId,
    required String sourcePath,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw FileSystemException('File lampiran tidak ditemukan.', sourcePath);
    }
    final extension = sourcePath.split('.').last.toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'webp', 'pdf'}.contains(extension)) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'Lampiran harus berupa gambar atau PDF.',
      );
    }
    final directory = await getApplicationDocumentsDirectory();
    final attachmentDirectory = Directory(
      '${directory.path}/letter_attachments',
    );
    await attachmentDirectory.create(recursive: true);
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final destination =
        '${attachmentDirectory.path}/${safeUserId}_${DateTime.now().microsecondsSinceEpoch}.$extension';
    return (await file.copy(destination)).path;
  }

  List<MonthlyDues> getMonthlyDues(String userId, {DateTime? now}) {
    final currentDate = now ?? DateTime.now();
    final paidMonths = _readStringList('paidDues:$userId').toSet();
    return List.generate(6, (index) {
      final month = DateTime(currentDate.year, currentDate.month - index);
      final key = _monthKey(month);
      return MonthlyDues(
        month: month,
        amount: _monthlyDuesAmount,
        isPaid: paidMonths.contains(key),
      );
    });
  }

  Future<void> markDuesPaid(String userId, DateTime month) async {
    final key = 'paidDues:$userId';
    final paidMonths = _readStringList(key);
    final monthKey = _monthKey(month);
    if (paidMonths.contains(monthKey)) return;
    await HiveService.session.put(key, jsonEncode([...paidMonths, monthKey]));
  }

  List<GuestVisit> getGuestVisits(String userId) {
    final entries = _readMapList('guestVisits:$userId');
    final visits = entries.map(GuestVisit.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return visits;
  }

  Future<GuestVisit> registerGuest({
    required String userId,
    required String name,
    required String purpose,
  }) async {
    final normalizedName = name.trim();
    final normalizedPurpose = purpose.trim();
    if (normalizedName.length < 2) {
      throw ArgumentError.value(name, 'name', 'Nama tamu minimal 2 karakter.');
    }
    if (normalizedPurpose.length < 3) {
      throw ArgumentError.value(
        purpose,
        'purpose',
        'Tujuan kunjungan minimal 3 karakter.',
      );
    }
    final visit = GuestVisit(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: normalizedName,
      purpose: normalizedPurpose,
      createdAt: DateTime.now(),
    );
    final key = 'guestVisits:$userId';
    final entries = _readMapList(key);
    await HiveService.session.put(
      key,
      jsonEncode([visit.toJson(), ...entries]),
    );
    return visit;
  }

  List<String> _readStringList(String key) {
    final raw = HiveService.session.get(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw as String);
    if (decoded is! List) {
      throw FormatException('Data lokal "$key" tidak valid.');
    }
    return decoded.map((entry) => entry.toString()).toList();
  }

  List<Map<String, dynamic>> _readMapList(String key) {
    final raw = HiveService.session.get(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw as String);
    if (decoded is! List) {
      throw FormatException('Data lokal "$key" tidak valid.');
    }
    return decoded.map((entry) {
      if (entry is! Map) {
        throw FormatException('Data lokal "$key" tidak valid.');
      }
      return Map<String, dynamic>.from(entry);
    }).toList();
  }

  String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';
}
