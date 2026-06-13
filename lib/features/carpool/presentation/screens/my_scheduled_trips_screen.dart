import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/failure_snackbar.dart';
import '../../data/models/carpool_enums.dart';
import '../controllers/my_trips_controller.dart';
import '../widgets/scheduled_trip_card.dart';

/// The driver's posted carpool trips, with a status filter and a "post a trip"
/// action. Tapping a trip opens its detail + bookings.
class MyScheduledTripsScreen extends ConsumerStatefulWidget {
  const MyScheduledTripsScreen({super.key});

  @override
  ConsumerState<MyScheduledTripsScreen> createState() =>
      _MyScheduledTripsScreenState();
}

class _MyScheduledTripsScreenState
    extends ConsumerState<MyScheduledTripsScreen> {
  final _scroll = ScrollController();

  static const _filters = <(String, ScheduledTripStatus?)>[
    ('All', null),
    ('Open', ScheduledTripStatus.open),
    ('In progress', ScheduledTripStatus.inProgress),
    ('Completed', ScheduledTripStatus.completed),
    ('Cancelled', ScheduledTripStatus.cancelled),
  ];

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
      ref.read(myTripsControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myTripsControllerProvider);
    final controller = ref.read(myTripsControllerProvider.notifier);
    final activeFilter = async.value?.filter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carpool trips'),
        actions: [
          IconButton(
            tooltip: 'Chats',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push(Routes.chats),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final posted = await context.push<bool>(Routes.postScheduledTrip);
          if (posted == true) unawaited(controller.refresh());
        },
        icon: const Icon(Icons.add),
        label: const Text('Post a trip'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.screenH,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final (label, status) = _filters[i];
                return Center(
                  child: ChoiceChip(
                    label: Text(label),
                    selected: activeFilter == status,
                    onSelected: (_) => controller.setFilter(status),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(),
              error: (e, _) => ErrorState(
                message: messageForError(e),
                onRetry: controller.refresh,
              ),
              data: (state) {
                if (state.trips.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_available,
                    title: 'No carpool trips',
                    message: 'Post a scheduled trip and riders can book seats.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: ListView.separated(
                    controller: _scroll,
                    padding: AppSpacing.screen,
                    itemCount: state.trips.length + (state.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index >= state.trips.length) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final trip = state.trips[index];
                      return ScheduledTripCard(
                        trip: trip,
                        onTap: () => context.push('/carpool/${trip.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
