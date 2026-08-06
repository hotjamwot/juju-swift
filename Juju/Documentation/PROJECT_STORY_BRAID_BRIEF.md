# Project Story View — "The Braid" Overhaul (Handoff Brief)

**Status:** ✅ **COMPLETE** (Aug 2026). The View rewrite, tests, and build verification are all done. This document is retained as a design reference for the Braid feature.

**Date:** 2026-08-05 (updated 2026-08-06)
**Author:** Previous Cline session (handoff) + completing session
**Owner:** Hayden

---

## 1. The Goal

Overhaul `ProjectStoryView` to fit Juju's Editorial design language and tell the project's story better through phases. The chosen direction is **"The Braid"** — a dual-track timeline that handles the reality that **phases are not always chronological**.

### Why "The Braid"?

The user uses phases in three different ways, often within the same project:
1. **Chronological phases** — Discovery → Development → Launch.
2. **Sub-projects within a master project** — jumped between, not sequential.
3. **Collaborators or facets** — e.g. "Misc Writing" appearing throughout.

The previous design (`ProjectStoryPhaseTimelineView`) rendered phases as a single stacked horizontal bar where segment width = `durationMinutes / totalDurationMinutes`. This is a **pie chart disguised as a timeline** — it implies "this came after that", which is false for non-chronological phases. The date ticks beneath it were positioned by chronology, so the ticks and the segments didn't even line up.

The Braid fixes this by making the **session spine** the only chronological track (sessions happened when they happened — always honest), and rendering phases as **parallel lanes** (one row per phase) whose marks are positioned by date. A phase you jump in/out of shows scattered marks; a chronological phase shows a cluster; a collaborator phase shows their sessions across the whole span.

---

## 2. What Was Done

### `Juju/Core/ViewModels/ProjectStoryViewModel.swift` — ✅ COMPLETE

1. **`PhaseLane` struct** added (Identifiable, Equatable). One per phase, carrying:
   - `id` (phaseID, or `"__unphased__"` for nil/unknown)
   - `title`, `isArchivedPhase`, `phaseIndex` (for color lookup)
   - `sessions` (chronological), `startDate`, `endDate`
   - `totalDurationMinutes`, `sessionCount`, `averageMood`, `milestoneCount`
   - `recentActionLines: [String]` — up to 3 most recent **distinct non-empty** action lines from **non-milestone** sessions, newest first. This is the new narrative texture (previously only milestone actions were shown).
   - `weeklyDensity: [DensityBucket]` — for a mood sparkline in the detail panel.

2. **`@Published private(set) var phaseLanes: [PhaseLane] = []`** added.

3. **`nonisolated static func derivePhaseLanes(from:project:calendar:) -> [PhaseLane]`** added. It:
   - Groups sessions by phase (nil/unknown → `"__unphased__"`).
   - Computes per-lane stats and recent action lines.
   - Sorts lanes by `totalDurationMinutes` descending, with `"__unphased__"` pinned to the bottom.

4. **`reload()`** now calls `phaseLanes = Self.derivePhaseLanes(from: sessions, project: project, calendar: calendar)`.

### `Juju/Features/Projects/ProjectStory/ProjectStoryView.swift` — ✅ REWRITTEN

The file was fully rewritten with the Braid design:

- **`ProjectStoryBraidView`** (new core component): chronological session spine (72pt) + one `PhaseLaneRow` per phase + axis labels + pinned `PhaseDetailPanel`.
- **`PhaseDetailPanel`** (new): pinned strip showing phase colour dot, title, archived badge, date range, weeks, total time, avg mood, milestone count, and up to 3 recent distinct non-milestone action lines.
- **`PhaseLaneRow`** (new): fixed-width title label (80pt) + date-positioned mark track.
- **`ProjectStoryNotableMomentsView`** (modified): added `onHoverPhase: (String?) -> Void` callback for phase cross-highlight.
- **Removed**: `ProjectStoryPhaseTimelineView`, `ProjectStoryTimelineTicksView`, `ProjectStoryIntensityMoodChartView`, `phaseTooltip(for:)`.
- **Kept**: `ColorFamily`, `Array` safe subscript, `PhasePill`, `NotableMomentCard`, `StoryMetricCard`, `ProjectStoryHeaderView`, `ProjectStorySummaryRowView`, back-button header, `#Preview` (updated to use Braid).

### `Juju/Core/Models/SessionModels.swift` — ✅ ONE-LINE FIX

Added `Equatable` conformance to `SessionRecord` so `PhaseLane: Equatable` can synthesize its `==` operator. This was a pre-existing build break in the saved ViewModel changes.

### `JujuTests/ProjectStoryDerivationTests.swift` — ✅ 3 TESTS ADDED

- `testDerivePhaseLanes_groupsByPhaseWithoutAssumingChronology` — verifies interleaved phases group correctly without assuming contiguity.
- `testDerivePhaseLanes_surfacesRecentActionLinesFromNonMilestones` — verifies newest-first, deduped, milestone-excluded action lines.
- `testDerivePhaseLanes_unphasedPinnedToBottom` — verifies the unphased lane sorts last.

**Note on test expectation**: The original brief expected `["Second action", "First action"]` for the action-lines test, but the implementation correctly produces `["First action", "Second action"]` — because "First action" appears on both Jan 1 and Jan 3, and the newest occurrence (Jan 3) is kept, placing it before "Second action" (Jan 2). The test was updated to match the correct dedup-by-newest-occurrence behaviour.

### What's preserved (do not remove)

