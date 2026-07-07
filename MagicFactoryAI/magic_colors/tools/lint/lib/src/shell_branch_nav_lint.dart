// =============================================================================
// Magic Colors · tools/lint/lib/src/shell_branch_nav_lint.dart
// =============================================================================
//
// The `shell_branch_nav` rule.
//
// Two AST patterns trigger the diagnostic:
//
//   1. `context.go(AppRoutes.<branchRoot>)`
//      where `<branchRoot>` ∈ {home, worlds, gallery, shop, profile}.
//      The first argument is `AppRoutes.<branchRoot>` parsed as
//      EITHER a `PropertyAccess(target=Identifier('AppRoutes'),
//      propertyName=Identifier('<branchRoot>'))` (modern form — used
//      for 3+ segment chains like `app.AppRoutes.home`) OR a
//      `PrefixedIdentifier(prefix=Identifier('AppRoutes'),
//      identifier=Identifier('<branchRoot>'))` (legacy form — used
//      for the simple two-segment `AppRoutes.home` shape in
//      `analyzer ^6.11.0`). Both shapes flow through the same
//      `_readAppRoutesBranchRoot` probe. NOT a string literal —
//      `context.go('/home')` is a different antipattern reserved
//      for a future lint rule.
//
//   2. Bare extension method call
//      `context.goHome|goWorlds|goGallery|goShop|goProfile()` — these
//      forward straight into `context.go(AppRoutes.<branchRoot>)` per
//      the `GoRouterContextX` extension in `core/routing/app_router.dart`
//      so they're caught at the same semantic layer.
//
// What the lint recommends
// ------------------------
// Per-branch stack preservation + the `MagicSound.bigTap` cue for
// cross-tab taps + tap-to-root semantics for same-tab taps only
// survive when the call site goes through the canonical
// `selectShellTab + goShellTab` pair (see
// `core/routing/app_router.dart` §"GoRouterContextX"). The lint
// surfaces every bypass so future contributors cannot quietly drop
// back into the plain `context.go(...)` shortcut.
//
// Escape hatch
// ------------
// Two sites legitimately need the path: `splash_screen.dart` (the
// shell doesn't exist yet on process boot, so neither helper would
// resolve — the `context.go(AppRoutes.home)` is the canonical cold-
// start bootstrap) and `coloring_screen.dart` (the `/coloring/:id`
// route is a top-level push outside the shell, so the shell helpers
// would throw `ProviderNotFoundException` here too). Plus the five
// bare-method DEFINITIONS in `core/routing/app_router.dart`
// (`goHome() => go(AppRoutes.home)` etc.) — these are the canonical
// implementations the lint cannot distinguish from call-sites, so
// each body carries `// ignore: shell_branch_nav` with a rationale
// citing the rule.
//
// Implementation notes (M2.4 PHASE 3)
// -----------------------------------
// Extends `DartLintRule` so the `filesToAnalyze` default (`['**.dart']`)
// and the LinterVisitor wiring come for free.
//
// The decision tree lives in the static [shouldFlag] method (annotated
// `@visibleForTesting`). [run] just registers a tiny callback that
// delegates to [shouldFlag] before reporting. This split is what
// makes fixture-based smoke tests possible — `custom_lint` 0.7.x has
// no public test-driver surface, so we exercise the AST decision
// tree directly via `package:analyzer/dart/analysis/utilities.dart`'s
// `parseString` + a `RecursiveAstVisitor` (see
// `test/shell_branch_nav_lint_test.dart`).
//
// The visitor itself is the modern
// `context.registry.addMethodInvocation((MethodInvocation node) => ...)`
// registration pattern — NOT a hand-walked
// `GeneralizingAstVisitor`, which is the older custom_lint_builder
// surface.
//
// Lifecycle choice — `run(resolver, reporter, context)` instead of
// `startUp(resolver, context)`:
//   • `startUp` is async (`Future<void>`) and only receives the
//     SHARED resolver — there's no per-file `ErrorReporter` in scope
//     at that point.
//   • `run` is sync and receives the per-file `ErrorReporter` from
//     `package:analyzer/error/listener.dart`. That's the only path
//     to a per-file diagnostic emit in v0.7.0 —
//     `CustomLintResolver` does NOT expose a reporting method.
//   • Cost: per-file listener registration through
//     `context.registry`. The framework's `LinterVisitor` walks the
//     unit's AST and dispatches registered callbacks once per node,
//     so the registration is idempotent across files.
//
// Diagnostic emit choice — `reporter.atNode(node, code)` instead of
// the older `reporter.reportErrorForNode(code, node)`:
//   • `analyzer ^6.9+` marks `reportErrorForNode` deprecated in
//     favour of the positional-AstNode-first overload `atNode`.
//   • Same `ErrorCode` plumbing, same `AnalysisError` sink — only the
//     argument order swaps.
//
// `LintCode` identifier (`name: 'shell_branch_nav'`) must match the
// `// ignore: shell_branch_nav` directive string EXACTLY (lowercase,
// hyphenated) — Dart's `parseIgnoreForLine` reads this from the
// comment and demotes matching diagnostics.
// =============================================================================

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart' show ErrorReporter;
import 'package:custom_lint_core/custom_lint_core.dart';
import 'package:meta/meta.dart';


