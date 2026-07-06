// =============================================================================
// Magic Colors · features/coloring/coloring_screen.dart
// =============================================================================
//
// The /coloring/:id destination. Owns ONE [ColoringController] for the
// duration of the screen (ChangeNotifierProvider.scoped). When the
// screen pops, the controller's `dispose()` flushes any pending save.
//
// LAYOUT
// ------
//   ┌────────────────────────────────────────┐
//   │   ColoringTopBar (back, title, status) │
//   ├────────────────────────────────────────┤
//   │                                        │
//   │       ColoringCanvas (expanded)        │
//   │                                        │
//   ├────────────────────────────────────────┤
//   │   ColoringBrushPicker (chips + size)   │
//   │   ColoringPalette   (6×4 grid)         │
//   │   ColoringToolbar  (undo / redo / !!)  │
//   └────────────────────────────────────────┘
//
// Back behaviour: force-flush the controller, then pop the route. If
// there's no route to pop (deep-link cold start), we goWorlds so the
// child is never stranded.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouter;
import 'package:provider/provider.dart';

import 'package:magic_colors/core/routing/app_router.dart'
    show GoRouterContextX;
import 'package:magic_colors/core/services/sound_service.dart';
import 'package:magic_colors/core/services/storage_service.dart';
import 'package:magic_colors/core/state/navigation_state.dart';
import 'package:magic_colors/core/state/settings_state.dart';
import 'package:magic_colors/core/widgets/animated_background.dart';
import 'package:magic_colors/core/theme/app_gradients.dart';

import 'coloring_controller.dart';
import 'state/view_transform_controller.dart';
import 'widgets/coloring_brush_picker.dart';
import 'widgets/coloring_canvas.dart';
import 'widgets/coloring_palette.dart';
import 'widgets/coloring_toolbar.dart';
import 'widgets/coloring_top_bar.dart';
import 'widgets/drawing_complete_overlay.dart';

// ── Catalog of starter drawings keyed by the :id URL param. ────────────

/// Small lookup so WorldDetailScreen's `context.goColoring(_kDefaultDrawingId)`
/// resolves to a sensible starting world + glyph when the index is not
/// persisted yet.
class _StarterDrawing {
  const _StarterDrawing(this.worldId, this.templateGlyph, this.title);
  final String worldId;
  final String templateGlyph;
  final String title;
}

const Map<String, _StarterDrawing> _kStarterDrawings =
    <String, _StarterDrawing>{
  'draw-now': _StarterDrawing('world_default', '🦄', 'Untitled drawing'),
  'unicorn_default': _StarterDrawing(
    'unicorn_valley',
    '🦄',
    'Unicorn Valley',
  ),
  'forest_default': _StarterDrawing('animal_forest', '🦒', 'Animal Forest'),
  'dino_default': _StarterDrawing('dinosaur_island', '🦖', 'Dinosaur Island'),
  'dragon_default': _StarterDrawing('dragon_mountain', '🐉', 'Dragon Mountain'),
  'mermaid_default': _StarterDrawing('mermaid_ocean', '🧜', 'Mermaid Ocean'),
  'castle_default': _StarterDrawing(
    'princess_kingdom',
    '👑',
    'Princess Kingdom',
  ),
  'space_default': _StarterDrawing('space_planet', '🚀', 'Space Planet'),
};

_StarterDrawing _resolveStarter(String drawingId) {
  return _kStarterDrawings[drawingId] ??
      const _StarterDrawing(
        'unknown',
        '',
        'Untitled drawing',
      );
}

// =============================================================================
//  ColoringScreen.
// =============================================================================

class ColoringScreen extends StatefulWidget {
  const ColoringScreen({
    super.key,
    this.drawingId = 'draw-now',
  });

  /// URL path parameter injected by the AppRouter. Defaults to the
  /// hardcoded "draw-now" sentinel so a deep-link that misses the
  /// parameter still lands somewhere drawable.
  final String drawingId;

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final StorageService storage = context.read<StorageService>();
    final SoundService sound = context.read<SoundService>();

    final _StarterDrawing starter = _resolveStarter(widget.drawingId);

    return ChangeNotifierProvider<ViewTransformController>(
      // M2.1 — owns the canvas view-matrix state (pinch zoom + 2-finger
      // pan). Provided BEFORE ColoringController so the canvas widget
      // finds it in the tree on first paint without missing a frame.
      create: (_) => ViewTransformController(),
      child: ChangeNotifierProvider<ColoringController>(
        create: (_) => ColoringController(
          box: storage.drawingsBox,
          sound: sound,
          drawingId: widget.drawingId,
          worldId: starter.worldId,
          templateGlyph: starter.templateGlyph,
          drawingName: starter.title,
          vsync: this,
        ),
        child: _ColoringNavigationSync(
          worldId: starter.worldId,
          child: const _ColoringScreenBody(),
        ),
      ),
    );
  }
}

// =============================================================================
//  _ColoringScreenBody — lays out chrome around the canvas.
// =============================================================================

class _ColoringScreenBody extends StatefulWidget {
  const _ColoringScreenBody();

  @override
  State<_ColoringScreenBody> createState() => _ColoringScreenBodyState();
}

