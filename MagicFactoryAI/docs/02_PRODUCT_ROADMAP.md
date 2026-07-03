# MagicFactoryAI — Product Roadmap

**Horizon:** 60 months (5 release cycles after V1 baseline)
**Cycle length:** 12 months per major release, 6 months per .5 patch release
**Audience:** Engineering, Product, Marketing, Partnerships, Customers
**Status:** Authoritative forward-looking plan; subject to quarterly strategic review

---

## Roadmap Summary

| Version | Codename | Timeline | Headline outcome |
|---------|----------|----------|-------------------|
| V1.0 | Foundation | Shipped | Pipeline MVP; proven end-to-end for solo creators |
| V1.1 | Polish & Hardening | Month 1–3 | Bug-fix + low-effort improvements on V1; no new architecture |
| V2.0 | Productivity & Intelligence Foundation | Month 4–9 | Smart prompt, persistent job queue, CAS, plugins, V2 Library V2 |
| V2.5 | Trust & Local-AI Readiness | Month 10–15 | Multi-provider failover, offline SD on Apple Silicon, advanced print correctness |
| V3 | Creator Economy & Collaboration | Month 16–27 | Marketplace, team workspaces, version history, style lock |
| V4 | Cloud, Mobile, Local AI | Month 28–39 | Web/mobile/shell companions, BYO-cloud, federated identity |
| V5 | Platform & AI Co-Creator | Month 40–60 | Agent platform, programmatic API, sovereign cloud, spatial surface |

All dates are month-count from V1 release (Month 0). Variation of ±2 months per release is expected; ≥6 month slip is a strategic event requiring board-level review.

---

## Version 1.1 — Polish & Hardening

**Timeline:** Month 1 → Month 3 (post-V1)
**Codename:** "Hardening"

### Mission
Lock V1's value proposition: prove to early users that MagicFactoryAI is stable, reliable, and worth investing time in, without introducing architectural change.

### Objectives
- Resolve known V1 paper-cuts and minor defects.
- Land pre-V2 architectural sinks (foundation seams) that V2 depends on.
- Capture usage telemetry (opt-in) to inform V2 prioritization.
- Validate V1's onboarding flow with real users.

### Major features
- V1.0.x bug-fix series (regression-tested)
- Onboarding revamp: first-run wizard with sample project
- Diagnostics overlay promoted to official "Performance Dashboard"
- Expanded logging categories with sanitization hooks for V2 AI providers
- Settings import/export (JSON) — required for V2 cloud sync
- Project metadata export (zip with .JSON + assets) — required for V2 cloud mirror
- Plugin-hook *seams* in code paths (no public API yet, internal hooks only)
- Hardened recovery: test crash/recovery over 1000 cycles
- Performance baselines captured per major screen

### Estimated development time
- Engineering: 6 person-weeks (1 senior eng + 1 mid eng + 0.5 QA)
- Design: 1 person-week
- QA / verification: 2 person-weeks
- Total effort: ~9 person-weeks

### Risks
- Risk: bug-fix cycle reveals deeper architectural issues.
  Mitigation: park architectural rewrites for V2.1; do not let V1.1 expand scope.
- Risk: telemetry opt-in creates trust concerns.
  Mitigation: telemetry is fully opt-in, anonymized, and explained in plain English.

### Dependencies
- None (V1.1 operates entirely within V1 codebase).

### Success criteria
- All P0/P1 bugs from V1 launch resolved.
- 95th-percentile UI freeze < 200ms across all major screens.
- Onboarding completion (first session → first asset imported): > 70%.
- Crash-free sessions: > 99.5%.
- Zero new architectural regression vs V1.0 baseline.

---

## Version 2.0 — Productivity & Intelligence Foundation

**Timeline:** Month 4 → Month 9 (6 months)
**Codename:** "Foundry"

### Mission
Replace every "you have to use a second tool" pain point in V1 with a MagicFactoryAI-native capability. Lay the architectural foundation (job queue, CAS, plugin API, multi-modal AI provider abstraction) required for V2.5+ features.

### Objectives
1. Deliver the first **end-to-end AI-driven printable-product pipeline** that does not require the user to leave the app between KDP niche research and book export.
2. Land the **persistent job queue**, **Content-Addressed Storage**, **multi-modal AI provider abstraction**, **plugin seam API**, and **background migration worker**.
3. Achieve **print correctness as a first-class invariant** (300 DPI, bleed, margin, RGB → CMYK).
4. Ship Smart Filters, Saved Searches, Search Everywhere, Quality Analysis.

