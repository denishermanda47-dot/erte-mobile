import 'package:hive_ce/hive.dart';

import 'data_status.dart';

part 'data_model.g.dart';

@HiveType(typeId: 2)
class DataModel extends HiveObject {
  DataModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.description,
    required this.submittedAt,
    this.status = DataStatus.pending,
    this.verifiedAt,
    this.verifiedBy,
    this.rejectionReason,
    this.isFavorite = false,
    this.attachments = const [],
    this.letterNumber,
    this.isLetterRequest = false,
    this.applicantDetails = const {},
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String userName;

  @HiveField(3)
  final String title;

  @HiveField(4)
  final String description;

  @HiveField(5)
  final DateTime submittedAt;

  @HiveField(6)
  final DataStatus status;

  @HiveField(7)
  final DateTime? verifiedAt;

  @HiveField(8)
  final String? verifiedBy;

  @HiveField(9)
  final String? rejectionReason;

  @HiveField(10)
  final bool isFavorite;

  @HiveField(11)
  final List<String> attachments;

  @HiveField(12)
  final String? letterNumber;

  @HiveField(13)
  final bool isLetterRequest;

  @HiveField(14)
  final Map<String, String> applicantDetails;

  DataModel copyWith({
    DataStatus? status,
    DateTime? verifiedAt,
    String? verifiedBy,
    String? rejectionReason,
    bool? isFavorite,
    List<String>? attachments,
    String? letterNumber,
    bool? isLetterRequest,
    Map<String, String>? applicantDetails,
  }) => DataModel(
    id: id,
    userId: userId,
    userName: userName,
    title: title,
    description: description,
    submittedAt: submittedAt,
    status: status ?? this.status,
    verifiedAt: verifiedAt ?? this.verifiedAt,
    verifiedBy: verifiedBy ?? this.verifiedBy,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    isFavorite: isFavorite ?? this.isFavorite,
    attachments: attachments ?? this.attachments,
    letterNumber: letterNumber ?? this.letterNumber,
    isLetterRequest: isLetterRequest ?? this.isLetterRequest,
    applicantDetails: applicantDetails ?? this.applicantDetails,
  );
}
