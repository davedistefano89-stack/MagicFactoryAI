// =============================================================================
// Magic Colors · features/gallery/presentation/drawing_detail_screen.dart
// =============================================================================
//
// M3 — Gallery drill-down destination. Routed at `/gallery/:id`, lives
// under the Gallery bottom-nav branch so the chrome stays visible while
// the child inspects a single drawing.
//
// SECTIONS
//   ▸ Header card      — glyph + name + worldId chip + created / updated
//                        timestamps formatted for a 4th-grade reader.
//   ▸ Stats row        — at-a-glance counts: total commands, draw-strokes,
//                        flood-fill areas, unique colour VALUES used,
//                        world-stars earned for this drawing's worldId.
//   ▸ Timeline         — chronological milestones (created → last edit)
//                        rendered as a vertical dot-rail.
//   ▸ Colors used      — distinct [PaintCommand.colorValue] ints (ARGB)
//                        across strokes + fills, plus flood-fill coverage.
//                        Mirrors the kid's "how many colors did I use?"
//                        mental model. NOTE: we intentionally drop the
//                        original `paletteRevision` derivation — that
//                        field is a *catalog version stamp*, NOT a
//                        per-stroke color id, so showing it would have
//                        been misleading (almost always "1" in practice).
//   ▸ Your badges      — chip cloud of [AchievementDefinition]s whose id
//                        is in [PlayerState.unlockedAchievementIds], with
//                        tier (bronze / silver / gold) colour cues.
//                        Honestly labelled "Your badges" — the catalog
//                        has no per-drawingId link, so this is the player's
//                        cross-drawing collection (NOT "earned on this
//                        drawing"). Per-drawing signal lives in the stats
//                        row's world-stars tile.
//   ▸ Sticky CTA       — "Resume Coloring" (replaces the gallery tile's
//                        old tap behavior) + a "Delete" danger button
//                        that mirrors the gallery tile's long-press.
//
// DATA SOURCES
//   • [Drawing] (Hive box `drawings`, surfaced via `ColoringRepository`).
//   • [PlayerState] for `unlockedAchievementIds` + `worldStars[worldId]`.
//   • `AchievementService.catalog` for the 12-achievement global catalog.
//
// NOT IN SCOPE (M3 polish, future)
//   • Canvas thumbnail of the drawing strokes. The header glyph anchors
//     identity; a re-render of [commands] through the paint pipeline is
//     a separate ticket once we decide on a snapshot strategy.
//   • Per-event stroke timestamps — `Drawing` only stores createdAt +
//     updatedAt. A future "chronological playback" feature would extend
//     the model with `List<int> commandTimestamps`.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/routing/app_router.dart' show GoRouterContextX;
import '../../../core/services/analytics_service.dart';
import '../../../core/services/economy/achievement_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/state/player_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/magic_card.dart';
import 'package:hive_flutter/hive_flutter.dart' show Box;

import '../../coloring/data/coloring_repository.dart';
import '../../coloring/domain/drawing.dart';
import '../../coloring/domain/paint_command.dart';

// ── Tuning constants ──────────────────────────────────────────────────

/// Hero glyph size in the header card. Larger than the gallery tile so
/// the pulled-into-detail moment reads as "look closer".
const double _kHeroGlyphSize = 96.0;

/// Section header padding from screen edge.
const EdgeInsets _kSectionPadding = EdgeInsets.fromLTRB(
  AppSpacing.xl,
  AppSpacing.lg,
  AppSpacing.xl,
  AppSpacing.sm,
);

/// Vertical gap between consecutive sections (matches gallery list rhythm).
const SizedBox _kSectionGap = SizedBox(height: AppSpacing.md);

/// Screen semantic label.
const String _kSemanticsRootLabel = 'Drawing details';

/// Chip-cloud padding.
const EdgeInsets _kChipRunPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.lg,
);

// =============================================================================
//  DrawingDetailScreen — the public widget.
// =============================================================================

class DrawingDetailScreen extends StatefulWidget {
  const DrawingDetailScreen({super.key, required this.drawingId});

  /// URL-supplied drawing id. Comes from `state.pathParameters['id']`
  /// in the router's nested GoRoute. Empty string falls through to a
  /// "not found" body.
  final String drawingId;

  @override
  State<DrawingDetailScreen> createState() => _DrawingDetailScreenState();
}

