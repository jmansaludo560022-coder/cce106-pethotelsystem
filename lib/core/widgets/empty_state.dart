import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../constants/app_tokens.dart';
import 'custom_button.dart';
import 'mascot.dart';
import 'paw_loader.dart';

/// Standard screen states (master spec §4.7, NAV-004).

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Show the mascot (spec §7: sleeping mascot for empty states) instead of
  /// the icon circle.
  final MascotPose? mascot;

  /// Place the content in the upper third instead of dead centre (spec §9.2).
  final bool topAligned;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.mascot,
    this.topAligned = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: topAligned ? const Alignment(0, -0.45) : Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mascot != null)
              BreathingMascot(pose: mascot!, size: 120)
            else
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: AppColors.textPrimary),
              ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              PrimaryButton(label: actionLabel!, onPressed: onAction, fullWidth: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mascot with a gentle 3 s breathing loop (spec §7). Still with reduced motion.
class BreathingMascot extends StatefulWidget {
  final MascotPose pose;
  final double size;
  const BreathingMascot({super.key, this.pose = MascotPose.sleep, this.size = 120});

  @override
  State<BreathingMascot> createState() => _BreathingMascotState();
}

class _BreathingMascotState extends State<BreathingMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.03).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        alignment: Alignment.bottomCenter,
        child: Mascot(pose: widget.pose, size: widget.size),
      );
}

class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PawLoader(semanticLabel: message ?? 'Loading'),
          if (message != null) ...[const SizedBox(height: 14), Text(message!, style: AppTextStyles.bodyMedium)],
        ]),
      );
}

/// Error state. [onRetry] must actually retry (e.g. recreate the stream).
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  const ErrorState({super.key, this.title = 'Something went wrong', required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 52, color: AppColors.error),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              SecondaryButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry, fullWidth: false),
            ],
          ]),
        ),
      );
}

/// Renders the loading / error / data states of a stream consistently.
class StreamStateBuilder<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext, T) builder;
  final String loadingMessage;
  final String errorTitle;
  final VoidCallback? onRetry;

  const StreamStateBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.loadingMessage = 'Loading…',
    this.errorTitle = 'Unable to load data',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorState(title: errorTitle, message: friendlyError(snap.error), onRetry: onRetry);
        }
        if (!snap.hasData) return LoadingState(message: loadingMessage);
        return builder(context, snap.data as T);
      },
    );
  }
}

/// Converts Firebase / platform exceptions into plain-language messages.
String friendlyError(Object? e) {
  final s = e.toString();
  if (s.contains('permission-denied')) return 'You do not have permission to view or change this data.';
  if (s.contains('unavailable') || s.contains('network')) return 'No connection to the server. Check your internet and try again.';
  if (s.contains('failed-precondition') && s.contains('index')) return 'The database needs an index for this query. See the setup notes.';
  if (s.contains('not-found')) return 'The record no longer exists.';
  final m = RegExp(r'\] (.+)$').firstMatch(s);
  if (m != null) return m.group(1)!;
  return s.replaceFirst('Exception: ', '');
}
