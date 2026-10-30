import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/data_model.dart';
import '../models/data_status.dart';
import '../models/user_model.dart';
import 'hive_service.dart';

final submissionRepositoryProvider = Provider<SubmissionRepository>(
  (ref) => SubmissionRepository(HiveService.submissions, HiveService.session),
);

class SubmissionRepository {
  SubmissionRepository(this._submissions, this._session);

  final Box<DataModel> _submissions;
  final Box<dynamic> _session;
  static const _uuid = Uuid();

  Future<DataModel> submitData({
    required UserModel user,
    required String title,
    required String description,
    List<String> attachments = const [],
    bool isLetterRequest = false,
    Map<String, String> applicantDetails = const {},
  }) async {
    _requireSignedInUser(user);
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    if (normalizedTitle.length < 3) {
      throw ArgumentError.value(title, 'title', 'Judul minimal 3 karakter.');
    }
    if (normalizedDescription.length < 8) {
      throw ArgumentError.value(
        description,
        'description',
        'Keterangan minimal 8 karakter.',
      );
    }
    if (attachments.length > 3) {
      throw ArgumentError.value(
        attachments.length,
        'attachments',
        'Maksimal 3 lampiran diperbolehkan.',
      );
    }
    final submission = DataModel(
      id: _uuid.v4(),
      userId: user.id,
      userName: user.name,
      title: normalizedTitle,
      description: normalizedDescription,
      submittedAt: DateTime.now(),
      attachments: List.unmodifiable(attachments),
      isLetterRequest: isLetterRequest,
      applicantDetails: Map.unmodifiable(applicantDetails),
    );
    await _submissions.put(submission.id, submission);
    return submission;
  }

  List<DataModel> getMyData(String userId) =>
      _sorted(_submissions.values.where((item) => item.userId == userId));

  List<DataModel> getAllData() => _sorted(_submissions.values);

  List<DataModel> getPendingData() => _sorted(
    _submissions.values.where((item) => item.status.isAwaitingReview),
  );

  Stream<List<DataModel>> watchAll() async* {
    yield getAllData();
    await for (final _ in _submissions.watch()) {
      yield getAllData();
    }
  }

  Stream<List<DataModel>> watchPending() async* {
    yield getPendingData();
    await for (final _ in _submissions.watch()) {
      yield getPendingData();
    }
  }

  Future<void> approveData(String id, String adminName) async {
    _requireAdmin(adminName);
    final item = _pendingItem(id);
    String? letterNumber;
    if (item.isLetterRequest) {
      final year = DateTime.now().year;
      final counterKey = 'letterCounter:$year';
      final nextNumber = (_session.get(counterKey) as int? ?? 0) + 1;
      await _session.put(counterKey, nextNumber);
      letterNumber = '${nextNumber.toString().padLeft(3, '0')}/RT-RW/$year';
    }
    await _submissions.put(
      id,
      item.copyWith(
        status: DataStatus.approved,
        verifiedAt: DateTime.now(),
        verifiedBy: adminName,
        letterNumber: letterNumber,
      ),
    );
  }

  Future<void> startProcessing(String id, String adminName) async {
    _requireAdmin(adminName);
    final item = _pendingItem(id);
    await _submissions.put(
      id,
      item.copyWith(
        status: DataStatus.processing,
        verifiedAt: DateTime.now(),
        verifiedBy: adminName,
      ),
    );
  }

  Future<void> completeData(String id, String adminName) async {
    _requireAdmin(adminName);
    final item = _submissions.get(id);
    if (item == null) throw StateError('Data tidak ditemukan.');
    if (item.status != DataStatus.approved) {
      throw StateError('Hanya surat yang disetujui dapat diselesaikan.');
    }
    await _submissions.put(
      id,
      item.copyWith(
        status: DataStatus.completed,
        verifiedAt: DateTime.now(),
        verifiedBy: adminName,
      ),
    );
  }

  Future<void> rejectData(String id, String adminName, String reason) async {
    _requireAdmin(adminName);
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Alasan penolakan wajib diisi.',
      );
    }
    final item = _pendingItem(id);
    await _submissions.put(
      id,
      item.copyWith(
        status: DataStatus.rejected,
        verifiedAt: DateTime.now(),
        verifiedBy: adminName,
        rejectionReason: normalizedReason,
      ),
    );
  }

  Future<void> toggleFavorite(String id) async {
    final item = _submissions.get(id);
    if (item == null) throw StateError('Data tidak ditemukan.');
    await _submissions.put(id, item.copyWith(isFavorite: !item.isFavorite));
  }

  List<DataModel> getUnseenReviews(String userId) {
    final lastSeenMillis =
        _session.get('lastReviewSeenAt:$userId') as int? ?? 0;
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenMillis);
    return getMyData(userId)
        .where(
          (item) =>
              !item.status.isAwaitingReview &&
              item.verifiedAt != null &&
              item.verifiedAt!.isAfter(lastSeen),
        )
        .toList();
  }

  Future<void> markReviewsSeen(String userId) => _session.put(
    'lastReviewSeenAt:$userId',
    DateTime.now().millisecondsSinceEpoch,
  );

  DataModel _pendingItem(String id) {
    final item = _submissions.get(id);
    if (item == null) throw StateError('Data tidak ditemukan.');
    if (item.status != DataStatus.pending &&
        item.status != DataStatus.processing) {
      throw StateError('Data ini sudah diverifikasi sebelumnya.');
    }
    return item;
  }

  void _requireSignedInUser(UserModel user) {
    if (user.isAdmin) {
      throw StateError('Masuk sebagai warga untuk mengirim data.');
    }
  }

  void _requireAdmin(String adminName) {
    final currentUserId = _session.get('currentUserId') as String?;
    final currentUser = currentUserId == null
        ? null
        : HiveService.users.get(currentUserId);
    if (currentUser == null ||
        !currentUser.isAdmin ||
        currentUser.name != adminName) {
      throw StateError(
        'Hanya admin yang sedang masuk dapat memverifikasi data.',
      );
    }
  }

  List<DataModel> _sorted(Iterable<DataModel> items) =>
      items.toList()..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
}