/// Single rule exposed by the plugin. See file-level docstring for
/// the AST patterns + escape-hatch rationale.
class ShellBranchNavLint extends DartLintRule {
  /// `const` constructor — the `super(code: _code)` initializer
  /// forwards the static `LintCode` instance to `LintRule`'s
  /// constructor (`{required LintCode code}`). Without this the
  /// analyzer reports "missing super-call" because DartLintRule has
  /// no default constructor.
  const ShellBranchNavLint() : super(code: _code);

  /// Identifier the analyzer matches against the `// ignore:` directive
  /// on a one-line-suppressed call. Must stay lowercase + hyphenated
  /// — Dart's `parseIgnoreForLine` is exact-match.
  static const String _codeId = 'shell_branch_nav';

  /// `problemMessage` is the diagnostic headline; `correctionMessage`
  /// is what the editor surfaces as the "Try: ..." quick-fix hint.
  static const LintCode _code = LintCode(
    name: _codeId,
    problemMessage: "Don't bypass the shell-tab pipeline.",
    correctionMessage:
        'Replace with `context.selectShellTab(<tab>) + '
        'context.goShellTab(<tab>)` to preserve per-branch stacks AND '
        'fire the cross-tab bigTap audio cue. Add `// ignore: '
        'shell_branch_nav` if this is an out-of-shell bootstrap '
        '(splash → home) or a top-level-route exit '
        '(/coloring/:id → worlds).',
  );

  /// The five bottom-nav branch roots AND their matching bare-extension
  /// method names on `BuildContext` (`GoRouterContextX` in
  /// `core/routing/app_router.dart`). This Map is the single source
  /// of truth — the two derived Sets below are pre-computed for
  /// O(1) per-call `.contains()` and stay driven by it.
  static const Map<String, String> _branchRootToBareMethod =
      <String, String>{
    'home': 'goHome',
    'worlds': 'goWorlds',
    'gallery': 'goGallery',
    'shop': 'goShop',
    'profile': 'goProfile',
  };

  /// Set precomputation is cheaper than `.contains()` per call.
  /// Derived once at first access from `_branchRootToBareMethod` —
  /// `static final` rather than `const` because `.keys.toSet()` isn't
  /// a const expression (Dart forbids non-trivial Set-literals as
  /// constants). The lazy init still happens exactly once per process
  /// because Dart caches `static final` initialisers.
  static final Set<String> _shellRoots =
      _branchRootToBareMethod.keys.toSet();
  static final Set<String> _shellBareMethods =
      _branchRootToBareMethod.values.toSet();

