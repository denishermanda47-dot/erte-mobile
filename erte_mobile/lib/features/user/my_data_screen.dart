import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../core/widgets/status_badge.dart';
import '../../models/data_model.dart';
import '../../models/data_status.dart';
import '../../models/user_model.dart';
import '../../services/submission_repository.dart';
import 'data_detail_screen.dart';

class MyDataScreen extends ConsumerStatefulWidget {
  const MyDataScreen({required this.user, super.key});

  final UserModel user;

  @override
  ConsumerState<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends ConsumerState<MyDataScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  String _query = '';
  DataStatus? _status;
  bool _favoritesOnly = false;
  int _visibleCount = 10;
  int _filteredCount = 0;
  late final Stream<List<DataModel>> _dataStream = ref
      .read(submissionRepositoryProvider)
      .watchAll();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNearEnd);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_loadMoreWhenNearEnd)
      ..dispose();
    super.dispose();
  }

  void _loadMoreWhenNearEnd() {
    if (_visibleCount < _filteredCount &&
        _scrollController.position.extentAfter < 220) {
      setState(() => _visibleCount += 10);
    }
  }

  Future<void> _refresh() async {
    setState(() => _visibleCount = 10);
    ref.read(submissionRepositoryProvider).getMyData(widget.user.id);
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim().toLowerCase();
        _visibleCount = 10;
      });
    });
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
      final allItems = snapshot.data!
          .where((item) => item.userId == widget.user.id)
          .where((item) => _status == null || item.status == _status)
          .where((item) => !_favoritesOnly || item.isFavorite)
          .where(
            (item) =>
                _query.isEmpty ||
                item.title.toLowerCase().contains(_query) ||
                item.description.toLowerCase().contains(_query),
          )
          .toList();
      _filteredCount = allItems.length;
      final visibleItems = allItems.take(_visibleCount).toList();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Cari judul atau keterangan',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('Semua', null),
                      const SizedBox(width: 8),
                      _filterChip('Menunggu', DataStatus.pending),
                      const SizedBox(width: 8),
                      _filterChip('Diproses', DataStatus.processing),
                      const SizedBox(width: 8),
                      _filterChip('Disetujui', DataStatus.approved),
                      const SizedBox(width: 8),
                      _filterChip('Selesai', DataStatus.completed),
                      const SizedBox(width: 8),
                      _filterChip('Ditolak', DataStatus.rejected),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _favoritesOnly,
                        label: const Text('Favorit'),
                        avatar: const Icon(Icons.bookmark_outline, size: 18),
                        onSelected: (value) => setState(() {
                          _favoritesOnly = value;
                          _visibleCount = 10;
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: allItems.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 360,
                          child: EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'Belum ada data',
                            message: 'Data yang Anda kirim akan tersimpan dan ditampilkan di sini.',
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _SubmissionCard(data: visibleItems[index]),
                    ),
            ),
          ),
        ],
      );
    },
  );

  Widget _filterChip(String label, DataStatus? status) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _status == status,
      onSelected: (_) => setState(() {
        _status = status;
        _visibleCount = 10;
      }),
    ),
  );
}

class _SubmissionCard extends ConsumerWidget {
  const _SubmissionCard({required this.data});

  final DataModel data;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => DataDetailScreen(data: data)),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: data.isFavorite
                      ? 'Hapus dari favorit'
                      : 'Tambahkan ke favorit',
                  onPressed: () async {
                    try {
                      await ref
                          .read(submissionRepositoryProvider)
                          .toggleFavorite(data.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              data.isFavorite
                                  ? 'Dihapus dari favorit.'
                                  : 'Ditambahkan ke favorit.',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Favorit gagal diperbarui: $error'),
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(
                    data.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  ),
                ),
              ],
            ),
            Text(
              data.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat(
                      'd MMM yyyy, HH:mm',
                      'id_ID',
                    ).format(data.submittedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                StatusBadge(status: data.status),
              ],
            ),
            if (data.status == DataStatus.rejected &&
                data.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Alasan: ${data.rejectionReason}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
