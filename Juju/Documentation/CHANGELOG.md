# Juju Changelog

**Purpose**: Chronological log of significant features, changes, and fixes. Updated each time a meaningful change lands. See **ROADMAP.md** for project status and ongoing work.

---

## Aug 2026

- **Card visual language overhaul**: Cards across the dashboard and project story now have a clear, consistent visual identity. The Surface colour was brightened (#1E1C1A → #25221F) so cards read as a visible step above the background instead of a barely-there tint. All card surfaces are now full-opacity (no more arbitrary 0.5/0.6/0.7 dilution), all use the standard 12pt corner radius (retired the mix of 10pt and 5pt card radii), and all now carry the previously-unused `subtleShadow()` for lift. Yearly project/activity charts gained surface backgrounds to match the rest of the dashboard. Nested elements within cards now use `background` for contrast instead of dimmer surface opacity. Added a CARD RULES block to `Theme.swift`'s design philosophy documenting the full-opacity / 12pt / shadow system so future changes keep to the vibe, plus a shared `cardStyle()` View modifier. Updated `Theme.swift`, `Surface.colorset`, `ProjectStoryView`, `DaySessionInfoPanel`, `YearlyProjectBarChartView`, `YearlyActivityTypeBarChartView`, `ActiveSessionStatusView`, `OverviewDashboardView`, `ProjectsView`, `ActivityTypeView`, `ProjectSidebarEditView`, `TooltipViews`.
- **Bulk edit UX overhaul**: Selected sessions now show a clear visual indicator — an accent-coloured border and a checkmark badge in the top-right corner. The Bulk Edit button transforms into the confirm button while in bulk edit mode, showing a tick icon and the selected session count ("✓ 3 selected"), so confirming bulk edits is always one obvious click away. The session list no longer refreshes when individual session changes are made during bulk edit — it only refreshes once you hit the confirm button, keeping the selection stable while you work. Removed the separate Save & Exit button from the bulk edit bar. Updated `SessionsRowView`, `BottomFilterBar`, `SessionsView`.
- **Phase filter in Sessions Tab**: Added a Phase dropdown to the Sessions filter bar, letting you filter sessions by project phase (e.g. "Planning", "Execution", "Review") or by "Uncategorized" for sessions with no phase assigned. When a project filter is active, the phase dropdown shows only that project's phases; otherwise it shows phases from all active projects with a project colour dot and project name for disambiguation. Added `hasPhase` to `SessionRecord+Filtering`, `filteredByPhase` to `Array+SessionExtensions`, `phaseFilter` state to `FilterExportState`, and the `filterPhaseDropdown` UI to `BottomFilterBar`. Updated `SessionsView` to apply the phase filter in `getFilteredSessions()`.
- **Project Story "The Braid" overhaul**: Replaced the old phase timeline bar + intensity chart in `ProjectStoryView` with a dual-track timeline. The top track (spine) is a chronological bar chart of sessions coloured by phase; the bottom tracks are one lane per phase with date-positioned marks — honest about the fact that phases aren't always chronological (they can be sub-projects, collaborators, or interleaved). Hovering a phase lane highlights its bars in the spine and reveals a pinned `PhaseDetailPanel` with date range, total time, average mood, milestone count, and up to 3 recent distinct non-milestone action lines (surfacing `SessionRecord.action` for the first time). Notable Moments now cross-highlight phases in the Braid. Added `PhaseLane` model + `derivePhaseLanes` to `ProjectStoryViewModel`, 3 new lane-derivation tests, and `Equatable` conformance on `SessionRecord`. Removed `ProjectStoryPhaseTimelineView`, `ProjectStoryTimelineTicksView`, `ProjectStoryIntensityMoodChartView`, and `phaseTooltip(for:)`. Updated `ProjectStoryView`, `ProjectStoryViewModel`, `SessionModels`, `ProjectStoryDerivationTests`, `ARCHITECTURE.md`, `ROADMAP.md`.
- **Narrative engine rolling 30-day focus/project + cleanup**: The FOCUS and PROJECT metric cards now rank top-3 activity types and projects by a **rolling 30-day window** (today + preceding 29 days) instead of month-to-date, giving a consistent month-long view that doesn't reset on the 1st. Also retired the unused comparative-analytics subsystem from `NarrativeEngine` (`PeriodSessionData`, `ComparativeAnalytics`, `AnalyticsTrends`, `TrendChange`, `getSessionData`, `getComparativeData`, `generateHeadline(for:)`, `calculateTrends`, `pctChange`, `distChanges`, `calculateAverageDailyHours`, `calculateActivityDistribution`, `calculateProjectDistribution`, `getTimeRange`, and `ChartTimePeriod.previousPeriod`/`calendarComponent`). Updated `NarrativeEngine`, `ARCHITECTURE.md`.
- **Day Session Info Panel default 7am–7pm rail**: the per-day timeline rail in `DaySessionInfoPanel` now defaults to a 7am–7pm window instead of stretching to fit whatever hours the day's sessions happen to span. If any session starts before 7am or ends after 7pm, the rail stretches (with the existing 0.5h padding) to accommodate it, so out-of-hours work stays visible without cramping in-hours days. Updated `computeTimelineRange` in `DaySessionInfoPanel`.
- **90-Day Timeline chart**: Replaced the 90-day stacked bar chart with a time-of-day timeline. Each session renders as a thin vertical sliver positioned by its start/end hour within its calendar-day column (Y-axis 6am–11pm, matching the weekly calendar chart). Hovering anywhere in a day column shows the existing `DaySessionInfoPanel` with that day's sessions. Cross-midnight sessions split into two slivers. Fully retired `Session90DayBarChartView`, `ProjectSegment`, `DayStack.segments`, and `stackedDailyProjectTotals`; added `DayTimelineSession` model, `DayProjectInfo` for per-day project lookups, `prepare90DayTimeline` preparer method (builds both slivers and day stacks), and `Session90DayTimelineView`. `DaySessionInfoPanel` now resolves project colours via `DayStack.projects` instead of segments.
- **Narrative engine monthly focus/project + rolling avg week**: The FOCUS and PROJECT metric cards at the top of the Overview Dashboard now rank by **month-to-date** sessions (1st → today) instead of the current week, giving a fairer representation of where you've been. The THIS WEEK card's delta now compares against the **average active week over a rolling 12-month window** (weeks with at least one session, excluding the current partial week) instead of the previous calendar week. UI delta label updated to "vs avg week". Updated `NarrativeEngine`, `OverviewDashboardView`, and `ARCHITECTURE.md`.
- **Narrative engine partial-week averaging for delta comparison**: The THIS WEEK card's delta now compares the current partial week (Mon → today) against the average of partial weeks (Mon → today's weekday offset) over a rolling 12-month window, instead of comparing against full Monday→Monday weeks. This ensures the comparison is apples-to-apples regardless of where in the week the dashboard is viewed. Updated `NarrativeEngine`, `ARCHITECTURE.md`, `CHANGELOG.md`.