/// Sprint 4b — small wrapper that stamps NavigationState.currentWorldId
/// for the lifetime of the coloring screen. Disposes the stamp on
/// pop so the world map's "you are here" highlight follows the kid's
/// actual location, not the last screen they backed out of.
class _ColoringNavigationSync extends StatefulWidget {
  const _ColoringNavigationSync({required this.worldId, required this.child});

  final String worldId;
  final Widget child;

  @override
  State<_ColoringNavigationSync> createState() =>
      _ColoringNavigationSyncState();
}

class _ColoringNavigationSyncState extends State<_ColoringNavigationSync> {
  /// Captured in [didChangeDependencies] for use in [dispose].
  /// Nullable because didChangeDependencies may not have fired yet
  /// when dispose runs on a screen that was built but never painted
  /// (rare, but possible on hot-reload). The captured reference
  /// replaces the previous try/catch around `context.read` in
  /// dispose — `context` is unreliable in dispose (Provider scope
  /// can already be torn down), and the broad `on Object` catch
  /// hid real bugs.
  NavigationState? _nav;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nav = context.read<NavigationState>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NavigationState>().setCurrentWorldId(widget.worldId);
    });
  }

  @override
  void dispose() {
    _nav?.setCurrentWorldId(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ColoringScreenBodyState extends State<_ColoringScreenBody> {
  /// Set to true after we've already shown this session's
  /// [DrawingCompleteOverlay]; ensures we don't pop a second overlay
  /// for the same reward.
  bool _rewardShownThisSession = false;

  void _onBack(BuildContext context) {
    final ColoringController controller = context.read<ColoringController>();
    controller.forceSave();

    // If we have something to pop, pop. Otherwise deep-link started the
    // screen — drop the child into the Worlds tab so they don't get
    // stranded on a half-drawn canvas.
    final GoRouter router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    // Out-of-shell takeover route: /coloring/:id is a top-level push
    // route, NOT a descendant of `_BranchScaffold`. The
    // `StatefulNavigationShell` Provider is therefore not in this
    // widget's context tree, so `selectShellTab` + `goShellTab` would
    // throw `ProviderNotFoundException`. Keep the bare
    // `context.goWorlds()` — GoRouter handles the transition by
    // building the StatefulShellRoute, which mounts a fresh shell
    // and the Worlds-tab root. If preserving the prior Worlds-stack
    // from this entry point ever matters, lift the shell Provider into
    // the app shell (`lib/app.dart`) so every screen can read it.
    // ignore: shell_branch_nav (out-of-shell deep-link recovery —
    // /coloring/:id is a top-level push route; the shell Provider
    // never made it into this widget's tree).
    context.goWorlds();
  }

  void _maybeShowRewardOverlay(BuildContext context, ColoringController c) {
    if (!c.hasUnacknowledgedReward) return;
    if (_rewardShownThisSession) return;
    _rewardShownThisSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => DrawingCompleteOverlay(
          title: 'WOW!',
          subtitle: c.lastRewardCoinDelta > 0 || c.lastRewardGemDelta > 0
              ? 'Your drawing earned stars — and the parent got coins for the gallery.'
              : 'Your drawing earned stars in ${c.worldId}.',
          coinDelta: c.lastRewardCoinDelta,
          gemDelta: c.lastRewardGemDelta,
          onDone: () {
            Navigator.of(ctx).pop();
            c.acknowledgeReward();
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      gradient: AppGradients.skyDefault,
      child: Consumer<ColoringController>(
        builder: (BuildContext context, ColoringController c, Widget? _) {
          // M2.4 — once the controller flips [hasUnacknowledgedReward]
          // true, pop the success overlay on the next frame.
          _maybeShowRewardOverlay(context, c);
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _topBar(context, c),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 4.0,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFBFF),
                        borderRadius: BorderRadius.circular(28.0),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28.0),
                        child: ColoringCanvas(
                          controller: c,
                          color: c.selectedColor,
                          isDarkSurface: false,
                        ),
                      ),
                    ),
                  ),
                ),
                _bottomDock(context, c),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _topBar(BuildContext context, ColoringController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 4.0, 12.0, 4.0),
      child: ColoringTopBar(
        controller: controller,
        onBack: () => _onBack(context),
      ),
    );
  }

  Widget _bottomDock(BuildContext context, ColoringController controller) {
    return Consumer<SettingsState>(
      builder: (BuildContext context, SettingsState settings, Widget? _) {
        return Padding(
          // Top-room 4 dp gives the card breathing space off the
          // canvas frame; bottom = 8 dp visual padding (SafeArea already
          // injected the system gesture inset).
          padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 8.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFF).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28.0),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ColoringBrushPicker(controller: controller),
                  const SizedBox(height: 10.0),
                  ColoringPalette(controller: controller),
                  const SizedBox(height: 10.0),
                  ColoringToolbar(controller: controller),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
//  Notes.
// =============================================================================
//
// The default BrushType for a fresh canvas is round (BrushType.values[0]).
// The starter canvas pre-selects the magenta swatch at index 8 of
// [PaletteCatalog.colors]. ColorSwatchGrid applies the selection ring
// immediately so the user sees their brush before the first stroke.
