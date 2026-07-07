# 14 — Magic Colors · Monetization
**Document:** Official Monetization Model v1.0
**Audience:** Founders, monetization lead, legal, design
**Status:** v1.0 baseline

---

## 1. Monetization Philosophy

Magic Colors is **paid without punishment**.

- Children enjoy the full game for free; no limi­ted content.
- Parents pay for **multipliers and polish**, not for essential features.
- We **never** show ads in the child zone.
- We **never** use dark patterns, FOMO, or "limited time" pressure.
- The free tier is generous and complete; the premium tier is a quality improvement.

This is the **"Disney model"** — content is the brand, monetization is the cherry on top, not a gate.

## 2. Revenue Streams (4 primary)

| Stream | Description | Cadence |
|---|---|---|
| **Premium subscription** | Recurring, unlocks premium brushes/seasonal packs | monthly/yearly |
| **One-off coin packs** | Cosmetic perks (stickers, brushes) paid in real money | one-time |
| **Seasonal packs** | World bundles (Wave 2, Wave 3) launched seasonally | per pack |
| **Optional parent extras** | Print/PDF export, advanced analytics | subscription-gated |

### 2.1 Revenue Mix Targets (Year 1)

| Stream | Target share |
|---|---|
| Premium subscription | 65 % |
| Coin packs (one-off) | 20 % |
| Seasonal packs | 10 % |
| Other (parent extras) | 5 % |

## 3. Premium Subscription ("Magic Colors Premium")

### 3.1 Pricing

| Plan | Price | Equivalent per month |
|---|---|---|
| Monthly | $4.99 | $4.99 |
| Yearly | $39.99 (33 % off) | $3.33 |
| Family (up to 5 child profiles) | $59.99/year | $5.00 |

Free trial: 7 days, full content accessible, no charge until trial end.

### 3.2 Premium benefits

- Premium brushes: **rainbow brush, glow brush, multicolor pencil.**
- Stickers: premium packs (Holidays, Fantasy, etc.).
- Print & PDF export of saved pages.
- Up to 5 child profiles.
- Priority feature release (early access to world packs).
- Custom daily revenue support (parents can opt to support creators).

### 3.3 What Premium does **not** unlock

- ❌ Any free world.
- ❌ Any free page.
- ❌ Any core coloring tool.
- ❌ The Parents Zone (always free).

## 4. Free Tier (the generous default)

- All 10 worlds.
- All 400 pages.
- All core tools: brush, pencil, bucket fill, marker, crayon, sticker, stamps.
- Coin and gem rewards.
- Daily event.
- Gallery + save.
- 1 child profile.

The free tier is **honest**: it does everything; it's just not as polished.

## 5. Coin & Gem In-App Currency (simplified model)

| Currency | Source | Sink |
|---|---|---|
| Coin (gold) | Page reward drop, daily login | Sticker packs (free + premium), brushes (cosmetic variants) |
| Gem (royal blue) | World-level milestones | Premium cosmetic sticker packs, special brushes |

Coins and gems are **earned** primarily, **purchased** secondarily.

### 5.1 Coin pack pricing

| Pack | Coins | Price |
|---|---|---|
| Small | 100 | $0.99 |
| Medium | 550 | $4.99 (most popular) |
| Large | 1200 | $9.99 |
| Mega | 3000 | $19.99 |

### 5.2 Gem pack pricing

| Pack | Gems | Price |
|---|---|---|
| Small | 25 | $0.99 |
| Medium | 150 | $4.99 |
| Large | 400 | $9.99 |

Bundles come with a small bonus (10 % extra in Medium, 20 % extra in Large).

## 6. Parents Zone = Monetization Boundary

| Feature | In Parents Zone | In Child Zone |
|---|---|---|
| Subscription purchase | ✅ | ❌ (gated) |
| Coin pack purchase | ✅ | ❌ (gated) |
| Receipts / restore | ✅ | ❌ |
| Cancel / refund access | ✅ | ❌ |
| Time limits | ✅ | ❌ |
| Volume | ✅ | ❌ |

This is a **hard rule** and is enforced by gate: tapping "Premium" in child zone shows the lock screen → math challenge → only after success does the parent see the subscription screen.