## Jun 2026

- **Day Session Info Panel**: swapped out tooltips on our 90 day chart in favour of an info panel that lists the sessions of the day on hover, showing Action and Notes preview, duration and Activity Type. Brilliant insights.
- **Dashboard visual redesign (JapaScandi)**: Replaced rigid `DashboardLayout` ratio-based grid system with `ScrollView` + `LazyVStack`. Charts float at natural heights with consistent horizontal margins. Section headers left-aligned, 8pt header-to-content gap, 56pt section gap. Overview dashboard reordered: Narrative Cards → Calendar Chart → 90-Day Stacked Bar → Yearly Totals. NarrativeMetricCard redesigned with title+symbol top-left, centred data content, elevated card surface (#252526), equal 180pt minimum height. 90-day chart gains milestone tracking with hover-to-highlight (gold pill, dimmed bars). Dashboard padding increased to 48pt. Deprecated old ratio-based `DashboardLayout` constants.
- **Dynamic Cmd+Tab visibility**: app appears in app switcher only when windows (dashboard/notes) are open; switches to `.accessory` activation policy (hidden) when all windows are closed. Status item is recreated on policy switch to maintain menu bar icon. Updated `AppDelegate`, `DashboardWindowController`, `NotesManager` with window counting and `NSApplication.setActivationPolicy(_:)` calls.
- **Activity type emoji → SF Symbols migration**: renamed `emoji` field to `sfSymbol` across ActivityType model, all chart data models, rendering code, and JSON data. Updated SelectionItem protocol to support SF Symbols alongside emojis.

## May 2026

- **Bulk edit UX improvements**: toggle button in filter bar, Escape to exit, accented outline selection, phase dropdown enabled for same-project selections, dropdown values persist visually
- **Bulk session editing implemented** (double-click mode, filter bar integration, shift-click selection)
- **Documentation cleanup**: removed DATA_FLOW.yaml (redundant with ARCHITECTURE.md), added purpose statements to all docs, created ROADMAP.md
- **Project Story feature implemented** (working, UI ongoing)

## Mar 2026

- **Phase ID integrity implemented** (archive + remove-with-clear + display rules)

## Feb 2026

- **Action and milestone fields added to sessions**

## Jan 2026

- **Date-based session migration completed** (startDate/endDate transition)

## Nov 2025

- **Dashboard with overview/yearly views implemented**

---

*This file is updated as significant changes land. Keep entries concise, chronological (newest at top), and cross-reference relevant docs or code files where useful.*