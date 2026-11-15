import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/services/analytics/product_analytics.dart';
import '../../../../core/theme/dream_colors.dart';
import '../../../../shared/widgets/dream_display.dart';
import '../../../../shared/widgets/dream_spinner.dart';
import '../../models/dream_models.dart';
import '../../providers/dreams_providers.dart';
import '../widgets/dream_card.dart';

/// Dreams tab: a feed of real needs people can fund directly or back by
/// trading the dream's coin.
class DreamsTabPage extends ConsumerStatefulWidget {
  const DreamsTabPage({super.key});

  @override
  ConsumerState<DreamsTabPage> createState() => _DreamsTabPageState();
}

class _DreamsTabPageState extends ConsumerState<DreamsTabPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(ProductAnalytics.dreamsFeedViewed(DreamSort.latest.apiValue));
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) {
        ref.read(dreamsFeedProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;
    final feed = ref.watch(dreamsFeedProvider);
    final notifier = ref.read(dreamsFeedProvider.notifier);

    return Scaffold(
      backgroundColor: dc.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 8.h, 16.w, 4.h),
              child: Row(
                children: [
                  Text(
                    'Dreams',
                    style: TextStyle(
                      color: dc.onSurface,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/dreams/new');
                    },
                    icon: Icon(PhosphorIcons.plus(), size: 16.r),
                    label: const Text('Post a dream'),
                    style: TextButton.styleFrom(foregroundColor: dc.primary),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                children: [
                  for (final s in DreamSort.values)
                    Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: ChoiceChip(
                        label: Text(s.label),
                        selected: feed.sort == s,
                        onSelected: (_) => notifier.setSort(s),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: _CategoryMenu(
                      selected: feed.category,
                      onSelected: notifier.setCategory,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(child: _buildBody(context, feed, notifier)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DreamsFeedState feed,
    DreamsFeedNotifier notifier,
  ) {
    if (feed.isLoading && feed.dreams.isEmpty) {
      return const Center(child: DreamSpinner());
    }
    if (feed.error != null && feed.dreams.isEmpty) {
      return DreamEmptyState(
        icon: PhosphorIcons.cloudWarning(),
        title: 'Couldn’t load dreams',
        subtitle: feed.error,
        action: TextButton(
          onPressed: notifier.refresh,
          child: const Text('Try again'),
        ),
      );
    }
    if (feed.dreams.isEmpty) {
      return DreamEmptyState(
        icon: PhosphorIcons.moonStars(),
        title: 'No dreams here yet',
        subtitle:
            'Post what you need — rent, fees, a bill — and let people help.',
        action: TextButton(
          onPressed: () => context.push('/dreams/new'),
          child: const Text('Post the first one'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 4.h, bottom: 120.h),
        itemCount: feed.dreams.length + (feed.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= feed.dreams.length) {
            return Padding(
              padding: EdgeInsets.all(16.r),
              child: const Center(child: DreamSpinner()),
            );
          }
          final dream = feed.dreams[i];
          return DreamCard(
            dream: dream,
            onTap: () => context.push('/dreams/${dream.id}'),
          );
        },
      ),
    );
  }
}

class _CategoryMenu extends StatelessWidget {
  final DreamCategory? selected;
  final ValueChanged<DreamCategory?> onSelected;
  const _CategoryMenu({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DreamCategory?>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        const PopupMenuItem(value: null, child: Text('All categories')),
        for (final c in DreamCategory.values)
          PopupMenuItem(value: c, child: Text('${c.emoji}  ${c.label}')),
      ],
      child: Chip(
        label: Text(
          selected == null ? 'All' : '${selected!.emoji} ${selected!.label}',
        ),
        avatar: Icon(PhosphorIcons.funnel(), size: 14.r),
      ),
    );
  }
}
