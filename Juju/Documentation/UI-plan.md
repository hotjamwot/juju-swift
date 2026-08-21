# Juju Design Plan — "A Warm Journal That Celebrates You"

**Goal:** Make Juju feel loving, friendly, encouraging, and beautiful — without adding a single element of visual noise. Warmth comes from *motion*, *words*, and *colour temperature*, never from new chrome.

---

## Design Principles

1. **Calm journal first.** Near-black editorial aesthetic stays constant. No time-based theming.
2. **Hue belongs to the data.** Project colours own all saturation. New semantic colours are muted, earthy, data-layer only.
3. **Motion is care, not decoration.** Soft springs, short durations, celebration only around real moments.
4. **The voice is a friend.** Data speaks warmly; encouragement is earned from real signals, never banner-like.

## Guardrails (hard rules)

- ❌ No new typefaces — `affirmation` style = same family, different weight/size combo.
- ❌ Card radius locked at **12**. Only sanctioned radius changes: blocks 5→8, rows 10→12.
- ❌ No borders on cards — depth comes from surface step + shadow.
- ❌ No bright backgrounds; background gradient capped at 2–3% opacity.
- ❌ Interaction animations: 0.15–0.4s springs/ease only. Ambient looping animation is **whitelisted for exactly two things**: milestone star pulse (~2.4s) and the greeting breathing motif. Nothing else loops.
- ❌ No confetti, particles, or idle decoration — celebration appears only when a milestone/data moment exists.
- ❌ No global accent reintroduction; no new charts, cards, or denser layouts.

---

## Phase 1 — Theme.swift Tokens (foundation; everything depends on this)

- [x] **Colours:** Add `Theme.Colors.positive` = `#7FA86C` (warm sage), `negative` = `#C97B6B` (soft terracotta), `liveIndicator` = `#E08A6D` (desaturated coral), `warmAccent` (warmer tint of current accent, for hover glows), `glow` (soft radial highlight for celebrations).
- [x] **Shadows:** Add `Theme.Design.shadowSoft` / `shadowWarm`. Replace current card shadow (`radius: 8, y: 4`) with (`radius: 14, y: 8`), lower opacity, subtle warm tint. Divider opacity 30% → 18%, warmed tint (pencil-on-paper feel).
- [x] **Motion:** Add `Theme.Design.spring` = `spring(response: 0.35, dampingFraction: 0.7)` — the single curve for all hover/selection.
- [x] **Type:** Add `Theme.Fonts.affirmation` — same family, friendly weight/size pairing for encouragement lines.
- [x] **Radii:** `blockCornerRadius` 5 → 8; row corner radius 10 → 12. Cards untouched.

## Phase 2 — Micro-interactions (highest fun-per-line payoff)

All use `Theme.Design.spring`; all respect Reduce Motion (disable ambient loops, fall back to opacity-only).