### Major features
**Generation pipeline (V2.0):**
- Multi-AI provider with auto-failover (OpenAI gpt-image-1, Stability SD3.5, Ollama)
- Prompt Variables + Templates library
- Smart Prompt Builder (LLM prompt engineer assistant)
- AI Batch Generation 2.0
- Persistent job queue (SQLite-backed, crash-survivable)
- Auto quality analysis with critic-LLM gating

**Library & organization (V2.0):**
- Asset metadata editor (custom fields + EXIF + license)
- Auto Tagging (vision API, configurable provider)
- Duplicate Detection (pHash 64-bit)
- Similar Image Search (CLIP embeddings)
- Smart Filters + Saved Searches
- Search Everywhere (Ctrl+K) workspace-wide
- Favorites + Recently Used

**Print correctness (V2.0):**
- Color Space Management (RGB ↔ CMYK profile support)
- 300 DPI auto-check on import and export
- Bleed & margin validators
- PDF Preview with bleed visualization

**Architecture (V2.0):**
- Content-Addressed Storage (CAS) with SHA-256
- SQLite migration to schema V2 (additive, V1 preserved)
- Multi-modal AI provider abstraction
- Plugin SDK (lifecycle, hooks, sandbox runtime — internal API only)
- Background migration worker (V1 → V2 schema + re-hash)
- Job queue with cancellation, ETA, retry, and observability

### Estimated development time
- Engineering: 70 person-weeks across 6 calendar months (10-person team approx)
- Design: 12 person-weeks
- QA: 14 person-weeks
- Documentation (SDK, AI provider integration, migration guide): 6 person-weeks
- Total: ~102 person-weeks

### Risks
- **R1:** Multi-provider abstraction adds implementation tax; if rushed, provider integrations break.
  Mitigation: ship OpenAI only in V2.0; defer Stability/Ollama to V2.5.
- **R2:** CAS migration on user installs with 50K+ assets freezes UI on first launch.
  Mitigation: F5 background migration worker with progress bar and resumable.
- **R3:** Scope creep pulls V2.5 features into V2.0.
  Mitigation: hard scope freeze at end of month 2; defer to V2.5 if not landed by then.
- **R4:** Plugin SDK design errors force V3 to rewrite hooks.
  Mitigation: ship internal-only hooks in V2.0 and validate before exposing public API in V2.5.
- **R5:** Print correctness refactor breaks exports created in V1.
  Mitigation: round-trip test library of 100 sample books through new export path.

### Dependencies
- V1.1 hooks for telemetry, project metadata export, plugin seams.
- No external dependency on cloud providers yet (all local).

### Success criteria
- Foundation features: all five architectural sinks shipped (job queue, CAS, multi-modal AI, plugin hooks, migration worker).
- First-time-right rate (creator finishes a book without ABORTING) ≥ 80%.
- Average time-to-publish for a 30-page coloring book: < 5 days (down from V1 baseline of ~14 days).
- 95th-percentile search latency: < 500ms over 100K assets.
- 95th-percentile thumbnail load: < 100ms.
- Plugin SDK design validated by at least 1 external partner (informal).
- All V1 print export round-trips to V2 export path produce identical pixel output within tolerance.

---

## Version 2.5 — Trust & Local-AI Readiness

**Timeline:** Month 10 → Month 15 (6 months)
**Codename:** "Steward"

### Mission
Earn creator trust on data sovereignty and AI provider independence. Add the second-tier AI providers, advanced print correctness, and the foundation of brand-kit / style-lock that V3 marketplaces depend on.

### Objectives
1. Ship **offline local Stable Diffusion** on Apple Silicon (MLX) and CUDA as a primary-class provider.
2. Achieve **print compliance** with major POD networks (KDP, IngramSpark, Lulu) — pre-flight validation accepted by their spec.
3. Introduce **Brand Kit** per author.
4. Introduce **Style Lock** (per-author perceptual embedding).
5. Land the **public Plugin SDK v1.0** with manifest, sandbox, signature.

