import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';
import '../constants/app_tokens.dart';
import 'common.dart';
import 'custom_button.dart';
import 'custom_card.dart';
import 'empty_state.dart' show friendlyError;

/// Opens a bottom-sheet editor (Personal Information rows, owner request
/// 2026-10-03): title, fields, Save / Cancel, loading and error feedback.
/// The sheet never exceeds 90 % of the screen, scrolls above the keyboard,
/// and asks before discarding unsaved changes. Returns true when saved.
Future<bool> showEditSheet(
  BuildContext context, {
  required String title,
  String? description,
  required WidgetBuilder fields,
  required Future<void> Function() onSave,
  bool Function()? isDirty,
  String saveLabel = 'Save',
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => EditSheet(title: title, description: description, fields: fields, onSave: onSave, isDirty: isDirty, saveLabel: saveLabel),
  );
  return saved ?? false;
}

class EditSheet extends StatefulWidget {
  final String title;
  final String? description;
  final WidgetBuilder fields;
  final Future<void> Function() onSave;
  final bool Function()? isDirty;
  final String saveLabel;

  const EditSheet({super.key, required this.title, this.description, required this.fields, required this.onSave, this.isDirty, this.saveLabel = 'Save'});

  @override
  State<EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<EditSheet> {
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    if (await _confirmDiscard() && mounted) Navigator.of(context).pop(false);
  }

  Future<bool> _confirmDiscard() async {
    if (_saving) return false;
    if (!(widget.isDirty?.call() ?? false)) return true;
    return confirmDialog(context, title: 'Discard changes?', message: 'Your changes have not been saved.', confirmLabel: 'Discard', cancelLabel: 'Keep editing', destructive: true);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop(false);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            child: Form(
              key: _form,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(widget.title, style: AppTextStyles.titleLarge),
                if (widget.description != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(widget.description!, style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted)),
                ],
                const SizedBox(height: AppSpacing.lg),
                AbsorbPointer(absorbing: _saving, child: widget.fields(context)),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  TintedCard(
                    tintColor: AppColors.errorBg,
                    borderColor: AppColors.errorBorder,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.errorText, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(_error!, style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.errorText))),
                    ]),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(children: [
                  Expanded(child: SecondaryButton(label: 'Cancel', onPressed: _saving ? null : _cancel)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: PrimaryButton(label: widget.saveLabel, isLoading: _saving, onPressed: _save)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of a grouped settings list: icon, label, value (wraps), chevron.
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String? placeholder;
  final VoidCallback? onTap;
  final bool destructive;
  final int valueMaxLines;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.placeholder,
    this.onTap,
    this.destructive = false,
    this.valueMaxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = (value ?? '').trim().isNotEmpty;
    final color = destructive ? AppColors.errorText : AppColors.ink;
    return Semantics(
      button: onTap != null,
      label: hasValue ? '$label: $value' : (placeholder ?? label),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(children: [
              Icon(icon, size: 22, color: destructive ? AppColors.errorText : AppColors.inkMuted),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: (hasValue ? AppTextStyles.bodySmallRole.copyWith(color: AppColors.inkMuted) : AppTextStyles.bodyLargeRole.copyWith(color: color))),
                  if (hasValue)
                    Text(value!, style: AppTextStyles.bodyLargeRole.copyWith(color: color), maxLines: valueMaxLines, overflow: TextOverflow.ellipsis)
                  else if (placeholder != null)
                    Text(placeholder!, style: AppTextStyles.bodySmallRole.copyWith(color: AppColors.skyText)),
                ]),
              ),
              if (onTap != null && !destructive) ...[
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// A titled card that groups [SettingsRow]s with hairline dividers.
class SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const SettingsGroup({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Semantics(header: true, child: Text(title, style: AppTextStyles.titleMedium)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.line, width: AppBorders.width),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 56, color: AppColors.line),
                rows[i],
              ],
            ]),
          ),
        ),
      ]);
}
