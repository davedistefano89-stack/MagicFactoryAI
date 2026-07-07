// Haptics — typed wrapper around Flutter's HapticFeedback.

import 'package:flutter/services.dart';

class Haptics {
  Haptics._();

  static Future<void> light() => HapticFeedback.lightImpact();
  static Future<void> medium() => HapticFeedback.mediumImpact();
  static Future<void> heavy() => HapticFeedback.heavyImpact();
  static Future<void> selection() => HapticFeedback.selectionClick();
  static Future<void> success() => HapticFeedback.lightImpact();
  static Future<void> warning() => HapticFeedback.mediumImpact();
}