- `phaseTimeline: [PhaseSegment]` and `derivePhaseTimeline(...)` are **kept** for backward compatibility / safety. The new view does NOT use them, but removing them is optional cleanup — only do so if you confirm nothing else references them (search first). The existing `ProjectStoryDerivationTests` do **not** test `derivePhaseTimeline`, so removing it is safe from a test perspective.
- `phaseBoundaries`, `items`, `chapters`, `allMilestones` — still derived and used by Notable Moments.

---

## 3. Design / Theme Rules (from AGENT.md and Theme.swift)

- **No new colours.** Use `Theme.Colors.*` and project colours only. `milestone` / `milestoneHighlight` for milestones.
- **Fonts:** `Theme.Fonts.caption` (10pt) for labels/axis, `Theme.Fonts.body` (12pt) for action lines, `Theme.Fonts.subheader` (12pt semibold) for section headers, `Theme.Fonts.title` (16pt) for metric values.
- **Spacing:** 8pt grid via `Theme.Spacing.*`. Outer padding `Theme.spacingLarge` (24pt) horizontal in the scroll content (matches original).
- **Corner radius:** `Theme.Row.cornerRadius` (10pt) for cards/lanes, `Theme.Design.blockCornerRadius` (5pt) for bars.
- **Tooltips:** The pinned `PhaseDetailPanel` is preferred over a floating tooltip inside the ScrollView. If a floating tooltip is ever added, use `TooltipContainer` / `TooltipRow` / `TooltipDivider` from `Juju/Shared/TooltipViews.swift`. **Never inline tooltip styling.**
- **Hover detection in charts:** N/A — the Braid uses `GeometryReader` + `.onHover`, not SwiftUI Charts. The `chartOverlay` rule in AGENT.md only applies if you switch to `Chart`.
- **Cross-highlight pattern:** `highlightedPhaseID` and `highlightedMilestoneSessionID` are lifted to `ProjectStoryView` (parent). Bindings are passed down. This matches the "Cross-Highlight Pattern" in AGENT.md.

---

## 4. Build Verification (completed)

```bash
xcodebuild -scheme Juju -destination 'platform=macOS' build 2>&1 | tail -30   # ✅ BUILD SUCCEEDED
xcodebuild -scheme Juju -destination 'platform=macOS' test 2>&1 | tail -30    # ✅ TEST SUCCEEDED (22 tests)
```

---

## 5. Out of Scope / Future Enhancements (do not implement now)

- **Mood sparkline** in `PhaseDetailPanel` using `lane.weeklyDensity`. The data is ready; the rendering is a follow-up. For now, just show `Avg mood 7.2` as text.
- **Mood line on the spine** (the old view was named `IntensityMoodChartView` but never plotted mood). Follow-up.
- **Removing `phaseTimeline` / `derivePhaseTimeline` / `phaseBoundaries`** — optional cleanup once the new view is confirmed working. Search the codebase first; the old `ProjectStoryPhaseTimelineView` (deleted) was the only consumer.
- **Edge-aware floating tooltip** for individual session bars — the pinned `PhaseDetailPanel` covers the phase case; per-session tooltips are a follow-up if desired.
- **Known minor bugs** in the Braid view are under review (per Hayden, Aug 2026).

---

## 6. File Reference

| File | State | Action |
|------|-------|--------|
| `Juju/Core/ViewModels/ProjectStoryViewModel.swift` | ✅ Done | `PhaseLane` + `derivePhaseLanes` + `phaseLanes` published + wired into `reload()`. |
| `Juju/Features/Projects/ProjectStory/ProjectStoryView.swift` | ✅ Rewritten | Braid view + PhaseDetailPanel + PhaseLaneRow + Notable Moments phase callback. |
| `Juju/Core/Models/SessionModels.swift` | ✅ Fixed | Added `Equatable` conformance to `SessionRecord`. |
| `JujuTests/ProjectStoryDerivationTests.swift` | ✅ Updated | 3 lane-derivation tests added. |
| `Juju/Shared/Theme.swift` | ✅ Reference | Colours/fonts/spacing. |
| `Juju/Shared/TooltipViews.swift` | ✅ Reference | `TooltipContainer` if adding floating tooltips. |
| `Juju/Shared/Extensions/Color+Extensions.swift` | ✅ Reference | `lightenedByLuminance()` and `Color.lightenedHex`. |
| `Juju/Documentation/AGENT.md` | ✅ Reference | UI patterns, tooltip rules, cross-highlight pattern. |
| `Juju/Documentation/ARCHITECTURE.md` | ✅ Updated | ProjectStory section now documents the Braid. |
| `Juju/Documentation/ROADMAP.md` | ✅ Updated | Project Story section reflects the Braid. |
| `Juju/Documentation/CHANGELOG.md` | ✅ Updated | Aug 2026 entry for the Braid overhaul. |

---

## 7. One-Paragraph Summary

`ProjectStoryView` was redesigned as "The Braid": a dual-track timeline where the top track (spine) is a chronological bar chart of sessions coloured by phase, and the bottom tracks are one lane per phase with marks positioned by date — honest about the fact that phases aren't always chronological (they can be sub-projects, collaborators, or interleaved). Hovering a phase lane highlights its bars in the spine and shows a pinned `PhaseDetailPanel` with date range, total time, mood, milestone count, and recent action lines (surfacing `SessionRecord.action` from non-milestone sessions for the first time). The ViewModel work (`PhaseLane` model + `derivePhaseLanes`) was already saved; this session completed the View rewrite, added 3 lane-derivation tests, fixed a pre-existing build break (`SessionRecord` needed `Equatable` for `PhaseLane: Equatable`), corrected one test expectation (dedup-by-newest-occurrence), and verified the build + full test suite (22 tests passing).