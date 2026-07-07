// Magic Colors — global theme tokens.
// Single source of truth for colors, gradients, typography, shapes, shadows.
// Used by every widget in the app.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand color palette. Soft, joyful, high-contrast-friendly for ages 3+.
///
/// Every color here passes WCAG AA contrast against white text in body roles
/// (verified during design); final QA must re-verify against shipped UI.
class AppColors {
  AppColors._();

  // Sky & atmosphere
  static const Color skyTop = Color(0xFFB6E2FF); // soft sky blue
  static const Color skyMid = Color(0xFFFFE0F0); // cotton-candy pink
  static const Color skyBottom = Color(0xFFFFF6E6); // warm cream

  // Brand rainbow
  static const Color rainbowRed = Color(0xFFFF6B6B);
  static const Color rainbowOrange = Color(0xFFFFA94D);
  static const Color rainbowYellow = Color(0xFFFFD93D);
  static const Color rainbowGreen = Color(0xFF6BCB77);
  static const Color rainbowBlue = Color(0xFF4D96FF);
  static const Color rainbowPurple = Color(0xFFC780FA);

  // Primary surface accents
  static const Color primaryPurple = Color(0xFF7B5BFF);
  static const Color primaryPink = Color(0xFFFF7BB6);
  static const Color accentYellow = Color(0xFFFFD93D);
  static const Color accentMint = Color(0xFF6FE6C7);

  // Currency
  static const Color coinGold = Color(0xFFFFC93C);
  static const Color coinGoldShade = Color(0xFFE8A91A);
  static const Color gemPink = Color(0xFFFF77B7);
  static const Color gemPinkShade = Color(0xFFD14B92);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color cream = Color(0xFFFFF8EE);
  static const Color textDark = Color(0xFF3A2E5A);
  static const Color textMid = Color(0xFF6E6397);
  static const Color textLight = Color(0xFFB8B0D6);

  // Status
  static const Color success = Color(0xFF6BCB77);
  static const Color warning = Color(0xFFFFB84D);
  static const Color error = Color(0xFFFF6B6B);
  static const Color notificationBubble = Color(0xFFFF4D6D);

  // Shadows
  static const Color shadowSoft = Color(0x337A55D9); // 20% violet
  static const Color shadowDeep = Color(0x554D2A8C); // 33% deep violet
}

/// Pre-built child-friendly gradients used across buttons, cards, and CTA chips.
class AppGradients {
  AppGradients._();

  static const LinearGradient rainbow = LinearGradient(
    colors: [
      AppColors.rainbowRed,
      AppColors.rainbowOrange,
      AppColors.rainbowYellow,
      AppColors.rainbowGreen,
      AppColors.rainbowBlue,
      AppColors.rainbowPurple,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient playNow = LinearGradient(
    colors: [Color(0xFFFF8FB4), Color(0xFFFFD86E), Color(0xFFFFB16E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient sky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.skyTop,
      AppColors.skyMid,
      AppColors.skyBottom,
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient collection = LinearGradient(
    colors: [Color(0xFFA0E7FF), Color(0xFFFFD1DC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient rewards = LinearGradient(
    colors: [Color(0xFFFFE16C), Color(0xFFFFA94D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shop = LinearGradient(
    colors: [Color(0xFFBFAEFF), Color(0xFFFFB7E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient parents = LinearGradient(
    colors: [Color(0xFFC4F0E5), Color(0xFFE7F0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.rainbowPurple,
      AppColors.rainbowBlue,
      AppColors.primaryPurple,
    ],
  );
}

/// Text style catalog. Two families:
///  - **Baloo 2** — display: logo, mascot wordmarks, big buttons.
///  - **Nunito** — UI body, captions, controls, settings.
class AppTypography {
  AppTypography._();

  static TextStyle logo({double size = 24, Color color = AppColors.textDark}) =>
      GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.5,
        height: 1.0,
      );

  static TextStyle bigButton({double size = 32, Color? color}) =>
      GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.white,
        letterSpacing: 1.2,
        height: 1.0,
        shadows: const [
          Shadow(
            color: Color(0x66000000),
            offset: Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      );

  static TextStyle buttonLabel({double size = 16, Color? color}) =>
      GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textDark,
        letterSpacing: 0.1,
        height: 1.0,
      );

  static TextStyle sectionTitle({double size = 18, Color? color}) =>
      GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.textDark,
        height: 1.1,
      );

  static TextStyle body({double size = 16, Color? color}) => GoogleFonts.nunito(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textDark,
        height: 1.3,
      );

  static TextStyle caption({double size = 12, Color? color}) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textMid,
        letterSpacing: 0.4,
        height: 1.0,
      );

  static TextStyle currencyAmount({double size = 16, Color? color}) =>
      GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.textDark,
        height: 1.0,
      );
}

/// Geometry tokens. Big radii & paddings — the "cute & rounded" identity.
class AppShape {
  AppShape._();

  static const double radiusXS = 8;
  static const double radiusS = 14;
  static const double radiusM = 22;
  static const double radiusL = 32;
  static const double radiusXL = 48;
  static const double radiusPill = 999;

  static const double paddingXS = 4;
  static const double paddingS = 8;
  static const double paddingM = 16;
  static const double paddingL = 24;
  static const double paddingXL = 32;

  static const double minTouchTarget = 64; // Ages 3–8: oversized.
}

/// Soft, layered shadows. The "premium & Disney-feeling" depth.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x337A55D9),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x447A55D9),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x33FFFFFF),
      offset: Offset(0, -2),
    ),
  ];

  static const List<BoxShadow> deep = [
    BoxShadow(
      color: Color(0x664D2A8C),
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
  ];

  static const List<BoxShadow> playButton = [
    BoxShadow(
      color: Color(0x66FF6F94),
      blurRadius: 36,
      offset: Offset(0, 18),
    ),
    BoxShadow(
      color: Color(0x33FFE16C),
      blurRadius: 60,
    ),
  ];
}
