import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';
import 'custom_card.dart';

/// Section title with optional trailing action ("See all").
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        // Spec §4: 12 dp below a section header.
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTextStyles.headingSmall),
              if (subtitle != null) Text(subtitle!, style: AppTextStyles.caption),
            ]),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textPrimary))),
        ]),
      );
}

/// A titled group of related fields (HCI: proximity + common region). Each
/// group sits in its own outlined card with an icon, a title, a one-line
/// purpose, and evenly spaced children, so long forms read as a few clear
/// chunks instead of one undifferentiated column of fields.
class FormSection extends StatelessWidget {
  final String title;
  final String? description;
  final IconData icon;
  final List<Widget> children;
  final double spacing;
  const FormSection({super.key, required this.title, required this.icon, required this.children, this.description, this.spacing = 14});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(SizedBox(height: spacing));
      items.add(children[i]);
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTextStyles.labelLarge),
              if (description != null) ...[const SizedBox(height: 2), Text(description!, style: AppTextStyles.caption)],
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        ...items,
      ]),
    );
  }
}

/// A value the user can see but not edit here (shown as text, not as a
/// disabled input, so it isn't mistaken for an editable field).
class ReadOnlyItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? note;
  const ReadOnlyItem({super.key, required this.label, required this.value, this.icon = Icons.lock_outline_rounded, this.note});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.bodyLarge, overflow: TextOverflow.ellipsis),
              if (note != null) ...[const SizedBox(height: 2), Text(note!, style: AppTextStyles.captionSmall)],
            ]),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: AppColors.textMuted),
        ]),
      );
}

/// Label / value row for summaries and detail screens.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;
  const InfoRow(this.label, this.value, {super.key, this.emphasize = false, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: Text(label, style: AppTextStyles.bodySmall)),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(value,
                textAlign: TextAlign.right,
                style: (emphasize ? AppTextStyles.priceSmall : AppTextStyles.labelMedium).copyWith(color: valueColor)),
          ),
        ]),
      );
}

/// Network image with a friendly placeholder (rooms, pets). Falls back to an icon.
class AppImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final double radius;
  final IconData fallbackIcon;
  final BoxFit fit;
  const AppImage({super.key, required this.url, this.width, this.height, this.radius = 14, this.fallbackIcon = Icons.pets_rounded, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.primaryContainer,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: AppColors.primaryDark, size: 30),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? placeholder
          : Image.network(url,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (c, child, p) => p == null ? child : placeholder),
    );
  }
}

/// Stat tile used on dashboards and summaries.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  const StatTile({super.key, required this.label, required this.value, required this.icon, this.tint = AppColors.chipYellow});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTextStyles.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: AppTextStyles.headingMedium)),
            ]),
          ),
        ]),
      );
}

/// Horizontal single-select filter chips.
class FilterChipsRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  const FilterChipsRow({super.key, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(o),
                  selected: o == selected,
                  showCheckmark: false,
                  labelStyle: AppTextStyles.chipLabel.copyWith(color: AppColors.ink, fontWeight: o == selected ? FontWeight.w600 : FontWeight.w500),
                  side: BorderSide(color: o == selected ? AppColors.ink : AppColors.line, width: 1.5),
                  onSelected: (_) => onSelected(o),
                ),
              ),
          ],
        ),
      );
}

/// Snackbars.
void showSuccess(BuildContext context, String msg) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle_rounded, color: AppColors.primary), const SizedBox(width: 10), Expanded(child: Text(msg))])));

void showError(BuildContext context, String msg) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(
      backgroundColor: AppColors.errorText,
      content: Row(children: [const Icon(Icons.error_outline_rounded, color: AppColors.onInk), const SizedBox(width: 10), Expanded(child: Text(msg))])));

/// Confirmation dialog. Destructive confirms are red (spec §4.4).
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Go back',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Text-input dialog (e.g. rejection reason). Returns null when cancelled.
Future<String?> promptDialog(BuildContext context, {required String title, String hint = '', String confirmLabel = 'Save', bool destructive = false}) async {
  final ctrl = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, maxLines: 3, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Go back')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.error) : null,
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r;
}

/// Constrains content width on tablets/web so forms and lists stay readable.
class MaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const MaxWidth({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}
