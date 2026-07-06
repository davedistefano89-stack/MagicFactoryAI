// =============================================================================
// Magic Colors · features/gallery/presentation/gallery_screen.dart
// =============================================================================
//
// The Gallery shell branch destination. Shows every saved drawing as a
// large MagicCard tile in a responsive grid. Kids can:
//
//   ▸ Tap a tile → reopens the drawing in the full-screen Coloring canvas.
//   ▸ Long-press a tile → delete confirmation dialog (undo-safe: the
//     drawing is only hard-deleted after the parent confirms).
//
// Empty state: a friendly mascot prompt encouraging the child to paint
// something first.
//
// DATA SOURCE
//   Reads from the `drawings` Hive box via `StorageService.drawingsBox`
//   (provided at the root of the widget tree). The `ColoringRepository`
//   facade keeps Hive internals out of the UI layer.
//
// RESPONSIVE
//   • Phone portrait  → 2 columns
//   • Tablet portrait → 3 columns
//   • Tablet landscape → 4 columns
//
// DESIGN TOKENS
//   Colour palette, spacing, and typography strictly follow the
//   `AppColors` / `AppSpacing` / `AppTypography` token catalogue.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/routing/app_router.dart' show GoRouterContextX;
import '../../../core/services/analytics_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/state/navigation_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/magic_card.dart';
import 'package:hive_flutter/hive_flutter.dart' show Box;

import '../../../features/coloring/data/coloring_repository.dart';
import '../../../features/coloring/domain/drawing.dart';

// ── Tuning constants ──────────────────────────────────────────────────

/// Tile corner radius — matches the World Map island cards so the
/// visual language stays consistent across tabs. Uses the shared
/// token directly rather than a local const to avoid double-definition
/// drift.
const BorderRadius _kTileRadius = AppCorner.brLg;

/// Emoji glyph size inside each tile.
const double _kTileGlyphSize = 56.0;

/// Tile aspect ratio (width : height). Slightly taller than square so
/// the emoji + label + date stack doesn't feel cramped.
const double _kTileAspectRatio = 0.92;

/// Empty-state illustration glyph.
const String _kEmptyGlyph = '🎨';

/// Empty-state title.
const String _kEmptyTitle = 'No drawings yet!';

/// Sprint 4b — minimal id → title lookup so the filter banner can
/// render a human-readable world name. The full catalog lives in
/// `world_map_screen.dart` / `world_detail_screen.dart` (both file-
/// private); the Sprint 4c catalog lift into `core/data/world_catalog.dart`
/// will replace this with a shared helper.
const Map<String, String> _kWorldIdToTitle = <String, String>{
  'princess_kingdom': 'Princess Kingdom',
  'unicorn_valley': 'Unicorn Valley',
  'animal_forest': 'Animal Forest',
  'dinosaur_island': 'Dinosaur Island',
  'dragon_mountain': 'Dragon Mountain',
  'mermaid_ocean': 'Mermaid Ocean',
  'space_planet': 'Space Planet',
  'christmas_village': 'Christmas Village',
  'halloween_world': 'Halloween World',
  'fantasy_land': 'Fantasy Land',
  'unknown': 'Untitled',
};

/// Empty-state caption.
const String _kEmptyCaption =
    'Tap PLAY NOW on the home screen to start your first masterpiece. '
    'Every drawing you save will appear here.';

/// Screen semantic label.
const String _kSemanticsRootLabel = 'My drawings gallery';

