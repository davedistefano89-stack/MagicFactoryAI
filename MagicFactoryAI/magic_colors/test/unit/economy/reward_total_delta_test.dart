// =============================================================================
// Magic Colors · test/unit/economy/reward_total_delta_test.dart
// =============================================================================
//
// M2.4 regression suite for the [RewardTotalDelta] extension. Walks the
// sealed [Reward] tree (CoinReward, GemReward, StarReward,
// CompositeReward) and asserts that the coin + gem totals are computed
// correctly across:
//   • leaf nodes,
//   • composite nodes,
//   • nested composites (composite-of-composite),
//   • mixed children,
//   • empty composites.
//
// The [ColoringController._evaluateRewardEligibility] snapshots the
// awarded delta so the [DrawingCompleteOverlay] can render the reward
// pill row without re-walking the tree. These tests pin down the
// contract.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/core/domain/economy/reward.dart';

void main() {
  group('RewardTotalDelta — leaf nodes', () {
    test('CoinReward.amount feeds totalCoinDelta only', () {
      const Reward r = CoinReward(reason: 'r1', amount: 25);
      expect(r.totalCoinDelta, 25);
      expect(r.totalGemDelta, 0);
    });

    test('GemReward.amount feeds totalGemDelta only', () {
      const Reward r = GemReward(reason: 'r2', amount: 3);
      expect(r.totalCoinDelta, 0);
      expect(r.totalGemDelta, 3);
    });

    test('StarReward contributes zero to both totals', () {
      const Reward r = StarReward(
        reason: 'r3',
        worldId: 'unicorn_valley',
        amount: 2,
      );
      expect(r.totalCoinDelta, 0);
      expect(r.totalGemDelta, 0,
          reason: 'star rewards are quality, not currency');
    });
  });

  group('RewardTotalDelta — single-level composite', () {
    test('sums CoinReward amounts', () {
      const Reward r = CompositeReward(
        reason: 'c1',
        children: <Reward>[
          CoinReward(reason: 'c1.1', amount: 10),
          CoinReward(reason: 'c1.2', amount: 15),
        ],
      );
      expect(r.totalCoinDelta, 25);
      expect(r.totalGemDelta, 0);
    });

    test('sums GemReward amounts', () {
      const Reward r = CompositeReward(
        reason: 'c2',
        children: <Reward>[
          GemReward(reason: 'c2.1', amount: 1),
          GemReward(reason: 'c2.2', amount: 2),
        ],
      );
      expect(r.totalCoinDelta, 0);
      expect(r.totalGemDelta, 3);
    });

    test('sums mixed Coin + Gem + Star children', () {
      const Reward r = CompositeReward(
        reason: 'c3',
        children: <Reward>[
          CoinReward(reason: 'c3.1', amount: 50),
          GemReward(reason: 'c3.2', amount: 2),
          StarReward(reason: 'c3.3', worldId: 'w', amount: 3),
        ],
      );
      expect(r.totalCoinDelta, 50);
      expect(r.totalGemDelta, 2,
          reason: 'star rewards are skipped, coins + gems summed');
    });

    test('empty composite contributes zero to both totals', () {
      const Reward r = CompositeReward(
        reason: 'c4',
        children: <Reward>[],
      );
      expect(r.totalCoinDelta, 0);
      expect(r.totalGemDelta, 0);
    });
  });

  group('RewardTotalDelta — nested composites', () {
    test('composite-of-composite aggregates grand-children totals', () {
      const Reward r = CompositeReward(
        reason: 'outer',
        children: <Reward>[
          CompositeReward(
            reason: 'inner1',
            children: <Reward>[
              CoinReward(reason: 'inner1.1', amount: 5),
              GemReward(reason: 'inner1.2', amount: 1),
            ],
          ),
          CompositeReward(
            reason: 'inner2',
            children: <Reward>[
              CoinReward(reason: 'inner2.1', amount: 15),
              StarReward(reason: 'inner2.2', worldId: 'w', amount: 1),
            ],
          ),
        ],
      );
      expect(r.totalCoinDelta, 20, reason: '5 (inner1.1) + 15 (inner2.1)');
      expect(r.totalGemDelta, 1, reason: '1 (inner1.2); inner2 has only stars');
    });

    test('every CoinReward + GemReward seen in any nesting depth contributes',
        () {
      const Reward r = CompositeReward(
        reason: 'deep',
        children: <Reward>[
          CompositeReward(
            reason: 'mid',
            children: <Reward>[
              CompositeReward(
                reason: 'leaf',
                children: <Reward>[
                  CoinReward(reason: 'leaf.1', amount: 7),
                  GemReward(reason: 'leaf.2', amount: 3),
                ],
              ),
            ],
          ),
        ],
      );
      expect(r.totalCoinDelta, 7);
      expect(r.totalGemDelta, 3);
    });

    test(
      'mixed-shape tree (coins + nested-gems + star-only subtree)',
      () {
        const Reward r = CompositeReward(
          reason: 'mixed',
          children: <Reward>[
            CoinReward(reason: 'm.coin1', amount: 12),
            CompositeReward(
              reason: 'gems',
              children: <Reward>[
                GemReward(reason: 'g.1', amount: 4),
                GemReward(reason: 'g.2', amount: 1),
              ],
            ),
            CompositeReward(
              reason: 'stars-only',
              children: <Reward>[
                StarReward(reason: 's.1', worldId: 'w', amount: 3),
              ],
            ),
          ],
        );
        expect(r.totalCoinDelta, 12);
        expect(r.totalGemDelta, 5,
            reason: 'star-only subtree contributes 0 gems');
      },
    );
  });

  group('RewardTotalDelta — mirror symmetry', () {
    test('a hand-rolled sum equals the recursive total', () {
      const Reward r = CompositeReward(
        reason: 'mirror',
        children: <Reward>[
          CoinReward(reason: 'm.1', amount: 11),
          CoinReward(reason: 'm.2', amount: 22),
          GemReward(reason: 'm.3', amount: 5),
          GemReward(reason: 'm.4', amount: 6),
        ],
      );
      // Hand-sum as an independent oracle.
      const int oracleCoins = 11 + 22;
      const int oracleGems = 5 + 6;
      expect(r.totalCoinDelta, oracleCoins);
      expect(r.totalGemDelta, oracleGems);
    });
  });

  group('RewardTotalDelta — sign / behaviour contracts', () {
    test('negative amounts contribute their sign (no sign-filter today)', () {
      // Pins current production behaviour: there is no `if (amount > 0)`
      // guard inside the extension. If a future change adds that guard,
      // this test MUST be re-written alongside it — silent flip = bug.
      const Reward r = CompositeReward(
        reason: 'signed',
        children: <Reward>[
          CoinReward(reason: 'neg', amount: -7),
          GemReward(reason: 'pos', amount: 4),
        ],
      );
      expect(r.totalCoinDelta, -7);
      expect(r.totalGemDelta, 4);
    });
  });

  group('RewardTotalDelta — recursion depth', () {
    test('5-level composite aggregates coin at the deepest leaf', () {
      // Build: composite(composite(composite(composite(composite(coin)))))
      const Reward deep = CompositeReward(
        reason: 'd5',
        children: <Reward>[
          CompositeReward(
            reason: 'd4',
            children: <Reward>[
              CompositeReward(
                reason: 'd3',
                children: <Reward>[
                  CompositeReward(
                    reason: 'd2',
                    children: <Reward>[
                      CompositeReward(
                        reason: 'd1',
                        children: <Reward>[
                          CoinReward(reason: 'leaf', amount: 9),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      expect(deep.totalCoinDelta, 9);
      expect(deep.totalGemDelta, 0);
    });
  });

  group('RewardTotalDelta — nested star-only subtrees', () {
    test(
      'a composite containing only StarReward + nested star-only composite '
      'contributes zero to both totals',
      () {
        const Reward nestedStars = CompositeReward(
          reason: 'outer-stars',
          children: <Reward>[
            StarReward(reason: 'outer', worldId: 'w', amount: 3),
            CompositeReward(
              reason: 'inner-stars',
              children: <Reward>[
                StarReward(reason: 'inner', worldId: 'w', amount: 1),
              ],
            ),
          ],
        );
        expect(nestedStars.totalCoinDelta, 0);
        expect(nestedStars.totalGemDelta, 0);
      },
    );
  });
}
