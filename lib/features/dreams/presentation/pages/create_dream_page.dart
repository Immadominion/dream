import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dream_colors.dart';
import '../../../../shared/widgets/dream_buttons.dart';
import '../../../../shared/widgets/error_utils.dart';
import '../../models/dream_models.dart';
import '../../providers/dreams_providers.dart';

/// Post a dream. Limits mirror the server's validation so users see errors
/// before submitting; the server remains the authority.
class CreateDreamPage extends ConsumerStatefulWidget {
  const CreateDreamPage({super.key});

  @override
  ConsumerState<CreateDreamPage> createState() => _CreateDreamPageState();
}

class _CreateDreamPageState extends ConsumerState<CreateDreamPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _story = TextEditingController();
  final _goal = TextEditingController();
  DreamCategory _category = DreamCategory.medical;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _story.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final dream = await ref
          .read(dreamActionsProvider)
          .create(
            title: _title.text.trim(),
            story: _story.text.trim(),
            category: _category,
            goalUsdc: _goal.text.trim(),
          );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      context.pushReplacement('/dreams/${dream.id}');
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dc = context.dreamColors;

    InputDecoration deco(String label, {String? hint, String? prefix}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefix,
          alignLabelWithHint: true,
          labelStyle: TextStyle(color: dc.muted),
          hintStyle: TextStyle(color: dc.muted.withValues(alpha: 0.7)),
          filled: true,
          fillColor: dc.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(color: dc.stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(color: dc.primary),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(color: dc.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(color: dc.error),
          ),
        );
    final textStyle = TextStyle(color: dc.onSurface, fontSize: 15.sp);

    return Scaffold(
      backgroundColor: dc.background,
      appBar: AppBar(
        backgroundColor: dc.background,
        elevation: 0,
        title: const Text('Post a dream'),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
            children: [
              Text(
                'Tell people what you need and why. Be specific — real details '
                'are what get dreams funded. Money goes straight to your wallet. '
                'After posting, link your X account to show supporters it’s really you.',
                style: TextStyle(color: dc.muted, fontSize: 13.sp, height: 1.4),
              ),
              SizedBox(height: 20.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  for (final c in DreamCategory.values)
                    ChoiceChip(
                      label: Text('${c.emoji} ${c.label}'),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _title,
                maxLength: 80,
                style: textStyle,
                textCapitalization: TextCapitalization.sentences,
                decoration: deco(
                  'What do you need?',
                  hint: 'e.g. Help me pay my final-year school fees',
                ),
                validator: (v) => (v ?? '').trim().length < 8
                    ? 'At least 8 characters'
                    : null,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _story,
                maxLength: 2000,
                minLines: 5,
                maxLines: 12,
                style: textStyle,
                textCapitalization: TextCapitalization.sentences,
                decoration: deco(
                  'Your story',
                  hint:
                      'Who you are, what happened, what the money is for, and by when.',
                ),
                validator: (v) => (v ?? '').trim().length < 40
                    ? 'Tell a bit more (at least 40 characters)'
                    : null,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _goal,
                style: textStyle,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,7}(\.\d{0,2})?'),
                  ),
                ],
                decoration: deco('Goal', prefix: '\$ ', hint: '350'),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null || n < 1) return 'At least \$1';
                  if (n > 1000000) return 'At most \$1,000,000';
                  return null;
                },
              ),
              SizedBox(height: 24.h),
              DreamPrimaryButton(
                label: 'Post dream',
                isLoading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
              SizedBox(height: 12.h),
              Text(
                'Posting false needs gets your dream removed. Supporters can report dreams.',
                textAlign: TextAlign.center,
                style: TextStyle(color: dc.muted, fontSize: 11.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
