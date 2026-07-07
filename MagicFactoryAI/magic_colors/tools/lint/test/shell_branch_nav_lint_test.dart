// =============================================================================
// Magic Colors · tools/lint/test/shell_branch_nav_lint_test.dart
// =============================================================================
//
// AST-shape smoke tests for `ShellBranchNavLint.shouldFlag`.
//
// Five canonical scenarios from the M2.4 Phase-3 test plan:
//
//   1. `context.go(AppRoutes.home)`        → FLAGGED (Pattern A)
//   2. `context.go('/home')`               → silent  (string literal)
//   3. `app.AppRoutes.home` (aliased)       → silent  (target ≠ AppRoutes)
//   4. `context.goHome()`                  → FLAGGED (Pattern B)
//   5. `selectShellTab` + `goShellTab`     → silent  (pipeline canonical)
//
// Why these exact scenarios?
// --------------------------
// Each one targets a distinct branch of [ShellBranchNavLint.shouldFlag]:
//   • #1 covers `methodName == 'go'` AND `_readAppRoutesBranchRoot`
//     returns non-null on the canonical `Identifier('AppRoutes')` target.
//   • #2 covers `methodName == 'go'` BUT first arg is a
//     `SimpleStringLiteral`, not a `PropertyAccess`
//     (`_readAppRoutesBranchRoot` early-exits via the `is! PropertyAccess`
//     cast).
//   • #3 covers the aliased-import trick — `app.AppRoutes.home` parses
//     as `PropertyAccess(target=PropertyAccess(target=Identifier('app'),
//     propertyName=Identifier('AppRoutes')), propertyName=Identifier('home'))`.
//     The inner `_readAppRoutesBranchRoot` check on `.home`'s target sees
//     a `PropertyAccess` (the `app.AppRoutes` chain), NOT an
//     `Identifier('AppRoutes')`, so the strict pattern-match suppresses.
//   • #4 covers the bare extension method (Pattern B) — `goHome` is in
//     `_shellBareMethods`.
//   • #5 covers the canonical replacement path — neither `selectShellTab`
//     nor `goShellTab` matches Pattern A's `methodName == 'go'` AND neither
//     is in `_shellBareMethods`. The test sees TWO MethodInvocations, both
//     individually silent.
//
// Test strategy
// -------------
// Strategy A — exercise `shouldFlag` directly. `custom_lint` 0.7.x has
// no public test-driver surface, so wiring up the
// `LintRule.run → ErrorReporter → diagnostics` chain in a unit test
// requires mocking internal classes that drift between minor releases.
// `shouldFlag` IS the source of truth — the `run()` closure delegates
// to it before reporting — so testing it covers exactly the same
// behaviour the framework would observe, with zero mocking overhead.
//
// We parse each fixture body with `analyzer`'s public
// `parseString({required String content, bool throwIfDiagnostics})`
// helper from `package:analyzer/dart/analysis/utilities.dart`. The
// fixtures use unresolved names (`AppRoutes`, `app`, `t`) deliberately
// because we only care about the AST shape — unresolved identifiers
// don't surface as parse errors and `throwIfDiagnostics: false` keeps
// any future parse-level diagnostic from aborting the test.
//
// Each fixture is wrapped in a one-line `void main() { ... }` so the
// text is a syntactically valid `CompilationUnit`. The
// `_CollectMethodInvocations` visitor walks every method invocation
// in the unit — chained calls inside lambda bodies, top-level
// statements, etc. — and we count how many of them return `true` from
// `shouldFlag`.
// =============================================================================

// `parseString` lives in the public `utilities.dart` barrel, but its
// return type `ParseStringResult` is declared in `results.dart` and
// NOT re-exported there in some analyzer minor versions. We don't
// need the type name — the local `final` infers it.
import 'package:analyzer/dart/analysis/utilities.dart' show parseString;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:magic_colors_lint/src/shell_branch_nav_lint.dart';
import 'package:test/test.dart';


