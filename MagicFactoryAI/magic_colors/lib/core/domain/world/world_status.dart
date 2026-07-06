// =============================================================================
// Magic Colors · lib/core/domain/world/world_status.dart
// =============================================================================
//
// Sprint 6 — central 4-state lifecycle enum for the World Unlock
// Progression system. Re-declared (rather than imported) from
// `features/worlds/presentation/pages/world_map_screen.dart` so
// downstream service-layer code in `core/` can branch on lifecycle
// without pulling in the entire world_map_screen.dart widget tree.
//
// The 4 states mirror the existing `CompletionState` in
// `world_map_screen.dart` 1:1 — both must stay in lock-step. The
// canonical UI enum remains the `CompletionState` (the island render
// branches on it for the badge layout). This type is the public
// surface that any service-layer code should reach for; an
// adapter converts at the UI boundary.
//
//   ▸ locked     — not yet reachable (premium-gated or star-gated).
//   ▸ available  — unlocked, but not the current world and not complete.
//   ▸ current    — the kid is inside this world right now.
//   ▸ completed  — all 3 stars earned; rewards available to claim.
// =============================================================================

/// Centralized world lifecycle state. Re-exports the same 4 states
/// the world map island render already uses, but stripped of any
/// "private-to-feature" prefix so the services layer can branch on
/// it cleanly.
enum WorldStatus { locked, available, current, completed }
