// =============================================================================
// Magic Colors · tests/unit/coloring/drawing_complete_overlay_test.dart
// =============================================================================
//
// M2.4 — minimal smoke test. Validates that the overlay renders the
// title text and the dismisses via the onDone callback without
// leaking resources. We keep the test cheap so the screenshot-diff
// QA can run nightly without dragging the unit-test budget.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/core/theme/app_theme.dart' show AppTheme;
import 'package:magic_colors/features/coloring/widgets/drawing_complete_overlay.dart';

void main() {
  testWidgets('DrawingCompleteOverlay renders title + dismiss CTA',
      (WidgetTester tester) async {
    bool dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: DrawingCompleteOverlay(
              title: 'WOW!',
              subtitle: 'Nice drawing.',
              coinDelta: 5,
              onDone: () => dismissed = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('WOW!'), findsOneWidget);
    expect(find.text('Nice drawing.'), findsOneWidget);
    expect(find.text('Awesome!'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
    // Tap the CTA — pumps confetti forward, then closing the dialog
    // is the parent's job (this widget only signals onDone).
    await tester.tap(find.text('Awesome!'));
    await tester.pump();
    expect(dismissed, isTrue);
  });
}
