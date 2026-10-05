import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/widgets/widgets.dart';

/// Shows [LaunchScreen] while the app starts, then [child] (Enhancement
/// Spec §5, roadmap Phase 2).
///
/// - The splash stays at least [minDuration] so it never just flickers.
/// - It leaves as soon as [ready] is true after that, and never later than
///   [maxDuration]: if sign-in is still loading then, [child] shows its own
///   loading state, so a slow network never traps the user on the splash.
/// - Once the app is shown, the splash never comes back (e.g. on sign-out).
class LaunchGate extends StatefulWidget {
  final bool ready;
  final Widget child;
  final Duration minDuration;
  final Duration maxDuration;

  static const defaultMin = Duration(milliseconds: 1200);
  static const defaultMax = Duration(seconds: 3);

  const LaunchGate({
    super.key,
    required this.ready,
    required this.child,
    this.minDuration = defaultMin,
    this.maxDuration = defaultMax,
  });

  /// Pure decision, unit-tested: may the app replace the splash now?
  static bool shouldShowApp({required bool ready, required bool minElapsed, required bool maxElapsed}) =>
      minElapsed && (ready || maxElapsed);

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  Timer? _minTimer;
  Timer? _maxTimer;
  bool _minElapsed = false;
  bool _maxElapsed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _minTimer = Timer(widget.minDuration, () => _update(() => _minElapsed = true));
    _maxTimer = Timer(widget.maxDuration, () => _update(() => _maxElapsed = true));
  }

  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(() {
      change();
      if (LaunchGate.shouldShowApp(ready: widget.ready, minElapsed: _minElapsed, maxElapsed: _maxElapsed)) {
        _done = true;
        _minTimer?.cancel();
        _maxTimer?.cancel();
      }
    });
  }

  @override
  void didUpdateWidget(LaunchGate old) {
    super.didUpdateWidget(old);
    if (!_done && widget.ready != old.ready && LaunchGate.shouldShowApp(ready: widget.ready, minElapsed: _minElapsed, maxElapsed: _maxElapsed)) {
      _done = true;
      _maxTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _maxTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.slow),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      child: _done ? KeyedSubtree(key: const ValueKey('app'), child: widget.child) : const LaunchScreen(key: ValueKey('launch')),
    );
  }
}

/// The animated splash: the mascot pops in, the name fades up, paws pulse.
/// With reduced motion everything simply fades in.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  static const appName = 'Pet Hotel';
  static const tagline = "Your pet's home away from home";
  static const popInKey = ValueKey('mascot-pop-in');

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  late final Animation<double> _mascotFade = CurvedAnimation(parent: _c, curve: const Interval(0, 0.3, curve: Curves.easeOut));
  late final Animation<double> _mascotScale =
      Tween(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0, 0.75, curve: AppMotion.mascot)));
  late final Animation<double> _textFade = CurvedAnimation(parent: _c, curve: const Interval(0.35, 0.8, curve: AppMotion.enter));
  late final Animation<Offset> _textSlide =
      Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _c, curve: const Interval(0.35, 0.8, curve: AppMotion.enter)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final shortSide = MediaQuery.sizeOf(context).shortestSide;
    final mascotSize = (shortSide * 0.45).clamp(120.0, 200.0);

    Widget mascot = const Mascot(pose: MascotPose.wave, semanticLabel: 'Pet Hotel mascot waving hello');
    mascot = SizedBox(height: mascotSize, child: FittedBox(child: mascot));
    mascot = reduced ? FadeTransition(opacity: _mascotFade, child: mascot) : FadeTransition(opacity: _mascotFade, child: ScaleTransition(key: LaunchScreen.popInKey, scale: _mascotScale, child: mascot));

    Widget title = Column(mainAxisSize: MainAxisSize.min, children: [
      const Text(LaunchScreen.appName, style: AppTextStyles.displaySmall, textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.xs),
      Text(LaunchScreen.tagline, style: AppTextStyles.bodyMediumRole.copyWith(color: AppColors.inkMuted), textAlign: TextAlign.center),
    ]);
    title = reduced ? FadeTransition(opacity: _textFade, child: title) : FadeTransition(opacity: _textFade, child: SlideTransition(position: _textSlide, child: title));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              mascot,
              const SizedBox(height: AppSpacing.xxl),
              title,
              const SizedBox(height: AppSpacing.xxxl),
              const PawLoader(semanticLabel: 'Starting Pet Hotel'),
            ]),
          ),
        ),
      ),
    );
  }
}