class _DrawingDetailScreenState extends State<DrawingDetailScreen> {
  Drawing? _drawing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    if (widget.drawingId.isEmpty) {
      setState(() => _drawing = null);
      return;
    }
    final Box<dynamic> box = context.read<StorageService>().drawingsBox;
    final Drawing? found = ColoringRepository.findById(box, widget.drawingId);
    // If the id is unknown we still want to surface a friendly "not
    // found" body — return null so [build] can branch.
    setState(() => _drawing = found);
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
      <String, Object?>{'id': drawing.id, 'source': 'detail'},
    );
    Haptics.medium();
    if (!mounted) return;
    // Pop back to the Gallery grid so the kid sees the tile disappear.
    context.goGallery();
  }

  void _resumeColoring(Drawing drawing) {
    AnalyticsService.instance.trackEvent(
      'gallery_resume_coloring',
      <String, Object?>{
        'id': drawing.id,
        'source': 'detail',
        'command_count': drawing.effectiveCommands.length,
      },
    );
    Haptics.light();
    context.goColoring(drawing.id);
  }

  @override
  Widget build(BuildContext context) {
    // Refresh on every build so the detail re-syncs after the kid taps
    // "Resume Coloring", makes edits, and pops back through the same
    // shell branch. The StatefulNavigationShell at index 2 preserves
    // the /gallery/:id route across the /coloring/:id push, so the
    // widget is NOT remounted on the round-trip — without this hook
    // the screen would show stale updatedAt + stale command counts.
    // Pattern matches `gallery_screen.dart:_load` postFrame refresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
    return AnimatedBackground(
      child: SafeArea(
        bottom: false,
        child: _drawing == null
            ? const _NotFoundBody()
            : Semantics(
                label: _kSemanticsRootLabel,
                container: true,
                child: _Content(
                  drawing: _drawing!,
                  onResume: () => _resumeColoring(_drawing!),
                  onDelete: () => _deleteDrawing(_drawing!),
                ),
              ),
      ),
    );
  }
}

// =============================================================================
//  _Content — builds the actual sections; pure layout, no state.
// =============================================================================

class _Content extends StatelessWidget {
  const _Content({
    required this.drawing,
    required this.onResume,
    required this.onDelete,
  });

  final Drawing drawing;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final PlayerState player = context.watch<PlayerState>();
    final List<AchievementDefinition> catalog = AchievementService.catalog;
    final Set<String> unlocked = player.unlockedAchievementIds;
    final List<AchievementDefinition> earnedBadges = catalog
        .where((AchievementDefinition a) => unlocked.contains(a.id))
        .toList(growable: false);
    final List<PaintCommand> commands = drawing.effectiveCommands;
    final int drawStrokeCount = commands.whereType<DrawStroke>().length;
    final int floodFillCount = commands.whereType<FillRegion>().length;
    // Unique colour VALUE (ARGB int) across both DrawStroke + FillRegion.
    // Reads through PaintCommand.colorValue so the math includes both
    // stroke colours and the fill colours, which matches a kid's
    // mental model: "I used N different colours".
    final Set<int> uniqueColors = commands
        .map((PaintCommand c) => c.colorValue)
        .toSet();
    final int worldStars = player.getWorldStars(drawing.worldId);

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: <Widget>[
              _HeaderCard(drawing: drawing),
              _kSectionGap,
              _StatsRow(
                commandCount: commands.length,
                strokeCount: drawStrokeCount,
                floodFillCount: floodFillCount,
                uniqueColors: uniqueColors.length,
                worldStars: worldStars,
              ),
              _kSectionGap,
              _TimelineSection(drawing: drawing),
              _kSectionGap,
              _ColorsUsedSection(
                uniqueColors: uniqueColors.length,
                floodFillCount: floodFillCount,
                strokeCount: drawStrokeCount,
              ),
              _kSectionGap,
              _BadgesCollectionSection(badges: earnedBadges),
              _kSectionGap,
            ],
          ),
        ),
        _BottomActionBar(
          onResume: onResume,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

// =============================================================================
//  _HeaderCard — glyph + name + worldId chip + created/updated dates.
// =============================================================================

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.drawing});

  final Drawing drawing;

  @override
  Widget build(BuildContext context) {
    final String glyph =
        drawing.templateGlyph.isNotEmpty ? drawing.templateGlyph : '🖼';
    return Padding(
      padding: _kSectionPadding,
      child: MagicCard(
        skin: MagicCardSkin.tinted,
        borderRadius: AppCorner.brLg,
        padding: AppSpacing.cardPaddingTight,
        borderColor: AppColors.magicPurple.withValues(alpha: 0.18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(glyph, style: const TextStyle(fontSize: _kHeroGlyphSize)),
            AppSpacing.vGapSm,
            Text(
              drawing.name,
              style: AppTypography.titleLg,
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapSm,
            _WorldChip(worldId: drawing.worldId),
            AppSpacing.vGapMd,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _DatePill(
                  label: 'Created',
                  date: drawing.createdAt,
                ),
                _DatePill(
                  label: 'Updated',
                  date: drawing.updatedAt,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldChip extends StatelessWidget {
  const _WorldChip({required this.worldId});

  final String worldId;

  @override
  Widget build(BuildContext context) {
    // Pretty-print the slug: unicorn_valley → Unicorn Valley.
    final String pretty = worldId
        .split('_')
        .map((String part) =>
            part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.magicPurple.withValues(alpha: 0.12),
        borderRadius: AppCorner.pill,
      ),
      child: Text(
        pretty,
        style: AppTypography.caption(color: AppColors.magicPurple),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label, required this.date});

  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(label, style: AppTypography.caption(color: AppColors.smoke)),
        SizedBox(height: AppSpacing.xs),
        Text(_formatDate(date), style: AppTypography.bodyMedium),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// =============================================================================
//  _StatsRow — five counters: commands, strokes, fills, unique colours,
//  world stars.
// =============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.commandCount,
    required this.strokeCount,
    required this.floodFillCount,
    required this.uniqueColors,
    required this.worldStars,
  });

  final int commandCount;
  final int strokeCount;
  final int floodFillCount;
  final int uniqueColors;
  final int worldStars;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _kSectionPadding,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          _StatChip(
            glyph: '✏️',
            value: '$commandCount',
            label: 'commands',
          ),
          _StatChip(
            glyph: '🖍️',
            value: '$strokeCount',
            label: 'strokes',
          ),
          _StatChip(
            glyph: '🪣',
            value: '$floodFillCount',
            label: 'fills',
          ),
          _StatChip(
            glyph: '🎨',
            value: '$uniqueColors',
            label: 'colours',
          ),
          _StatChip(
            glyph: '⭐',
            value: '$worldStars',
            label: 'world stars',
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.glyph,
    required this.value,
    required this.label,
  });

  final String glyph;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      skin: MagicCardSkin.blank,
      borderRadius: AppCorner.brMd,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderColor: AppColors.magicPurple.withValues(alpha: 0.12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(glyph, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.xs),
          Text(value, style: AppTypography.titleSm),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTypography.caption(color: AppColors.smoke)),
        ],
      ),
    );
  }
}

