// Responsive helpers — design at 360 × 800 (typical small phone).
// On larger screens, scale up proportionally; on smaller screens, scale
// down — but never below 0.85 (preserve legibility).

import 'package:flutter/widgets.dart';

enum MagicBreakpoint { compact, medium, expanded }

class ResponsiveScale {
  ResponsiveScale._();

  static const Size designSize = Size(360, 800);

  static double scale(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double sw = size.width / designSize.width;
    final double sh = size.height / designSize.height;
    final double v = sw < sh ? sw : sh;
    return v.clamp(0.85, 1.20);
  }

  static double sc(BuildContext context, double dp) => dp * scale(context);

  static double vsc(BuildContext context, double dp) => dp * scale(context);

  static MagicBreakpoint breakpoint(BuildContext context) {
    final double w = MediaQuery.sizeOf(context).width;
    if (w <= 480) return MagicBreakpoint.compact;
    if (w <= 720) return MagicBreakpoint.medium;
    return MagicBreakpoint.expanded;
  }
}
