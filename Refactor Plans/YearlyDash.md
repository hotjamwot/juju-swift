### Current State Analysis

** What's Working Well:**
- ✅ Excellent modularity with separate chart components
- ✅ Responsive layout with dynamic sizing calculations
- ✅ Clean separation between weekly and yearly views
- ✅ Efficient data preparation with filtering by time period
- ✅ Good use of GeometryReader for responsive layouts

**Current Yearly Dashboard Components:**
1. **This Year Section** - Yearly total bar chart + summary metrics
2. **Weekly Stacked Bar Chart** - 52-week project distribution
3. **Stacked Area Chart** - Monthly trends by project

### Key Issues Identified

**1. Visual Hierarchy Problems:**
- The "This Year" section has complex dynamic height calculations that can cause layout instability
- Three charts compete for attention without clear storytelling flow
- Summary metrics feel cramped next to the bar chart

**2. Data Redundancy:**
- Weekly stacked bar chart shows project distribution (same as yearly total bar chart, just more granular)
- Monthly stacked area chart also shows project distribution over time
- Both charts essentially tell the same story: "Which projects did I work on?"

**3. Performance Considerations:**
- Loading all yearly data at once for multiple charts
- Complex calculations for dynamic heights and layouts

### Recommended Yearly Dashboard Structure

**Option A: Streamlined & Focused (Recommended)**

```
Yearly Dashboard (3 main sections):

1. HERO SECTION - "This Year in Review"
   ┌─────────────────────────────────────────────────────────┐
   │  Juju Logo + Dynamic Headline                             │
   │  "This year you logged 480h. Your focus was Film, where  │
   │   you spent 180h on Project X."                           │
   ├─────────────────────────────────────────────────────────┤
   │  LEFT: Yearly Project Distribution (donut/pie chart)     │
   │  RIGHT: Yearly Summary Metrics (3 cards)                 │
   └─────────────────────────────────────────────────────────┘

2. MONTHLY TRENDS
   ┌─────────────────────────────────────────────────────────┐
   │  Stacked Area Chart - "Monthly Project Distribution"     │
   │  Shows how project focus shifted throughout the year     │
   └─────────────────────────────────────────────────────────┘

3. ACTIVITY BREAKDOWN
   ┌─────────────────────────────────────────────────────────┐
   │  Yearly Activity Bubble Chart                            │
   │  Shows time distribution by activity type (Writing,      │
   │  Editing, Admin, etc.) - NEW COMPONENT                   │
   └─────────────────────────────────────────────────────────┘
```

**Option B: Data-Rich (Alternative)**

```
1. HERO SECTION (same as Option A)
2. MONTHLY TRENDS (same as Option A)
3. PROJECT PERFORMANCE
   ┌─────────────────────────────────────────────────────────┐
   │  Horizontal Bar Chart - "Top 10 Projects by Hours"       │
   │  Shows project ranking with clear winners/losers         │
   └─────────────────────────────────────────────────────────┘
```

### Specific Recommendations

**1. Remove the Weekly Stacked Bar Chart**
- **Why:** It's redundant with the yearly total bar chart and monthly area chart
- **Keep:** The data preparation logic in `ChartDataPreparer` for future use
- **Benefit:** Cleaner visual hierarchy, less cognitive load

**2. Add Yearly Activity Breakdown**
- **New Component:** `YearlyActivityBubbleChartView` (similar to weekly version)
- **Data Source:** Use existing `aggregateActivityTotals()` method
- **Benefit:** Shows different dimension of data (activity types vs projects)

**3. Improve the "This Year" Section**
- **Simplify:** Fixed height layout instead of dynamic calculations
- **Better Visuals:** Use donut chart instead of horizontal bars for project distribution
- **Enhanced Metrics:** 3-column layout with icons and better typography

**4. Enhanced Storytelling**
- **Dynamic Headlines:** "This year you logged 480h. Your focus was Film, where you spent 180h on Project X."
- **Milestone Detection:** "You hit 100h on Project Y in March!"
- **Activity Insights:** "You were most productive in Writing (40% of time)"

### Implementation Plan

**Phase 1: Remove Redundancy**
1. Remove `WeeklyStackedBarChartView` from `YearlyDashboardView`
2. Keep the data preparation methods in `ChartDataPreparer` for future use
3. Update the layout to have 2 main sections instead of 3

**Phase 2: Add Activity Breakdown**
1. Create `YearlyActivityBubbleChartView` (similar to weekly version)
2. Add method to `ChartDataPreparer` for yearly activity totals
3. Integrate into yearly dashboard layout

**Phase 3: Enhance Visuals**
1. Create `YearlyProjectDonutChartView` for better project distribution visualization
2. Improve summary metrics layout with card-based design
3. Add dynamic editorial headline generation

**Phase 4: Responsive Optimization**
1. Simplify height calculations for better performance
2. Ensure all charts scale properly with window size
3. Add loading states and empty states

### Data Storytelling Flow

The yearly dashboard should tell this story:
1. **"Here's your year in numbers"** (Hero section with headline and metrics)
2. **"Here's how your focus shifted over time"** (Monthly trends)
3. **"Here's what you actually did"** (Activity breakdown)