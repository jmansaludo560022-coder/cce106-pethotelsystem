import 'package:flutter/material.dart';

import '../constants/app_tokens.dart';

/// Press feedback (Enhancement Spec §7): scales to 0.97 while pressed, like a
/// physical button, and lets [builder] shrink the pop shadow. It never blocks
/// or delays the tap, and becomes a no-op when the user asked for reduced
/// motion (spec §7 guardrail).
class Pressable extends StatefulWidget {
  final bool enabled;
  final Widget Function(BuildContext context, bool pressed) builder;
  const Pressable({super.key, required this.builder, this.enabled = true});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (!widget.enabled || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final pressed = _pressed && widget.enabled;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: pressed && !reduced ? 0.97 : 1.0,
        duration: reduced ? Duration.zero : AppMotion.fast,
        curve: AppMotion.enter,
        child: widget.builder(context, pressed),
      ),
    );
  }
}
