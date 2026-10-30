import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import '../core/theme/app_colors.dart';

part 'data_status.g.dart';

@HiveType(typeId: 0)
enum DataStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  approved,
  @HiveField(2)
  rejected,
  @HiveField(3)
  processing,
  @HiveField(4)
  completed,
}

extension DataStatusPresentation on DataStatus {
  bool get isAwaitingReview =>
      this == DataStatus.pending || this == DataStatus.processing;

  String get label => switch (this) {
    DataStatus.pending => 'Menunggu',
    DataStatus.processing => 'Diproses',
    DataStatus.approved => 'Disetujui',
    DataStatus.completed => 'Selesai',
    DataStatus.rejected => 'Ditolak',
  };

  Color get color => switch (this) {
    DataStatus.pending => AppColors.warning,
    DataStatus.processing => AppColors.warning,
    DataStatus.approved => AppColors.success,
    DataStatus.completed => AppColors.success,
    DataStatus.rejected => AppColors.error,
  };

  IconData get icon => switch (this) {
    DataStatus.pending => Icons.schedule_rounded,
    DataStatus.processing => Icons.sync_rounded,
    DataStatus.approved => Icons.verified_rounded,
    DataStatus.completed => Icons.task_alt_rounded,
    DataStatus.rejected => Icons.cancel_rounded,
  };
}