  /// Per-file AST processing. We override `run` (NOT `startUp`)
  /// because `run` is the only lifecycle hook in v0.7.0 that receives
  /// the per-file `ErrorReporter` — `startUp`'s signature is async and
  /// only carries the SHARED `resolver`. The framework's internal
  /// `DartLintRule` machinery wires
  /// `LinterVisitor(context.registry.nodeLintRegistry)` after our
  /// `run` completes, dispatching each AST node to the registered
  /// callbacks. The closure captures `reporter` so per-file
  /// `reportErrorForNode` calls are routed to the right
  /// diagnostic sink.
  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Decision delegated to [shouldFlag] — see [shouldFlag] for the
      // AST-shape reasoning. Keeping the closure micro-thin (one
      // boolean + one report call) is intentional: any change to the
      // decision tree should land in [shouldFlag] where the unit tests
      // cover it.
      if (shouldFlag(node)) {
        // Modern analyzer-6.9+ diagnostic emit. The older
        // `reportErrorForNode(code, node)` overload is still defined
        // but is flagged `deprecated_member_use`.
        reporter.atNode(node, _code);
      }
    });
  }

  /// AST decision tree. Returns `true` iff [node] is a call site the
  /// rule should emit a diagnostic for.
  ///
  /// **Pattern A — `context.go(AppRoutes.<branchRoot>)`**
  /// First argument shape must be the AST leaf `AppRoutes.<branchRoot>`
  /// — i.e. a `PropertyAccess(target=Identifier('AppRoutes'),
  /// propertyName=Identifier('<branchRoot>'))` (3+ segment chains
  /// land here as `app.AppRoutes.home`) OR a
  /// `PrefixedIdentifier(prefix=Identifier('AppRoutes'),
  /// identifier=Identifier('<branchRoot>'))` (the simple two-segment
  /// form for `AppRoutes.home` in `analyzer ^6.11.0`). The
  /// underlying `<branchRoot>` must be one of
  /// `home|worlds|gallery|shop|profile`. String-literal routes
  /// (`context.go('/home')`) are deliberately NOT flagged — they're
  /// a different antipattern (hard-coded path strings) that lives in
  /// a future lint rule, not this one.
  ///
  /// **Pattern B — bare extension call**
  /// `context.goHome|goWorlds|goGallery|goShop|goProfile()`. The
  /// list of names comes from
  /// `core/routing/app_router.dart::GoRouterContextX` —
  /// `GoRouter` extension methods on `BuildContext` that forward
  /// straight into `context.go(AppRoutes.<...>)`.
  ///
  /// The two patterns are mutually exclusive in practice (Pattern A
  /// matches `go(...)`, Pattern B matches `goHome()` etc.) so they
  /// share the same single return path.
  @visibleForTesting
  static bool shouldFlag(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (methodName == 'go' &&
        node.argumentList.arguments.isNotEmpty) {
      final String? branchRoot = _readAppRoutesBranchRoot(
        node.argumentList.arguments.first,
      );
      if (branchRoot != null) return true;
    }
    return _shellBareMethods.contains(methodName);
  }

  /// Returns `<branchRoot>` iff [expr] is the AST shape
  /// `AppRoutes.home|worlds|gallery|shop|profile`. Otherwise `null`.
  /// Strict pattern-match — we do NOT heuristically resolve the receiver
  /// type; the rule is statically identifiable and the contributors
  /// always import `app_routes.dart show AppRoutes` un-renamed.
  /// Aliased imports (`app.AppRoutes.home`) are deliberately NOT
  /// covered because the receiver becomes `app.AppRoutes` (a chained
  /// access), not a bare `Identifier('AppRoutes')`, so the
  /// `receiver is! Identifier` cast fails and the diagnostic is
  /// suppressed. If the project ever adopts `import ... as app;` for
  /// app_routes, update this check accordingly.
  ///
  /// AST-shape probe accepts both modern `PropertyAccess` AND legacy
  /// `PrefixedIdentifier`. `analyzer ^6.11.0` keeps both forms in the
  /// spec: simple `a.b` where `a` is a `SimpleIdentifier` parses as
  /// `PrefixedIdentifier(prefix=a, identifier=b)`, while `a.b.c`
  /// (3-segment) parses as
  /// `PropertyAccess(target=PrefixedIdentifier('a','b'),
  /// propertyName='c')`. We accept the leaf-shape from either form
  /// and test the receiver-cast uniformly.
  static String? _readAppRoutesBranchRoot(Expression expr) {
    // Probe both AST shapes. The leaf (right-most identifier) is what
    // we compare against `_shellRoots`; the receiver (left side) is
    // what we hard-pin to the bare `AppRoutes` identifier.
    //
    // `expr.target`/`expr.prefix` are nullable in `analyzer ^6.x`'s
    // AST spec even though in practice they're always set for the
    // chains we care about — accept `Expression?` and forward-defend
    // the null case.
    final Identifier leaf;
    final Expression? receiver;
    if (expr is PropertyAccess) {
      leaf = expr.propertyName;
      receiver = expr.target;
    } else if (expr is PrefixedIdentifier) {
      leaf = expr.identifier;
      receiver = expr.prefix;
    } else {
      return null;
    }
    if (receiver == null) return null;
    if (!_shellRoots.contains(leaf.name)) return null;
    // Strict receiver — only matches `AppRoutes.<branch>`. Aliased
    // imports (`app.AppRoutes.home`) parse with `receiver` as a
    // chained `PrefixedIdentifier`/`PropertyAccess` on `app.AppRoutes`,
    // so the `receiver is! Identifier` cast rejects both. Same for
    // completely different surface expressions that happen to land
    // at this branch (e.g. `Config.home`).
    if (receiver is! Identifier || receiver.name != 'AppRoutes') {
      return null;
    }
    return leaf.name;
  }
}