### Major features
**AI (V2.5):**
- Local Stable Diffusion Turbo (Apple Silicon via MLX, NVIDIA via ONNX Runtime)
- Stability AI provider (SD3.5 Large, SD3.5 Medium)
- Midjourney proxy provider (legitimate via Discord or API; if not available, defer)
- Auto-failover orchestration between providers
- Quality gate (configurable threshold) before delivering to library

**Brand & consistency (V2.5):**
- Brand Kit (logos, fonts, color palettes, voice prompt) per author
- Style Lock embedding (per-author: trained on approved assets)
- Series manager (Book 1 of N: shared character bank)

**Print (V2.5):**
- Pre-flight validator for KDP, IngramSpark, Lulu POD specs
- Auto-detect trim size and bleed from cover layout
- Spine width math (computed from page count + paper stock)
- CMYK profile embedding (PDF/X-3:2002 standard)

**Plugin SDK public (V2.5):**
- Public Plugin SDK v1.0 with manifest, lifecycle, hooks, event bus, sandbox
- Verified MagicFactoryAI Labs plugins (10+ first-party)
- Sample community plugins (3–5)

**Commerce (V2.5):**
- Optional seller mode for creators (connect Stripe/PayPal in pre-launch)
- Template pack format (.mfpack) specification
- Template pack browser (in-app, read-only until V3 marketplace opens)

### Estimated development time
- Engineering: 60 person-weeks
- Design: 8 person-weeks
- QA: 12 person-weeks
- MagicFactoryAI Labs plugins: 8 person-weeks
- Total: ~88 person-weeks

### Risks
- **R1:** Local SD licensing & model weight distribution unclear.
  Mitigation: support only open-weights models; document licensing rigorously.
- **R2:** Apple Silicon MLX adoption is volatile; performance gaps frustrate users.
  Mitigation: explicit "supported hardware" matrix; not block on fallback to cloud on unsupported.
- **R3:** Public plugin SDK gets abused.
  Mitigation: signed-only distribution at first; rate-limited marketplace (V2.5 has no marketplace, only direct install of signed plugins).

### Dependencies
- V2.0 architecture (CAS, job queue, plugin seams, multi-modal provider).
- External: Apple's MLX, Stability API access, ONNX runtime, open-weight model distributable channels.

### Success criteria
- Local SD on M2/M3 produces 1024×1024 in < 4 seconds for at least 80% of test prompts.
- Multi-provider auto-failover rescues 100% of simulated single-provider outages in tests.
- KDP pre-flight validator passes 95% of test books without user fix-up.
- 10+ first-party plugins installed and used by 30% of active V2.5 Pro users.
- 1,000+ creators using Brand Kit + Style Lock.
- Plugin SDK adopted by at least 5 external developers.

---

## Version 3 — Creator Economy & Collaboration

**Timeline:** Month 16 → Month 27 (12 months)
**Codename:** "Society"

### Mission
Turn MagicFactoryAI from a solo-creator app into a **creator platform** — first-party marketplace, team workspaces, version-controlled sharing of brand kits, and certified creator storefronts.

### Objectives
1. Ship the **public marketplace** (templates, plugins, prompt packs) with revenue share.
2. Ship **team workspaces** (up to 5 creators, role-based).
3. Ship **project version history** backed by CAS DAG.
4. Ship **real-time co-curation of libraries** (lightweight CRDT; not full canvas collab yet).
5. Grow to **100,000 MAU and $25M ARR**.

### Major features
**Marketplace (V3.0):**
- Creator publishing flow (template pack, prompt pack, plugin)
- Marketplace browse, search, filter
- Purchase flow with Stripe Connect for revenue share
- Creator analytics dashboard (sales, ratings, conversion)
- Verified Creator badge (V3.2)

**Team workspaces (V3.0):**
- Multi-user workspace (up to 5 creators)
- Roles: Owner, Editor, Reviewer, Read-only
- Workspace-level asset library (shared)
- Workspace-level brand kit (shared)
- Workspace-level backups

**Version history (V3.0):**
- Project version timeline (CAS-based DAG)
- Branching & merging on projects
- "Restore to version" with conflict resolution
- Visual diff of two versions (diff view)

**Quality & intelligence (V3.0 onwards):**
- Multi-agent generation pipeline (Prompt Engineer → Generator → Critic → Refiner → Quality Gate agents)
- Quality gate scoring (configurable threshold per project)
- Style lock updates on author approval feedback

