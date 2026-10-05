import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double mobileMax = 600.0;
  static const double tabletMax = 900.0;
}

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < ResponsiveBreakpoints.mobileMax;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= ResponsiveBreakpoints.mobileMax &&
        width <= ResponsiveBreakpoints.tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width > ResponsiveBreakpoints.tabletMax;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > ResponsiveBreakpoints.tabletMax) {
          return desktop;
        } else if (constraints.maxWidth >= ResponsiveBreakpoints.mobileMax) {
          return tablet ?? desktop;
        } else {
          return mobile;
        }
      },
    );
  }
}
