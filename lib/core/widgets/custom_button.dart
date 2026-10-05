import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_tokens.dart';
import 'pressable.dart';

/// Button hierarchy (master spec §4.4, UI-002). All buttons are pill-shaped.
///  • [PrimaryButton]     – main action, golden yellow.
///  • [InkButton]         – strong secondary action, near-black (e.g. "QR Pass").
///  • [SecondaryButton]   – outlined.
///  • [TertiaryButton]    – text only.
///  • [DestructiveButton] – red (cancel booking, reject, delete).

Widget _content(String label, IconData? icon, bool loading, Color spinner) {
  if (loading) {
    return SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: spinner));
  }
  final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center);
  if (icon == null) return text;
  return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18), const SizedBox(width: 8), Flexible(child: text)]);
}

Widget _wrap(Widget b, bool fullWidth) => fullWidth ? SizedBox(width: double.infinity, child: b) : b;

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.isLoading = false, this.fullWidth = true});

  /// Spec §4/§7: mustard pill, ink outline, solid "pop" shadow; pressing
  /// scales to 0.97 and the shadow shrinks. Disabled buttons have no shadow.
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return _wrap(
      Pressable(
        enabled: enabled,
        builder: (context, pressed) => AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: enabled ? (pressed ? AppShadows.popPressed : AppShadows.pop) : const [],
          ),
          child: ElevatedButton(onPressed: isLoading ? null : onPressed, child: _content(label, icon, isLoading, AppColors.onPrimary)),
        ),
      ),
      fullWidth,
    );
  }
}

class InkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  const InkButton({super.key, required this.label, required this.onPressed, this.icon, this.isLoading = false, this.fullWidth = true});

  @override
  Widget build(BuildContext context) => _wrap(
        FilledButton(onPressed: isLoading ? null : onPressed, child: _content(label, icon, isLoading, AppColors.onInk)),
        fullWidth,
      );
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.isLoading = false, this.fullWidth = true});

  @override
  Widget build(BuildContext context) => _wrap(
        OutlinedButton(onPressed: isLoading ? null : onPressed, child: _content(label, icon, isLoading, AppColors.textPrimary)),
        fullWidth,
      );
}

class TertiaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  const TertiaryButton({super.key, required this.label, required this.onPressed, this.icon, this.color});

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: color != null ? TextButton.styleFrom(foregroundColor: color) : null,
        child: _content(label, icon, false, AppColors.textPrimary),
      );
}

class DestructiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool isLoading;
  final bool fullWidth;
  const DestructiveButton({super.key, required this.label, required this.onPressed, this.icon, this.outlined = true, this.isLoading = false, this.fullWidth = true});

  @override
  Widget build(BuildContext context) {
    final child = _content(label, icon, isLoading, outlined ? AppColors.error : AppColors.onInk);
    final b = outlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.errorText,
              backgroundColor: AppColors.errorBg,
              side: const BorderSide(color: AppColors.errorBorder),
            ),
            child: child)
        : FilledButton(
            onPressed: isLoading ? null : onPressed,
            style: FilledButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.onInk),
            child: child);
    return _wrap(b, fullWidth);
  }
}
