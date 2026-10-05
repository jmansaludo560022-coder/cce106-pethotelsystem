import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_tokens.dart';

/// App-wide loading indicator (Enhancement Spec §5): three paw prints that
/// light up one after another. With reduced motion the paws only fade
/// (no bounce), so progress is still visible without movement.
class PawLoader extends StatefulWidget {
  final double size;
  final Color color;
  final String semanticLabel;

  const PawLoader({super.key, this.size = 22, this.color = AppColors.ink, this.semanticLabel = 'Loading'});

  /// 0..1 "lit" amount for paw [i] at animation value [t]: each paw peaks a
  /// third of a cycle after the previous one.
  static double litAt(int i, double t) {
    final phase = (t - i / 3) % 1.0;
    return math.max(0, math.sin(phase * math.pi * 2)).toDouble();
  }

  @override
  State<PawLoader> createState() => _PawLoaderState();
}

class _PawLoaderState extends State<PawLoader> with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 1200);
  late final AnimationController _c = AnimationController(vsync: this, duration: _cycle)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final lit = PawLoader.litAt(i, _c.value);
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.size * 0.18),
                child: Transform.translate(
                  offset: Offset(0, reduced ? 0 : -lit * widget.size * 0.35),
                  // Alternating tilt makes the three dots read as footsteps.
                  child: Transform.rotate(
                    angle: (i.isEven ? -1 : 1) * 0.25,
                    child: Opacity(
                      opacity: 0.3 + 0.7 * lit,
                      child: Icon(Icons.pets_rounded, size: widget.size, color: widget.color),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