**Cloud (V3.2):**
- First-party "MagicFactoryAI Cloud" (BYO optional; default = hosted)
- Plan tiers: Free (5 GB + 1 workspace), Pro (100 GB + unlimited workspaces)
- Cloud-side sync from local SQLite to cloud Postgres mirror
- Real-time collab CRDT relay (lightweight, no full DB hosting)

**Plugin ecosystem (V3.0+):**
- Plugin marketplace (curated + verified)
- Plugin royalties: 70/30 first 12 months → 80/20 thereafter
- Plugin verification pipeline (sandboxed test harness, signature verification, license registry)

### Estimated development time
- Engineering: 200 person-weeks across 12 months (~17 engineers)
- Design: 30 person-weeks
- QA: 50 person-weeks
- Trust & Safety (marketplace review, dispute handling): 12 person-weeks
- Marketplace ops (Creator support, payouts, taxes): 8 person-weeks
- Total: ~300 person-weeks

### Risks
- **R1:** Marketplace quality control is a brand risk.
  Mitigation: tiered verification; manual review for top store tiers; community flagging.
- **R2:** Real-time collab UX complexity rivals Figma; resourcing is heavy.
  Mitigation: scope to library-level collab in V3.0, defer canvas collab to V4.
- **R3:** Cloud unit economics unknown.
  Mitigation: ship cloud only with V3.2; collect data; iterate.
- **R4:** Stripe Connect + international tax (VAT, GST) is operationally heavy.
  Mitigation: phased country rollout (US, UK, CA, AU, EU in V3.0; ROW in V3.2).

### Dependencies
- V2.5 foundations (plugin SDK, brand kit, style lock).
- External: Stripe Connect, Amazon Selling Partner API, payment processor for international.
- Operational: marketplace ops team, trust and safety team.

### Success criteria
- 100,000 MAU by month 27.
- 1,000+ marketplace listings by month 27.
- 25% of Pro users have at least one team workspace seat.
- 50% of new V3 users opt into cloud backup.
- Revenue $25M ARR by month 27.
- Plugin developers earning average $500/mo on marketplace.
- NPS ≥ 55.

---

## Version 4 — Cloud, Mobile, Local AI

**Timeline:** Month 28 → Month 39 (12 months)
**Codename:** "Federation"

### Mission
Make MagicFactoryAI feel **native everywhere** — desktop is the powerhouse, web is the fast lane, mobile is the field tool, on-device AI is the privacy promise.

### Objectives
1. Ship **Web Companion** (Tauri shell) — full read, lite edit.
2. Ship **Mobile Companion** (iOS + Android via React Native shells) — review, approve, comment.
3. Promote **local AI maturity** (Flux.1, Llama 3.x, Stable Diffusion 4) on Apple Silicon and NVIDIA.
4. Ship **BYO-cloud** (S3/B2/GCS/Dropbox/OneDrive adapters).
5. Ship **federated prompt improvement** (opt-in) aggregating per-author style signals locally.
6. Grow to **250,000 MAU and $80M ARR**.

### Major features
**Multi-device (V4.0):**
- Web Companion (Tauri-Electron shell): launch from browser, full asset browsing, lite editing
- iOS Companion: asset review, comment, approve, swipe approve/reject with haptics
- Android Companion: same feature parity as iOS
- Universal command palette (Ctrl+K on desktop, /cmd on web/mobile)

**Local AI maturity (V4.0):**
- Flux.1 (Black Forest Labs) — local support via quantized gguf
- Llama 3.x local for prompt engineering
- Stable Diffusion 4 / Flux Pro on NVIDIA
- On-device inference layer (llama.cpp, MLX, ONNX runtime)
- Auto-detect: eGPU, NVIDIA, Apple Silicon
- Optimal-backend routing (cloud vs local) per task

**BYO-cloud (V4.0):**
- Adapters: S3, Backblaze B2, Google Cloud Storage, Dropbox, OneDrive
- One-click installer: MagicFactoryAI self-hosted (Docker Compose)
- Active community-supported edition
- Read-only mirror mode (default), full-sync mode (paid)

**Federation (V4.2):**
- Federated prompt improvement: opt-in, transparent, killable
- Per-niche style fingerprints aggregated locally
- Per-creator improvement loop

**Spatial (V4.3):**
- Spatial UI prototype: visionOS / Quest 3
- Float approved assets on a plane for physical-space review
- Walk-through experience for book previews

