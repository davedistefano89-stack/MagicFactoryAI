// =============================================================================
// Magic Colors · tools/lint/lib/magic_colors_lint.dart
// =============================================================================
// Plugin entry point consumed by the analyzer via the
// `analyzer.plugins` block in `analysis_options.yaml`. The plugin
// subclass implements `getLintRules(configs)` — the analyzer calls this
// once per analysis session WITH the user's resolved
// `CustomLintConfigs`, so each rule can opt in/out per file pattern.

import 'package:custom_lint_core/custom_lint_core.dart';

import 'src/shell_branch_nav_lint.dart';

/// Top-level export registered with `analyzer.plugins`.
///
/// Adding a rule is a one-line job: implement a `LintRule`, append it
/// to [getLintRules]'s return list, wire `analysis_options.yaml`
/// (`custom_lint.rules` + `analyzer.plugins`) and the rule goes live
/// for `flutter analyze`.
class MagicColorsLintPlugin extends PluginBase {
  /// `CustomLintConfigs` is the per-rule enabled/disabled state — for
  /// v1.0 every rule is unconditional so the function ignores the
  /// `configs` arg. When per-file fine-tuning lands (e.g. loosen the
  /// rule for legacy test fixtures), read the rule's enable state
  /// from `configs.rules['shell_branch_nav']` here.
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) =>
      const <LintRule>[
        ShellBranchNavLint(),
      ];
}