## 7. Anti-Dark-Pattern Manifesto

| Pattern | Status in Magic Colors |
|---|---|
| FOMO timers ("offer ends in 30 minutes") | ❌ Banned |
| Hidden costs / loot box | ❌ Banned |
| Energy / life system | ❌ Banned |
| "Almost there!" progress with loss framing | ❌ Banned |
| Cart-abandon pressure | ❌ Banned |
| Auto-renew without parent signature | ❌ Banned |
| Variable reward schedules (slot-machine) | ❌ Banned |
| Paywall on first session | ❌ Banned |
| Forced tutorials teaching purchase | ❌ Banned |
| Real-currency coin illustrations | ❌ Banned |

## 8. Subscription Flow (canonical)

```
[Child Zone: tap "Premium" tag]
                  ↓
[Lock screen math challenge]
                  ↓
[Parent unlocks Parents Zone → Premium screen]
                  ↓
[Plan selection card (monthly / yearly / family)]
                  ↓
[Apple/Google native subscription sheet]
                  ↓
[Confirmation modal: "Premium unlocked!" with Pixel excited]
                  ↓
[Parent remains in Parents Zone; child sees new brushes next launch]
```

## 9. Family Sharing (5 profiles)

Premium family plan supports up to 5 child profiles per family. Each child has:

- Their own progress, gallery, sticker collection.
- Independent daily streak.
- Independent coin/gem economy (no cross-pollination).

Family purchase is gated under a single parent account.

## 10. Saving & Print-to-PDF

Print-to-PDF is **Premium only**. Free tier can save in-app; Premium can export to PDF or share to printer:

- 1 page at $0 (unlimited) from the app.
- Family Album PDF (40 pages): **Premium**.
- Custom cover: **Premium**.

Children see "Print to PDF" but the action goes through Parents Zone.

## 11. App Store Compliance

| Region | Rule |
|---|---|
| EU (GDPR, DMA) | Parental gate before any IAP screen. Privacy nutrition labels accurate. |
| US (COPPA, FTC) | No behavioral targeting of minors. No persistent identifiers in child zone. |
| UK | Same as EU. |
| China | Specific compliance — kid-friendly content + IAP approval — address as needed v1.1. |

## 12. Refunds & Restorations

- All IAP handled by Apple/Google native flow.
- "Restore purchases" button in Parents Zone.
- Refund requests handled per-platform policy.
- Customer support email `support@magiccolors.app` (24-h weekday SLA).

## 13. Localization & Pricing

Pricing in local currencies is auto-handled by App Store. We use **psychological pricing** ($4.99 not $5.00) in all regions where it's customary.

## 14. Year-1 Revenue Goal

- 500 K installs (organic + paid acquisition)
- 5 % conversion to subscription
- ARPU ~ $1.20/year (free users)
- ARRPU ~ $24/year (paying users)
- Year-1 target ARR: ~ $600 K

## 15. Year-2-3 Goals

| Year | Goal |
|---|---|
| 1 | 500 K MAU, 5 % subscription conversion |
| 2 | 2 M MAU, 8 % conversion |
| 3 | 5 M MAU, 12 % conversion |

## 16. Where Revenue Comes From Without Annoying Parents

- 90 % of paying users pay once and stay.
- Family plan covers multiple siblings: organic expansion.
- Seasonal world packs: organic, gentle, non-urgent marketing.
- Coin packs: niche "thank you" gesture from engaged parents — never pushed in child zone.

## 17. Anti-Conversion Tactics (forbidden)

- ❌ Email blasts to parents announcing "Sale ends tonight!".
- ❌ In-app push notifications to parents about price changes.
- ❌ Email to children (not allowed; children have no email).
- ❌ Sharing user-generated content of children publicly.

## 18. Open Questions to Resolve v1.1

| Question | Owner | When |
|---|---|---|
| Web companion (browser) for in-app parents | Eng | v1.1 |
| School licensing program | BD | v1.2 |
| Therapy / clinic licensing | BD | v1.3 |

---

**Document complete. v1.0 frozen.**
