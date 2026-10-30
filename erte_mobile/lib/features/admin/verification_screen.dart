import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../core/widgets/status_badge.dart';
import '../../models/data_model.dart';
import '../../models/data_status.dart';
import '../../services/submission_repository.dart';
import 'verification_detail_screen.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  DataStatus? _status;
  late final Stream<List<DataModel>> _dataStream = ref
      .read(submissionRepositoryProvider)
      .watchAll();

  Future<void> _refresh() async {
    ref.read(submissionRepositoryProvider).getAllData();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<DataModel>>(
    stream: _dataStream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('Gagal membaca data lokal: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const LoadingSkeleton();
      }
      final allItems = snapshot.data!;
      final items = _status == null
          ? allItems
          : allItems.where((item) => item.status == _status).toList();
      return Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _chip('Semua', null, allItems.length),
                _chip(
                  'Menunggu',
                  DataStatus.pending,
                  allItems
                      .where((item) => item.status == DataStatus.pending)
                      .length,
                ),
                _chip(
                  'Diproses',
                  DataStatus.processing,
                  allItems
                      .where((item) => item.status == DataStatus.processing)
                      .length,
                ),
                _chip(
                  'Disetujui',
                  DataStatus.approved,
                  allItems
                      .where((item) => item.status == DataStatus.approved)
                      .length,
                ),
                _chip(
                  'Selesai',
                  DataStatus.completed,
                  allItems
                      .where((item) => item.status == DataStatus.completed)
                      .length,
                ),
                _chip(
                  'Ditolak',
                  DataStatus.rejected,
                  allItems
                      .where((item) => item.status == DataStatus.rejected)
                      .length,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 360,
                          child: EmptyState(
                            icon: Icons.task_alt_rounded,
                            title: _status == DataStatus.pending
                                ? 'Tidak ada pengajuan menunggu'
                                : 'Belum ada pengajuan',
                            message:
                                'Data yang dikirim warga akan muncul otomatis di sini.',
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _VerificationCard(data: items[index]),
                    ),
            ),
          ),
        ],
      );
    },
  );

  Widget _chip(String label, DataStatus? status, int count) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text('$label ($count)'),
      selected: _status == status,
      onSelected: (_) => setState(() => _status = status),
    ),
  );
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.data});

  final DataModel data;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => VerificationDetailScreen(data: data),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusBadge(status: data.status),
              ],
            ),
            const SizedBox(height: 6),
            Text('Dari ${data.userName}'),
            const SizedBox(height: 4),
            Text(
              DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(data.submittedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(
              data.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (data.status == DataStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.touch_app_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Ketuk untuk memeriksa dan memberi keputusan',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