- [x] **Session row project dot:** on row hover, scale 1.0 → 1.03 (0.15s spring) + brighten ~15%. Uses `hoverSpringScale` modifier.
- [x] **Chart bars** (yearly charts, calendar, 90-day timeline, Braid spine): on hover, opacity 0.85 → 1.0 and bar thickens 6 → 8pt with spring. Yearly bar charts use `Theme.Design.spring`; chart hover handlers use `Theme.Design.spring` (replaced `.easeOut(duration: 0.1)`).
- [x] **Calendar session blocks:** on hover, 0.85 → 1.0 opacity + warm accent stroke annotation (2pt, 35% opacity). `Theme.Design.spring` in hover handler.
- [x] **Milestone stars (everywhere):** slow ambient pulse 1.0 → 1.12 → 1.0 over ~2.4s loop. *(Whitelisted loop #1. If it reads as distracting in testing, downgrade to a one-time 0.4s scale+glow pulse on appear/hover.)*
- [x] **Metric/stat cards:** on hover, 1–2px lift + warmer shadow. (`.hoverLift()` modifier on `NarrativeMetricCard`, `DaySessionInfoPanel` session cards, `ProjectStoryView` PhaseDetailPanel background.)
- [x] **Buttons** (back chevron, filter toggles, confirm/close/bulk-edit/mood): 1.03 scale on hover with the spring curve. (`.hoverSpringScale(targetScale: 1.03)` modifier.)

### Implementation notes

- **New file:** `Juju/Shared/Extensions/MicroInteractions.swift` — three reusable view modifiers:
  - `MilestonePulseModifier` (`.milestonePulse()`) — ambient scale pulse; fully suppressed when Reduce Motion is enabled.
  - `HoverSpringScaleModifier` (`.hoverSpringScale(targetScale:)`) — spring scale on hover; falls back to opacity-only when Reduce Motion is enabled.
  - `HoverLiftModifier` (`.hoverLift()`) — 1–2px lift + warm shadow on hover; shadow-only when Reduce Motion is enabled.
- **Theme.swift fix:** `Theme.Design.spring` changed from `Spring(response: 0.35, dampingRatio: 0.7)` to `Animation.spring(response: 0.35, dampingFraction: 0.7)` for compatibility with `.animation()` and `withAnimation()`.
- **ChartContent limitation:** `.animation()` cannot be applied directly to `RectangleMark` (`some ChartContent`). Animation is driven by the `withAnimation(Theme.Design.spring)` calls in the chart overlay hover handlers.
- **Xcode project:** `MicroInteractions.swift` was added to `Juju.xcodeproj` (PBXBuildFile, PBXFileReference, PBXSourcesBuildPhase, and PBXGroup entries).

## Phase 3 — Milestone Celebration Layer

- [ ] **90-Day Timeline:** milestone days get a soft radial glow behind their sliver — `milestone` colour at ~12% opacity expanding outward. On hover, halo pulses brighter (18% ↔ 26%) with slow `.easeInOut`. Sliver tints subtly toward gold.
- [ ] **Weekly Calendar:** milestone session blocks get a 4pt `milestoneHighlight` circle at top-trailing corner — an LED dot, not chrome.
- [ ] **DaySessionInfoPanel:** the "★ Milestone" pill gains a warm background tint (`milestone` @ 8%).

## Phase 4 — Voice Layer (NarrativeEngine + placements)

- [ ] **Add `encouragement(for:)` API** to NarrativeEngine, keyed to real signals: active streak, milestone logged, project with many sessions, high average mood. Returns one quiet line; never fires without data.
- [ ] **Delta copy reframe** (keep semantic colours, soften the words):
  - Positive: `"Yeah baby! Nice momentum — +2.1h vs your average week"`
  - Zero: `"Cool — matching your average week"`
  - Negative: `"Chilling this week — −1.4h vs your average"` (kind word, existing terracotta)
- [ ] **Rotating encouragement caption** under the narrative header: 10pt, `textSecondary`, hand-written feel, cross-fades between phrases on each dashboard visit (e.g. *"Nice work this week ✦"*, *"Feels good to be in the Juju"*, *"Lock in."*). Only appears when there's data to celebrate. Never a callout. We can incorporate some te reo Māori (phrase ideas below) for this.
- [ ] **ProjectStory header:** one gentle story-metaphor line (e.g. *"This project has grown across 3 phases — beautiful to watch."*).
- [ ] **Empty states:** keep the existing friendly voice; add warm accent tint to the icon.

## Phase 5 — Greeting & Page Openers

- [ ] **OverviewDashboardView:** day-greeting above the narrative strip — time-of-day te reo with name (*"Mōrena, Hayden"* / afternoon / evening variants), `Theme.Fonts.header` 16pt semibold. Below it, a `textSecondary` caption: editorial date (*"Friday, 21 August · Week 34"*). Adds a beat of humanity before the data; replaces nothing.
- [ ] **Breathing motif:** beside/behind the greeting, a slow meditative orb/synapse-style pulse — gentle opacity/scale breathing, 'in the zone' rhythm. *(Whitelisted loop #2.)*
- [ ] Extend the same opener pattern to projects/sessions headers.

## Phase 6 — Canvas Warmth

- [ ] **Background:** barely-there vertical gradient — base background → whisper of `warmAccent` at top (~2–3% opacity). Should be felt, not seen.
- [ ] **Pill badges & filter chips:** warm surface + `shadowSoft` so they read as friendly tags.

## Phase 7 — Copy Bank & QA

- [ ] **Centralise all te reo strings** in one localisable file, each with its English translation adjacent (users should always be able to understand them). Verify macrons render correctly throughout.
- [ ] **Phrase bank to draw from:**

| Te reo | English | Suggested spot |
|---|---|---|
| Kua tae te wā ki te Juju! | The time for Juju has arrived | Splash / session start |
| Kuhu ki te Juju! | Get into the Juju! | Playful CTA |
| Eke ki te Juju! | Hop aboard the Juju! | Onboarding |
| Me tīmata te Juju! | Let's get this Juju started! | Start button |
| Nau mai, hoki mai | Welcome back | Returning users |
| Kia ora, e te kaituhi | Hello, writer | Greeting variant |
| Tēnā koe, e te kaihanga | Greetings, maker | Greeting variant |
| E te pūkōrero… | O storyteller… | Story-mode opener |
| He rā hou, he rā auaha | A new day, a creative day | Morning greeting |
| Me tīmata te haerenga | Let the journey begin | New project |
| Whakamaua tō pene! | Grab your pen! | New session |
| Kia pai te tuhi | Happy writing | Sign-off |
| Kia kaha te tuhi | Stay strong, keep writing | Streak nudge |
| Tuhi noa | Just write | Freewrite mode |
| Tuhi i nāianei, whakatika ā muri | Write now, fix later | Draft mode |
| Kaua e whakamā | Don't be shy | First draft |
| He taonga tō kōrero | Your story is a treasure | Milestone |
| Whakapono ki a koe mātou | We believe in you | Encouragement pool |
| Whāia tō moemoeā | Chase your dream | Goal set |
| Hangaia tō ao! | Build your world! | Worldbuilding projects |
| Waihanga i tō ao hōu | Create your new world | New world doc |
| Hōparatia te ao | Explore the world | Browse mode |
| I te wā onamata… | In ancient times… | Story-mode loading line |
| Rarangatia tō kōrero | Weave your story | Braid view |
| Te Kore → Te Pō → Te Ao Mārama | Void → Night → World of Light | Generating/progress animation stages |
| Kua rere ngā whakaaro | The ideas are flowing | Flow-state detection |
| Kia tau ngā whakaaro | Let thoughts settle | Focus mode |
| Kōkiri! | Press on! | Deadline sprint |
| Haere tonu | Keep going | Resume button |
| Kia māia | Be bold | Publish/share |
| Kua oti! | Done! | Task complete |
| Kua toa koe! | You champion! | Streak/win screens |
| Kua angitu koe | You've succeeded | Milestone toast |
| Whakanuia! | Celebrate! | Milestone toast |
| Whakapūmau i tō kōrero | Make your story endure | Project archive / completion |
| Kia pai tō moe, e te kaituhi | Sleep well, writer | Late-night session close |
| Kia ora | Hello / thanks / be well | All-purpose greeting variant |
| Mōrena | Good morning | Morning greeting |
| Kia kaha | Stay strong | General encouragement pool |

**Worldbuilding vocab kit** (for world docs / lore templates, always with English gloss): **maunga** mountain · **awa** river · **ngahere** forest · **moana** sea · **tipua** supernatural being · **taniwha** water creature · **kaitiaki** guardian · **karakia** incantation.

- [ ] **QA the voice:** every te reo string ships with its translation visible or on hover/tap; macrons verified in the app font at all sizes; strings sourced consistently against **Te Aka** / **Paekupu**; final pass by a fluent speaker before public release.

---

## Phase 8 — Implementation Order & Acceptance Criteria

**Build order** (each step is independently shippable):

1. **Theme.swift tokens** — colours, shadows, spring, affirmation style, radii. Nothing else compiles against warmth until this lands.
2. **Micro-interactions** — highest delight-per-line-of-code; they consume the spring token.
3. **Milestone celebration layer** — halo, LED dot, pill tint.
4. **Canvas warmth** — background gradient, dividers, pills/chips.
5. **Voice layer** — `encouragement(for:)` API, then delta copy, then caption rotation, then ProjectStory line.
6. **Greetings & openers** — day-greeting, date caption, breathing motif.
7. **Copy bank & QA** — localisable strings file, macron audit, speaker review.

**Acceptance criteria for the whole plan:**

- [ ] Zero new typefaces; zero new corner radii beyond the two sanctioned changes.
- [ ] Every animation is either a ≤0.4s spring/ease on interaction, or one of the two whitelisted ambient loops.
- [ ] With Reduce Motion on: no ambient loops, hover states fall back to opacity-only.
- [ ] New colours (`positive`, `negative`, `liveIndicator`) pass contrast checks against near-black surfaces.
- [ ] No encouragement line renders without real underlying data.
- [ ] Side-by-side before/after: cards feel "held" not "floating", blocks feel "huggable" not "technical", the dashboard opens with a human beat before any number appears.

**Defaults chosen so the agent can start immediately** (change any of these and I'll amend):

1. **Scope:** all phases, in the order above — each is a safe stopping point.
2. **Voice:** warm and personal ("lovely momentum ✦"), one notch above the current editorial tone — never gushing.
3. **Motion:** full springs on hover, as specced — restrained by the 0.35s response curve, not by removing motion.