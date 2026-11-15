import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/dream_colors.dart';
import '../../../../shared/widgets/dream_display.dart';
import '../../../../shared/widgets/dream_spinner.dart';
import '../../providers/dreams_providers.dart';
import '../widgets/dream_card.dart';

class MyDreamsPage extends ConsumerWidget {
  const MyDreamsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dc = context.dreamColors;
    final mine = ref.watch(myDreamsProvider);

    return Scaffold(
      backgroundColor: dc.background,
      appBar: AppBar(
        backgroundColor: dc.background,
        elevation: 0,
        title: const Text('My dreams'),
      ),
      body: mine.when(
        loading: () => const Center(child: DreamSpinner()),
        error: (e, _) => DreamEmptyState(
          icon: PhosphorIcons.cloudWarning(),
          title: 'Couldn’t load your dreams',
          subtitle: e.toString(),
          action: TextButton(
            onPressed: () => ref.invalidate(myDreamsProvider),
            child: const Text('Try again'),
          ),
        ),
        data: (dreams) => dreams.isEmpty
            ? DreamEmptyState(
                icon: PhosphorIcons.moonStars(),
                title: 'You haven’t posted a dream',
                action: TextButton(
                  onPressed: () => context.push('/dreams/new'),
                  child: const Text('Post a dream'),
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(myDreamsProvider.future),
                child: ListView(
                  padding: EdgeInsets.only(top: 8.h, bottom: 32.h),
                  children: [
                    for (final d in dreams)
                      DreamCard(
                        dream: d,
                        onTap: () => context.push('/dreams/${d.id}'),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
