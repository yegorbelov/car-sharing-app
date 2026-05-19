import 'package:flutter/material.dart';

import '../core/api_config.dart';
import '../models/vehicle.dart';
import '../services/staff_api.dart';

class ModerationRejectInput {
  const ModerationRejectInput({
    required this.reasonCode,
    required this.reasonLabel,
    this.comment = '',
  });

  final String reasonCode;
  final String reasonLabel;
  final String comment;
}

/// Mandatory reason from catalog + optional comment.
Future<ModerationRejectInput?> showModerationRejectDialog(
  BuildContext context, {
  required Vehicle vehicle,
  required List<RejectionReason> reasons,
}) {
  if (reasons.isEmpty) return Future.value();

  final sorted = List<RejectionReason>.from(reasons)
    ..sort((a, b) {
      if (a.code == 'other') return 1;
      if (b.code == 'other') return -1;
      return a.label.compareTo(b.label);
    });

  return showModalBottomSheet<ModerationRejectInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ModerationRejectSheet(
      vehicle: vehicle,
      reasons: sorted,
    ),
  );
}

class _ModerationRejectSheet extends StatefulWidget {
  const _ModerationRejectSheet({
    required this.vehicle,
    required this.reasons,
  });

  final Vehicle vehicle;
  final List<RejectionReason> reasons;

  @override
  State<_ModerationRejectSheet> createState() => _ModerationRejectSheetState();
}

class _ModerationRejectSheetState extends State<_ModerationRejectSheet> {
  late String _reasonCode;
  late final TextEditingController _commentCtrl;

  @override
  void initState() {
    super.initState();
    _reasonCode = widget.reasons.first.code;
    _commentCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _submit() {
    final commentTooLong = _commentCtrl.text.trim().length > 500;
    if (commentTooLong) return;
    final selected = widget.reasons.firstWhere((r) => r.code == _reasonCode);
    Navigator.pop(
      context,
      ModerationRejectInput(
        reasonCode: _reasonCode,
        reasonLabel: selected.label,
        comment: _commentCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final commentTooLong = _commentCtrl.text.trim().length > 500;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final vehicle = widget.vehicle;
    final sorted = widget.reasons;
    final cover = vehicle.photoUrl.isNotEmpty
        ? fullImageUrl(vehicle.photoUrl)
        : null;

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.errorContainer.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.block_rounded, color: cs.error),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reject listing',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                            Text(
                              'Required reason · optional note',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F6FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: cover != null
                                    ? Image.network(
                                        cover,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 56,
                                        height: 56,
                                        color: cs.surfaceContainerHighest,
                                        child: Icon(
                                          Icons.directions_car_rounded,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vehicle.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      vehicle.city,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Reason',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        ...sorted.map((r) {
                          final selected = r.code == _reasonCode;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => setState(() => _reasonCode = r.code),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? cs.errorContainer.withValues(alpha: 0.4)
                                      : const Color(0xFFF4F6FA),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? cs.error.withValues(alpha: 0.5)
                                        : cs.outlineVariant.withValues(
                                            alpha: 0.4,
                                          ),
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        selected
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        size: 22,
                                        color: selected
                                            ? cs.error
                                            : cs.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          r.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: selected
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        Text(
                          'Comment',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _commentCtrl,
                          maxLines: 3,
                          maxLength: 500,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Add details (optional)',
                            filled: true,
                            fillColor: const Color(0xFFF4F6FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: cs.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: cs.primary.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                            ),
                            errorText: commentTooLong
                                ? 'Max 500 characters'
                                : null,
                            counterStyle: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: commentTooLong ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: cs.error,
                            foregroundColor: cs.onError,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
