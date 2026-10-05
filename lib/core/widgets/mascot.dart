import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Pet Hotel mascot, an original dog bellhop (Enhancement Spec §5).
/// wave = splash / onboarding, sleep = empty states, cheer = success,
/// head = logo and small brand spots.
enum MascotPose { wave, sleep, cheer, head }

class Mascot extends StatelessWidget {
  final MascotPose pose;

  /// Height of the drawing; the width follows the art's aspect ratio.
  final double size;

  /// Read by screen readers. Pass null when the mascot is purely decorative
  /// next to text that already says the same thing.
  final String? semanticLabel;

  const Mascot({super.key, this.pose = MascotPose.wave, this.size = 160, this.semanticLabel});

  static String assetFor(MascotPose pose) => 'assets/mascot/mascot_${pose.name}.svg';

  @override
  Widget build(BuildContext context) {
    final picture = SvgPicture.asset(
      assetFor(pose),
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      // Keeps layout stable while the asset loads (no jump on first frame).
      placeholderBuilder: (_) => SizedBox(height: size, width: size * (pose == MascotPose.head ? 1.125 : 0.83)),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: picture);
    return Semantics(image: true, label: semanticLabel, child: picture);
  }
}
