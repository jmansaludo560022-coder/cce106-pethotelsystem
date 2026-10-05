import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/widgets/widgets.dart';
import 'cus_auth.dart';

/// S-01 Landing carousel (AUTH-001, Figma "Landing Page"). Shared by
/// everyone, including the admin. Owner request (2026-10-03): real-world
/// photos instead of icons in circles, so the app feels like an actual pet
/// hotel. Photos are bundled (CC0, see project_documentation/assets/
/// PHOTO_CREDITS.md), so no network is needed. Slides auto-advance and can
/// be swiped.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _Slide {
  final String image;
  final String imageLabel;
  final String title;
  final String text;
  const _Slide(this.image, this.imageLabel, this.title, this.text);
}

class _LandingScreenState extends State<LandingScreen> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  static const _slides = [
    _Slide('assets/images/landing/slide1_home_away.jpg', 'Two dogs resting together on a soft blanket', "Your pet's home away from home",
        'Cozy boarding rooms in Davao City, open 24 hours for your beloved companions.'),
    _Slide('assets/images/landing/slide2_book_on_phone.jpg', 'A pet owner booking on his phone with his dog beside him', 'Book in a few taps',
        'Choose a room, pick your dates and add grooming or playtime — all from your phone.'),
    _Slide('assets/images/landing/slide3_check_in.jpg', 'A happy dog with its owner', 'Fast QR check-in',
        'Once approved, show your digital QR pass at the front desk for a quick check-in and check-out.'),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      final next = (_page + 1) % _slides.length;
      _controller.animateToPage(next, duration: AppMotion.slow, curve: AppMotion.enter);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load every slide photo up front so none pops in when the slide changes.
    for (final slide in _slides) {
      precacheImage(AssetImage(slide.image), context).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _toLogin() {
    _timer?.cancel();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: MaxWidth(
          maxWidth: 520,
          child: Column(children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: AppMotion.of(context, AppMotion.normal),
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: active ? AppColors.ink : AppColors.borderMedium, borderRadius: BorderRadius.circular(AppRadius.pill)),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xs),
              child: PrimaryButton(
                label: last ? "Let's get started" : 'Next',
                onPressed: last ? _toLogin : () => _controller.nextPage(duration: AppMotion.slow, curve: AppMotion.enter),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                const Text('Already have an account? ', style: AppTextStyles.bodyMedium),
                Semantics(
                  button: true,
                  child: InkWell(
                    onTap: _toLogin,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
                      child: Text('Sign in', style: AppTextStyles.linkBold),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
      // Skip floats over the photo, top-right.
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Material(
          color: AppColors.surface.withValues(alpha: 0.92),
          shape: const StadiumBorder(side: BorderSide(color: AppColors.line)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: _toLogin,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Text('Skip', style: AppTextStyles.labelLargeRole),
            ),
          ),
        ),
      ),
    );
  }
}

/// Diameter of the photo circle (the original 220 px design).
const double kLandingCircle = 220;

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
        child: Column(children: [
          Expanded(
            child: Center(
              // A real photo inside the original circle: ClipOval makes the
              // clip a true circle, and the 2 px ink ring is drawn on top.
              child: Container(
                key: const ValueKey('landing_photo_circle'),
                width: kLandingCircle,
                height: kLandingCircle,
                decoration: const BoxDecoration(color: AppColors.mustardSoft, shape: BoxShape.circle),
                child: Stack(fit: StackFit.expand, children: [
                  ClipOval(
                    child: Image.asset(
                      slide.image,
                      fit: BoxFit.cover,
                      semanticLabel: slide.imageLabel,
                      errorBuilder: (_, _, _) => const Center(child: Mascot(pose: MascotPose.wave, size: 120)),
                    ),
                  ),
                  const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: AppColors.ink, width: AppBorders.width)))),
                ]),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(slide.title, style: AppTextStyles.displaySmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(slide.text, style: AppTextStyles.bodyLargeRole.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
        ]),
      );
}
