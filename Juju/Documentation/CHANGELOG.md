# Juju Changelog

**Purpose**: Chronological log of significant features, changes, and fixes. Updated each time a meaningful change lands. See **ROADMAP.md** for project status and ongoing work.

---

## Aug 2026

- **Narrative engine rolling 30-day focus/project + cleanup**: The FOCUS and PROJECT metric cards now rank top-3 activity types and projects by a **rolling 30-day window** (today + preceding 29 days) instead of month-to-date, giving a consistent month-long view that doesn't reset on the 1st. Also retired the unused comparative-analytics subsystem from `NarrativeEngine` (`PeriodSessionData`, `ComparativeAnalytics`, `AnalyticsTrends`, `TrendChange`, `getSessionData`, `getComparativeData`, `generateHeadline(for:)`, `calculateTrends`, `pctChange`, `distChanges`, `calculateAverageDailyHours`, `calculateActivityDistribution`, `calculateProjectDistribution`, `getTimeRange`, and `ChartTimePeriod.previousPeriod`/`calendarComponent`). Updated `NarrativeEngine`, `ARCHITECTURE.md`.
- **Day Session Info Panel default 7am–7pm rail**: the per-day timeline rail in `DaySessionInfoPanel` now defaults to a 7am–7pm window instead of stretching to fit whatever hours the day's sessions happen to span. If any session starts before 7am or ends after 7pm, the rail stretches (with the existing 0.5h padding) to accommodate it, so out-of-hours work stays visible without cramping in-hours days. Updated `computeTimelineRange` in `DaySessionInfoPanel`.
- **90-Day Timeline chart**: Replaced the 90-day stacked bar chart with a time-of-day timeline. Each session renders as a thin vertical sliver positioned by its start/end hour within its calendar-day column (Y-axis 6am–11pm, matching the weekly calendar chart). Hovering anywhere in a day column shows the existing `DaySessionInfoPanel` with that day's sessions. Cross-midnight sessions split into two slivers. Fully retired `Session90DayBarChartView`, `ProjectSegment`, `DayStack.segments`, and `stackedDailyProjectTotals`; added `DayTimelineSession` model, `DayProjectInfo` for per-day project lookups, `prepare90DayTimeline` preparer method (builds both slivers and day stacks), and `Session90DayTimelineView`. `DaySessionInfoPanel` now resolves project colours via `DayStack.projects` instead of segments.
- **Narrative engine monthly focus/project + rolling avg week**: The FOCUS and PROJECT metric cards at the top of the Overview Dashboard now rank by **month-to-date** sessions (1st → today) instead of the current week, giving a fairer representation of where you've been. The THIS WEEK card's delta now compares against the **average active week over a rolling 12-month window** (weeks with at least one session, excluding the current partial week) instead of the previous calendar week. UI delta label updated to "vs avg week". Updated `NarrativeEngine`, `OverviewDashboardView`, and `ARCHITECTURE.md`.

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