// =============================================================================
//  GalleryScreen — the public widget.
// =============================================================================

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<Drawing> _drawings = <Drawing>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final Box<dynamic> box = context.read<StorageService>().drawingsBox;
    // Sprint 4b — read the gallery filter from NavigationState. The
    // filter is ephemeral (process-lifetime only), so a "show me all
    // drawings" tap simply re-loads without the filter. We read
    // before the demo seed so the seed is unaffected (the demo
    // drawing is always inserted with worldId='unicorn_valley' — if
    // the kid is filtering by another world, the seed will simply
    // not appear in the filtered view, which is the correct UX).
    final NavigationState nav = context.read<NavigationState>();
    final String? filterWorldId = nav.galleryFilterWorldId;

    // ── DEMO SEED (remove before production) ──────────────────────────
    // Seeds one demo drawing so the Gallery shows a populated card.
    // Only runs the very first time (when the box is completely empty
    // AND the demo id doesn't already exist — prevents re-seeding).
    const String demoId = 'demo-unicorn-001';
    if (ColoringRepository.listAll(box).isEmpty &&
        ColoringRepository.findById(box, demoId) == null) {
      final Drawing demo = Drawing.fresh(
        id: demoId,
        worldId: 'unicorn_valley',
        templateGlyph: '🦄',
        name: 'My First Drawing',
        paletteRevision: 1,
      );
      ColoringRepository.save(box, demo);
    }
    // ── END DEMO SEED ────────────────────────────────────────────────

    final List<Drawing> all = ColoringRepository.listAll(box);
    // Sprint 4b — apply the gallery filter. A null filterWorldId
    // means "show all worlds" (the default). Any non-null value
    // narrows the list to that single world.
    final List<Drawing> filtered = filterWorldId == null
        ? all
        : all.where((Drawing d) => d.worldId == filterWorldId).toList();
    // Sort newest first so the kid's latest creation is always at the top.
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    setState(() {
      _drawings = filtered;
      _activeFilterWorldId = filterWorldId;
    });
  }

  /// Sprint 4b — the active filter the most recent [_load] applied.
  /// Mirrored to a field so [build] can render the filter banner
  /// without racing the post-frame [_load] (which re-fires on every
  /// build, including the first one where the field is still null).
  String? _activeFilterWorldId;

  /// Sprint 4b — clears the gallery filter from NavigationState and
  /// re-loads so the kid sees every world again. Wired to the
  /// "Clear filter" button on [_GalleryFilterBanner].
  void _clearFilter() {
    AnalyticsService.instance.trackEvent('gallery_filter_cleared');
    context.read<NavigationState>().setGalleryFilterWorldId(null);
    _load();
  }

  /// Sprint 4b — resolves a worldId to its catalog title. Falls back
  /// to the raw id when the catalog has no match (handles future
  /// worlds that the kid drew against but aren't in the v1.0
  /// catalog yet).
  String? _filterTitle() {
    final String? worldId = _activeFilterWorldId;
    if (worldId == null) return null;
    return _kWorldIdToTitle[worldId] ?? worldId;
  }

  Future<void> _deleteDrawing(Drawing drawing) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete drawing?'),
        content: Text(
          'Are you sure you want to delete "${drawing.name}"? '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.tangerine,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final Box<dynamic> box = context.read<StorageService>().drawingsBox;
    ColoringRepository.deleteById(box, drawing.id);
    AnalyticsService.instance.trackEvent(
      'gallery_delete_drawing',
      <String, Object?>{'id': drawing.id},
    );
    Haptics.medium();
    _load();
  }

  void _openDrawing(Drawing drawing) {
    // M3 swap: tap now opens the gallery drill-down (timeline, colours
    // used, badges earned). The full-screen Coloring canvas re-entry
    // point lives inside the detail screen as a "Resume Coloring" CTA
    // so the child sees their drawing's history before they resume
    // painting. The canvas path itself is unchanged — it just moved
    // one level deeper.
    AnalyticsService.instance.trackEvent(
      'gallery_open_detail',
      <String, Object?>{'id': drawing.id, 'name': drawing.name},
    );
    Haptics.light();
    context.goGalleryDetail(drawing.id);
  }

  @override
  Widget build(BuildContext context) {
    // Refresh on every build so the gallery updates when returning
    // from the Coloring screen (full-screen route over the shell).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
    final String? filterTitle = _filterTitle();
    return AnimatedBackground(
      child: SafeArea(
        bottom: false,
        child: _drawings.isEmpty
            ? (filterTitle == null
                ? const _EmptyState()
                : _GalleryEmptyForFilter(
                    title: filterTitle,
                    onClear: _clearFilter,
                  ))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (filterTitle != null)
                    _GalleryFilterBanner(
                      worldTitle: filterTitle,
                      onClear: _clearFilter,
                    ),
                  Expanded(
                    child: _GalleryGrid(
                      drawings: _drawings,
                      onTap: _openDrawing,
                      onLongPress: _deleteDrawing,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// =============================================================================
//  _GalleryFilterBanner — Sprint 4b. Renders at the top of the Gallery
//  when a world filter is active. Shows the world glyph + title + a
//  "Clear filter" pill that drops the filter and re-loads.
// =============================================================================

class _GalleryFilterBanner extends StatelessWidget {
  const _GalleryFilterBanner({
    required this.worldTitle,
    required this.onClear,
  });

  final String worldTitle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Gallery filtered to $worldTitle',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xs,
        ),
        child: MagicCard(
          skin: MagicCardSkin.tinted,
          borderRadius: AppCorner.brLg,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          borderColor: AppColors.magicPurple.withValues(alpha: 0.20),
          child: Row(
            children: <Widget>[
              const Text('🎨', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'My drawings in $worldTitle',
                  style: AppTypography.titleSm,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.magicPink,
                    borderRadius: AppCorner.pill,
                  ),
                  child: const Text(
                    'Clear filter',
                    style: TextStyle(
                      color: AppColors.cloudWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  _GalleryEmptyForFilter — Sprint 4b. Rendered when a filter is active
//  and zero drawings match. Offers a clear-filter CTA so the kid can
//  get back to the full gallery without backing out of the screen.
// =============================================================================

class _GalleryEmptyForFilter extends StatelessWidget {
  const _GalleryEmptyForFilter({
    required this.title,
    required this.onClear,
  });

  final String title;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('🎨', style: TextStyle(fontSize: 64)),
            AppSpacing.vGapMd,
            Text(
              'No drawings yet in $title',
              style: AppTypography.titleMd,
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapMd,
            Text(
              'Start a drawing from the world map to fill this collection.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.smoke,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapLg,
            FilledButton(
              onPressed: onClear,
              child: const Text('Show all drawings'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  _EmptyState — friendly prompt shown when no drawings are saved yet.
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(_kEmptyGlyph, style: TextStyle(fontSize: 72)),
            AppSpacing.vGapLg,
            Text(
              _kEmptyTitle,
              style: AppTypography.titleMd,
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapMd,
            Text(
              _kEmptyCaption,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.smoke,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  _GalleryGrid — responsive grid of drawing tiles.
// =============================================================================

class _GalleryGrid extends StatelessWidget {
  const _GalleryGrid({
    required this.drawings,
    required this.onTap,
    required this.onLongPress,
  });

  final List<Drawing> drawings;
  final ValueChanged<Drawing> onTap;
  final ValueChanged<Drawing> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _kSemanticsRootLabel,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Text(
              'My Drawings',
              style: AppTypography.titleLg,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columns = _resolveColumns(constraints.maxWidth);
                const double spacing = AppSpacing.sm;
                final double tileWidth =
                    (constraints.maxWidth - spacing * (columns + 1)) / columns;
                final double tileHeight = tileWidth / _kTileAspectRatio;

                return GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: tileHeight,
                  ),
                  itemCount: drawings.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _DrawingTile(
                      drawing: drawings[index],
                      onTap: () => onTap(drawings[index]),
                      onLongPress: () => onLongPress(drawings[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static int _resolveColumns(double viewportWidth) {
    if (viewportWidth < 600) return 2;
    if (viewportWidth < 900) return 3;
    return 4;
  }
}

// =============================================================================
//  _DrawingTile — single drawing card with emoji + name + date.
// =============================================================================

class _DrawingTile extends StatelessWidget {
  const _DrawingTile({
    required this.drawing,
    required this.onTap,
    required this.onLongPress,
  });

  final Drawing drawing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final String glyph =
        drawing.templateGlyph.isNotEmpty ? drawing.templateGlyph : '🖼';
    final String formattedDate = _formatDate(drawing.updatedAt);

    return Semantics(
      button: true,
      label: 'Drawing: ${drawing.name}, last edited $formattedDate',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: MagicCard(
          skin: MagicCardSkin.tinted,
          borderRadius: _kTileRadius,
          padding: AppSpacing.cardPaddingTight,
          borderColor: AppColors.magicPurple.withValues(alpha: 0.18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Spacer(),
              Text(
                glyph,
                style: const TextStyle(fontSize: _kTileGlyphSize),
              ),
              const Spacer(),
              Text(
                drawing.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.titleSm.copyWith(fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formattedDate,
                style: AppTypography.caption(
                  color: AppColors.smoke,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