// =============================================================================
//  _TimelineSection — vertical dot-rail of milestones.
// =============================================================================

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.drawing});

  final Drawing drawing;

  @override
  Widget build(BuildContext context) {
    final List<_TimelineEvent> events = _buildEvents(drawing);
    return Padding(
      padding: _kSectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Timeline', style: AppTypography.titleMd),
          AppSpacing.vGapSm,
          MagicCard(
            skin: MagicCardSkin.blank,
            borderRadius: AppCorner.brLg,
            padding: AppSpacing.cardPaddingTight,
            borderColor: AppColors.magicPurple.withValues(alpha: 0.12),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < events.length; i++)
                  _TimelineRow(
                    event: events[i],
                    isLast: i == events.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<_TimelineEvent> _buildEvents(Drawing drawing) {
    // NOTE: there is no "About now" terminal event. A `DateTime.now()`
    // capture inside the build closure re-runs on every PlayerState
    // notify, so any re-render would shift the relative-time label
    // (visible bug: "just now" → "10m ago" on the same screen). The
    // timeline ends at "Last edit" — that's the meaningful terminus for
    // the drawing's history.
    return <_TimelineEvent>[
      _TimelineEvent(
        glyph: '🆕',
        label: 'Drawing started',
        when: drawing.createdAt,
        isMilestone: true,
      ),
      if (drawing.updatedAt.difference(drawing.createdAt).inSeconds > 30)
        _TimelineEvent(
          glyph: '✏️',
          label: 'Last edit',
          when: drawing.updatedAt,
          isMilestone: false,
        ),
    ];
  }
}

class _TimelineEvent {
  const _TimelineEvent({
    required this.glyph,
    required this.label,
    required this.when,
    required this.isMilestone,
  });
  final String glyph;
  final String label;
  final DateTime when;
  final bool isMilestone;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final _TimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color dotColor =
        event.isMilestone ? AppColors.magicPurple : AppColors.smoke;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Vertical dot-rail. Top dot is the milestone; the line
          // continues down to the next entry unless this is the last.
          SizedBox(
            width: 28,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 4),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.smoke.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  Text(event.glyph, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(event.label, style: AppTypography.bodyMedium),
                        Text(
                          _formatTimestamp(event.when),
                          style: AppTypography.caption(color: AppColors.smoke),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTimestamp(DateTime when) {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(when);
    if (diff.isNegative) return 'in ${(-diff.inMinutes).clamp(1, 60)}m';
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${when.day}/${when.month}/${when.year}';
  }
}

// =============================================================================
//  _ColorsUsedSection — distinct colour VALUES + flood-fill coverage.
// =============================================================================

class _ColorsUsedSection extends StatelessWidget {
  const _ColorsUsedSection({
    required this.uniqueColors,
    required this.floodFillCount,
    required this.strokeCount,
  });

  final int uniqueColors;
  final int floodFillCount;
  final int strokeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _kSectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Colors used', style: AppTypography.titleMd),
          AppSpacing.vGapSm,
          MagicCard(
            skin: MagicCardSkin.blank,
            borderRadius: AppCorner.brLg,
            padding: AppSpacing.cardPaddingTight,
            borderColor: AppColors.magicPurple.withValues(alpha: 0.12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Bullet(
                  glyph: '🎨',
                  text:
                      '$uniqueColors different colour${uniqueColors == 1 ? '' : 's'} across $strokeCount stroke${strokeCount == 1 ? '' : 's'}',
                ),
                SizedBox(height: AppSpacing.xs),
                _Bullet(
                  glyph: '🪣',
                  text:
                      '$floodFillCount flood-fill area${floodFillCount == 1 ? '' : 's'} covered',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.glyph, required this.text});

  final String glyph;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(glyph, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: AppTypography.bodyMedium),
        ),
      ],
    );
  }
}

// =============================================================================
//  _BadgesCollectionSection — chip cloud of the player's unlocked
//  achievements.
//
// M3 — honestly labelled. The AchievementService catalog has no
// per-drawing link, so this section shows the player's collection
// (cross-drawing) rather than claiming "badges earned ON this drawing".
// The drawing's world-stars in the stats row ARE strictly per-drawing
// via player.worldStars[worldId], so the screen's per-drawing-vs-
// per-player demarcation is honest.
// =============================================================================

class _BadgesCollectionSection extends StatelessWidget {
  const _BadgesCollectionSection({required this.badges});

  final List<AchievementDefinition> badges;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _kSectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Your badges', style: AppTypography.titleMd),
          AppSpacing.vGapSm,
          if (badges.isEmpty)
            MagicCard(
              skin: MagicCardSkin.blank,
              borderRadius: AppCorner.brLg,
              padding: AppSpacing.cardPaddingTight,
              borderColor: AppColors.magicPurple.withValues(alpha: 0.12),
              child: Text(
                'No badges yet — keep drawing to earn them!',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.smoke,
                ),
              ),
            )
          else
            Padding(
              padding: _kChipRunPadding,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final AchievementDefinition badge in badges)
                    _BadgeChip(badge: badge),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final AchievementDefinition badge;

  @override
  Widget build(BuildContext context) {
    final Color tierColor = _tierColor(badge.tier);
    return MagicCard(
      skin: MagicCardSkin.tinted,
      borderRadius: AppCorner.pill,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      borderColor: tierColor.withValues(alpha: 0.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(badge.glyph, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            badge.title,
            style: AppTypography.caption(color: AppColors.deepInk),
          ),
        ],
      ),
    );
  }

  static Color _tierColor(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return AppColors.tangerine;
      case AchievementTier.silver:
        return AppColors.smoke;
      case AchievementTier.gold:
        return AppColors.magicPurple;
    }
  }
}

