import 'package:flutter/material.dart';

/// Material breakpoints: mobile < 600, tablet 600-1024, desktop > 1024.
const double kMobileMaxWidth = 600;
const double kTabletMaxWidth = 1024;

enum ScreenSize { mobile, tablet, desktop }

ScreenSize screenSizeOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < kMobileMaxWidth) return ScreenSize.mobile;
  if (w < kTabletMaxWidth) return ScreenSize.tablet;
  return ScreenSize.desktop;
}

bool isMobile(BuildContext context) => screenSizeOf(context) == ScreenSize.mobile;
bool isTablet(BuildContext context) => screenSizeOf(context) == ScreenSize.tablet;
bool isDesktop(BuildContext context) => screenSizeOf(context) == ScreenSize.desktop;

/// Chooses one of [mobile], [tablet], [desktop] based on current width.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder desktop;

  @override
  Widget build(BuildContext context) {
    switch (screenSizeOf(context)) {
      case ScreenSize.mobile:
        return mobile(context);
      case ScreenSize.tablet:
        return (tablet ?? desktop)(context);
      case ScreenSize.desktop:
        return desktop(context);
    }
  }
}