**Compliance & enterprise (V4.0):**
- Audit logs (creator level, asset level)
- SOC-2-style compliance mode for publishers
- SAML SSO support (pro tier)
- Department-level access for 200+ seat business

### Estimated development time
- Engineering: 250 person-weeks (~21 engineers)
- Mobile: 60 person-weeks (2 iOS + 2 Android dedicated teams in parallel)
- Backend / Cloud: 80 person-weeks
- Design: 40 person-weeks
- QA: 70 person-weeks
- Compliance & legal: 12 person-weeks
- Total: ~512 person-weeks

### Risks
- **R1:** Mobile parity is hard; risk of shipping a square-peg iPad app.
  Mitigation: scope mobile = review/approve only; full creation is desktop-only until V5.
- **R2:** On-device AI hardware matrix is huge.
  Mitigation: define minimum spec; auto-fallback to cloud; "supported" vs "best-effort" labels.
- **R3:** Building app shells (Tauri/RN) doubles effective engineering surface.
  Mitigation: parallel team structure; invest in shared SDK that all surfaces use.

### Dependencies
- V3 marketplace and cloud foundation.
- External: Flutter/React Native, MLX, ONNX, llama.cpp, visionOS SDK, Quest 3 SDK.
- Legal: SOC-2 audit, GDPR-DPA, CCPA compliance, country-specific data residency.

### Success criteria
- 250,000 MAU by month 39.
- 50,000 active mobile companions / 25,000 active web companions.
- 25% of Pro users using local SD as primary provider.
- $80M ARR by month 39.
- Sub-500ms semantic search across 10M vectors.
- Sub-2s mobile paint on 5-year-old device.
- SOC-2 Type II audit passed.

---

## Version 5 — Platform & AI Co-Creator

**Timeline:** Month 40 → Month 60 (20 months)
**Codename:** "Apex"

### Mission
MagicFactoryAI becomes an **AI Co-Creator Platform**. The user defines a niche, an audience, a brand; agents autonomously research, generate, refine, export, and publish. The human creator occupies the role of creative director and taste-setter, not pixel-pusher.

### Objectives
1. Ship **Co-Creator Agent** flagship: full autonomous book production with human veto per step.
2. Ship **agent marketplace** (creator-published agent recipes; revenue share).
3. Ship **spatial creation studio** (visionOS + Quest 3) for AR-native book experiences.
4. Ship **programmatic API** (full platform accessible from CLI/scripts).
5. Reach **1,000,000 MAU and $250M ARR**.

### Major features
**Agents (V5.0):**
- Co-Creator Agent (flagship): "Build me a 30-page unicorn winter coloring book for ages 4–7 targeting the KDP holiday niche" → executes the whole pipeline
- Sub-agents: Researcher, Director, Generator, Critic, Refiner, Publisher, Marketer, Analyst
- Agent memory (long-term store per project)
- Agent negotiation protocol (multi-agent tasks)
- Meta-agents: tune other agents per-author based on sales response

**Agent marketplace (V5.0):**
- Creator-published agent recipes
- Search, version, rating
- Revenue share (70/30 first 12 months → 80/20 thereafter)
- Verified agent recipes (T&S-reviewed)
- Sovereign identity: users own their agent recipes

**Spatial Creation Studio (V5.1):**
- Native visionOS / Quest 3 app
- Float approved assets on a plane
- Walk-through experience
- Spatial canvas review for book compositions
- Voice navigation ("open last night's project")

**Generative UI (V5.2):**
- Tasks adapt their UI to context
- Cover mode shows typography surface
- Series mode shows timeline surface
- Custom dashboards assembled around current activity

**Programmatic API (V5.3):**
- Full MagicFactoryAI accessible via CLI
- Python SDK (public)
- TypeScript SDK (public)
- Webhook events for plugin-like integrations

**Sovereign cloud (V5.0):**
- User owns all data
- Encrypted cloud mirror as backup (never canonical)
- User-region-pinned default
- Data-export-format covers agents, marketplaces, plugins, projects, history

**Federated computing (V5.3+):**
- Cross-device compute (use idle phones for inference, opt-in)
- Federated vector indices per niche / topic