// =============================================================================
//  _BottomActionBar — sticky CTA: Resume Coloring (primary) + Delete (danger).
// =============================================================================

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({required this.onResume, required this.onDelete});

  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: MagicCard(
                skin: MagicCardSkin.tinted,
                borderRadius: AppCorner.brLg,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.lg,
                ),
                borderColor:
                    AppColors.magicPurple.withValues(alpha: 0.5),
                onTap: onResume,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      '🎨',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Resume Coloring',
                      style: AppTypography.titleSm,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            MagicCard(
              skin: MagicCardSkin.blank,
              borderRadius: AppCorner.brLg,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.lg,
              ),
              borderColor: AppColors.tangerine.withValues(alpha: 0.5),                onTap: onDelete,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('🗑', style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Delete',
                      style: AppTypography.titleSm.copyWith(
                        color: AppColors.tangerine,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  _NotFoundBody — graceful fallback when the id is unknown.
// =============================================================================

class _NotFoundBody extends StatelessWidget {
  const _NotFoundBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('🪄', style: TextStyle(fontSize: 64)),
            AppSpacing.vGapMd,
            Text(
              'Drawing not found',
              style: AppTypography.titleMd,
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapSm,
            Text(
              'It may have been deleted from another device. '
              'Head back to the Gallery to keep creating.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.smoke,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapLg,
            FilledButton(
              onPressed: () => context.goGallery(),
              child: const Text('Back to gallery'),
            ),
          ],
        ),
      ),
    );
  }
}
