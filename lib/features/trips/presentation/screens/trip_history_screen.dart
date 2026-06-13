import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/extensions/date_extensions.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../../../shared/utils/money.dart';
import '../../data/models/trip.dart';
import '../controllers/trip_history_controller.dart';

/// Paginated trip history, newest first. Tapping a trip opens its detail. Scroll
/// to the bottom to load the next page.
class TripHistoryScreen extends ConsumerStatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  ConsumerState<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends ConsumerState<TripHistoryScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      ref.read(tripHistoryControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tripHistoryControllerProvider);
    final controller = ref.read(tripHistoryControllerProvider.notifier);

    return AppScaffold(
      title: 'Trip history',
      padded: false,
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
          message: messageForError(e),
          onRetry: controller.refresh,
        ),
        data: (state) {
          if (state.trips.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No trips yet',
              message: 'Completed trips will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.separated(
              controller: _scroll,
              padding: AppSpacing.screen,
              itemCount: state.trips.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index >= state.trips.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _TripTile(trip: state.trips[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => context.push('/trips/${trip.publicId}'),
        title: Text(
          trip.drop.display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(trip.createdAt.toFriendly()),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatPaise(trip.displayFare),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            StatusBadge(label: trip.status.label, tone: trip.status.tone),
          ],
        ),
      ),
    );
  }
}