### Estimated development time
- Engineering: 400 person-weeks
- AI / Agents: 100 person-weeks (dedicated team)
- Spatial (visionOS / Quest): 80 person-weeks
- Cloud / Backend: 120 person-weeks
- Marketplace ops at scale: 20 person-weeks
- Design: 60 person-weeks
- QA: 120 person-weeks
- Total: ~900 person-weeks across 20 months

### Risks
- **R1:** AGI-adjacent positioning invites headline risk.
  Mitigation: clear communications — "Agent suggests; you decide." Public stance documents.
- **R2:** Agent loops can spin money on cloud AI calls.
  Mitigation: hard spend caps per task; transparent meter UI; dry-run preview before any spend.
- **R3:** Marketplace vetting at scale is hard.
  Mitigation: tiered verification (auto for low-risk, manual for high-risk).
- **R4:** Revenue mix risk — heavy marketplace dependence.
  Mitigation: subscription tier (Co-Creator $99/mo) anchors predictable revenue.

### Dependencies
- V4 multi-device, cloud, BYO-cloud foundation.
- Local AI maturity (V4).
- Marketplace (V3).
- External: ARKit (visionOS), MetaPresence (Quest), Agent SDK references (e.g., LangChain patterns).

### Success criteria
- 1,000,000 MAU by month 60.
- 5,000+ Certified Creators.
- 100+ agent recipes in marketplace.
- $250M ARR by month 60.
- 1,000+ "Agent-produced" books reach KDP Top 100 BSR.
- Spatial Creation Studio received 100,000+ trial downloads.

---

## Cross-Version Architectural Lifts

Throughout all five releases, these architectural capabilities are progressively strengthened:

| Capability | V1.0 baseline | V2.0 | V2.5 | V3 | V4 | V5 |
|------------|---------------|------|------|-----|-----|-----|
| Job persistence | in-memory | SQLite | SQLite | SQLite + cloud | SQLite + cloud + CRDT | distributed CRDT |
| Asset storage | file path | CAS (local) | CAS (local) | CAS (local+cloud) | CAS (local+cloud+BYO) | CAS (federated) |
| AI provider abstraction | none | multi-modal | multi-modal + local | multi-agent | multi-agent + on-device | co-creator agents |
| Plugin SDK | none | internal hooks | public v1.0 | marketplace | SDK v2 + mobile | SDK v2 + spatial |
| Auth | local | local | local | OAuth + workspace | OAuth + workspace + SSO | sovereign identity |
| Database | SQLite V1 | SQLite V2 | SQLite V2 | SQLite V2 + cloud PG | SQLite + PG + vector | distributed |
| Telemetry | basic logs | structured | opt-in metrics | full analytics | cross-device | federated |

---

## Strategic Pivots & Decision Points

The roadmap assumes certain strategic bets remain valid. The following decisions are scheduled review points:

| Decision point | When | Trigger |
|----------------|------|---------|
| Should we ship marketplace in V2.5 or V3? | End of V2.5 sprint 1 | Marketplace review pipeline maturity |
| Should we ship web companion in V3 or V4? | End of V3 sprint 1 | Mobile-first usage signal |
| Should we default to cloud or local-first for new users? | End of V4 sprint 1 | Trust / privacy surveys |
| Should we ship Co-Creator Agent to all users or Pro+ only? | End of V5 sprint 1 | Cost-of-inference data |

Any decision-point where the trigger condition is not met triggers a planning pivot; these are expected and acceptable. Decisions cannot unilaterally delay a release by > 1 quarter.

---

## Cross-Cutting Themes Across All Releases

Five themes dominate every release:

1. **Vertical integration** — each release adds more of the pipeline into MagicFactoryAI.
2. **Sovereignty** — creator owns their data, agents, plugins; vendor lock-in is intentionally avoided.
3. **AI in service of taste** — AI accelerates; creator decides; never "AI shipped it".
4. **Trust** — print correctness, provenance, recovery, transparency take priority over feature breadth.
5. **Modular architecture** — every feature shipped in plugin-ready shape so it can be replaced, extended, or resold.

---

## Closing Note

Five years is a long time in software. This roadmap will evolve. What will not evolve is the **mission** — to be the world's first end-to-end AI desktop studio for printable products — and the **north star metric** — books successfully published per active user per quarter.

Every team in MagicFactoryAI should be able to answer: *"Does this feature increase published books per user?"* If yes, build it. If no, defer it.
