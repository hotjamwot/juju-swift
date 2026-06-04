# Dashboard Refactor Plan: From Grid Containers to Free-Flowing LazyVStack

**Last Updated**: 04 June 2026
**Status**: Active

## 🎯 Vision

Instead of cramming charts into rigid ratio-based grid containers, each chart sits at its **natural/ideal height** and fills **full width**. The dashboard becomes a scrollable LazyVStack — charts breathe with their own negative space, and consistent margins + typography provide visual separation.

**Design Principles:**
- **No more `DashboardLayout`** (deprecated) — no ratio-based `GeometryReader` grids
- **No cards/containers** — charts float freely on the background. Separation comes from spacing and data alignment, not background fills
- **Each chart defines its own `idealHeight`** — content determines height, not a percentage of the window
- **Full-width charts** — every chart spans the available dashboard content width
- **ScrollView + LazyVStack** — natural vertical scrolling, lazy loading for performance
- **ActiveSessionStatusView stays** — it's just the first item in the LazyVStack, appearing/disappearing naturally
- **Horizontal paging stays** — overview/yearly pages remain horizontally swipeable, each now independently scrollable vertically

## 🏗️ Architecture Changes

### Before
```
DashboardRootView
  └── Horizontal ScrollView (paging)
        ├── OverviewDashboardView
        │     └── GeometryReader
        │           └── DashboardLayout (ratio-based grid)
        │                 ├── ChartContainer { SessionHeatMapView }
        │                 ├── ChartContainer { NarrativeSummaryCard }
        │                 └── ChartContainer { SessionCalendarChartView }
        └── YearlyDashboardView
              └── GeometryReader
                    └── DashboardLayout (ratio-based grid)
                          ├── ChartContainer { MonthlyActivityTypeGrouped }
                          ├── ChartContainer { YearlyProjectBarChart }
                          └── ChartContainer { YearlyActivityTypeBar }
```

### After
```
DashboardRootView
  └── Horizontal ScrollView (paging)
        ├── OverviewDashboardView (containerRelativeFrame .horizontal)
        │     └── ScrollView (.vertical) + LazyVStack
        │           ├── [optional] ActiveSessionStatusView
        │           ├── SessionHeatMapView (minHeight: 200)
        │           ├── NarrativeSummaryCard (minHeight: 220)
        │           └── SessionCalendarChartView (minHeight: 340)
        └── YearlyDashboardView (containerRelativeFrame .horizontal)
              └── ScrollView (.vertical) + LazyVStack
                    ├── [optional] ActiveSessionStatusView
                    ├── MonthlyActivityTypeGrouped (minHeight: 520)
                    ├── YearlyProjectBarChart (minHeight: 380)
                    └── YearlyActivityTypeBar (minHeight: 340)
```

## 📐 Japandi Design — No Cards, No Containers

Visual order comes from:
- **Consistent left/right margins** on all chart content (via `.padding(.horizontal, dashboardPadding)`)
- **Vertical spacing between charts** (16–24pt gap in LazyVStack)
- **Typography hierarchy** — chart titles, labels, and data values create structure
- **Data alignment** — everything lines up along the same left/right edges

## 📄 Files to Modify / Create

| File | Change |
|---|---|
| `Juju/Features/Dashboard/Shared/ChartCardView.swift` | Delete — not needed for no-card approach |
| `Juju/Features/Dashboard/Overview/OverviewDashboardView.swift` | Rewrite body: ScrollView + LazyVStack. Remove GeometryReader + DashboardLayout. Charts get `.padding(.horizontal, dashboardPadding)` and `.frame(minHeight:)` |
| `Juju/Features/Dashboard/Yearly/YearlyDashboardView.swift` | Same pattern as Overview |
| `Juju/Features/Dashboard/Shared/DashboardLayout.swift` | Deprecate layout logic, keep `BottomNavigationCircles` |
| `Juju/Features/Dashboard/DashboardRootView.swift` | May need minor adjustments |

## 🔄 Migration Steps

1. Rewrite `OverviewDashboardView.swift` — ScrollView + LazyVStack at natural heights, no containers
2. Rewrite `YearlyDashboardView.swift` — same pattern
3. Update `DashboardLayout.swift` — deprecate layout, keep `BottomNavigationCircles`
4. Remove `ChartCardView.swift` from Xcode project
5. Build and verify compilation
6. Verify ActiveSessionStatusView pushes content naturally
7. Verify horizontal paging still works

## 🧪 Testing Notes

- **Compilation test**: Build the project after changes
- **Visual test**: Run the app, verify overview and yearly dashboards render correctly at their natural heights
- **Active session test**: Start a session, verify the status bar appears at top of LazyVStack and pushes charts down
- **Scroll test**: Verify vertical scroll works on each page
- **Page navigation test**: Verify horizontal swipe between overview and yearly still works