void main() {
  group('ShellBranchNavLint.shouldFlag — five canonical scenarios', () {
    // Inline fixture bodies wrapped in `void main() { ... }` for
    // syntactic validity. Each entry maps source → expected count
    // of `shouldFlag(...) == true` invocations across the unit.
    final Map<String, int> scenarios = <String, int>{
      // ────────────────────────────────────────────────────────────
      // 1. FLAGGED. Pattern A: `methodName=='go'` AND first arg is
      //    `PropertyAccess(target=Identifier('AppRoutes'),
      //    propertyName=Identifier('home'))`.
      // ────────────────────────────────────────────────────────────
      'void main() { context.go(AppRoutes.home); }': 1,

      // ────────────────────────────────────────────────────────────
      // 2. silent. First arg is `SimpleStringLiteral('/home')`,
      //    NOT `PropertyAccess` — `_readAppRoutesBranchRoot`
      //    returns `null` via the `is! PropertyAccess` cast.
      //    String-literal routes are a different antipattern
      //    (hard-coded route paths) reserved for a future rule.
      // ────────────────────────────────────────────────────────────
      "void main() { context.go('/home'); }": 0,

      // ────────────────────────────────────────────────────────────
      // 3. silent. Aliased import — `.home`'s target is
      //    `app.AppRoutes` (a `PropertyAccess`), not
      //    `Identifier('AppRoutes')`. The strict
      //    `target is! Identifier` cast fails so the diagnostic
      //    is suppressed.
      // ────────────────────────────────────────────────────────────
      'void main() { context.go(app.AppRoutes.home); }': 0,

      // ────────────────────────────────────────────────────────────
      // 4. FLAGGED. Pattern B: methodName `goHome` is in
      //    `_shellBareMethods` (forwarded from
      //    `GoRouterContextX::goHome` →
      //    `context.go(AppRoutes.home)`).
      // ────────────────────────────────────────────────────────────
      'void main() { context.goHome(); }': 1,

      // ────────────────────────────────────────────────────────────
      // 5. silent. TWO MethodInvocations: `selectShellTab(t)` AND
      //    `goShellTab(t)`. Neither matches Pattern A's
      //    `methodName=='go'` filter and NEITHER is in
      //    `_shellBareMethods`. The visitor counts both; the test
      //    asserts the total flag count across both invocations
      //    is 0 — defeating a future refactor that accidentally
      //    widens `shouldFlag` to swallow any call on `context`.
      // ────────────────────────────────────────────────────────────
      'void main() {\n'
          '  context.selectShellTab(t);\n'
          '  context.goShellTab(t);\n'
          '}\n': 0,
    };

    scenarios.forEach((String source, int expectedFlagCount) {
      final String label = source.length > 64
          ? '${source.substring(0, 61)}...'
          : source;
      test('flag count for: $label', () {
        // `throwIfDiagnostics: false` keeps any parse-level
        // diagnostic (e.g. missing `AppRoutes` import in fixture #1)
        // from aborting the test. We only care about AST shape.
        final parsed = parseString(
          content: source,
          throwIfDiagnostics: false,
        );
        // Fail loudly if a future fixture has a syntactic typo. The
        // Dart parser is highly recovery-friendly, so a partially-
        // broken `main()` declaration could silently hand back a
        // drillhole unit missing the call site, and the count check
        // below would report 0 invocations rather than the expected
        // count — which IS still a loud failure, but only because
        // our expected count happens to be non-zero. If a future
        // contributor adds a `silent` fixture whose expected count is
        // 0, the typo would silently pass. Better to fence the
        // surface now.
        expect(
          parsed.errors,
          isEmpty,
          reason:
              'fixture must parse cleanly (no errors).\nSource:\n$source',
        );

        final _CollectMethodInvocations visitor =
            _CollectMethodInvocations();
        parsed.unit.accept(visitor);

        int flagCount = 0;
        for (final MethodInvocation node in visitor.invocations) {
          if (ShellBranchNavLint.shouldFlag(node)) {
            flagCount++;
          }
        }

        expect(
          flagCount,
          expectedFlagCount,
          reason:
              'Expected $expectedFlagCount flagged MethodInvocation(s) '
              'from shouldFlag, got $flagCount. Source:\n$source',
        );
      });
    });
  });
}


/// Recursively walks a `CompilationUnit` and collects every
/// `MethodInvocation` AST node encountered. Extends
/// `RecursiveAstVisitor<void>` so the walk continues into children
/// (chained methods, lambda bodies, nested blocks, etc.) — without
/// this we'd only see the top-level statement's invocation.
class _CollectMethodInvocations extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node);
    super.visitMethodInvocation(node);
  }
}
