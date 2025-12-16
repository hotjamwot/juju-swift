# Yearly Dashboard Build Plan

## Overview
Build three yearly charts for the yearly dashboard with small, testable steps. Each phase must be fully testable before moving to the next.

## Architecture Decision
**Keep yearly logic in existing `ChartDataPreparer.swift`** - Add yearly methods to the existing file with clear MARK comments to separate weekly and yearly functionality. This avoids code duplication and maintains consistency.

## Current Year Focus
- Start with current year only (2025)
- Future year navigation will be Phase 5 (separate phase as requested)
- Clean navigation between weekly/yearly dashboards already exists

## Phase 1: Project Distribution Chart (Right Column Top)

### 1.1 Create Project Yearly Data Models
- Add `YearlyProjectChartData` model to `ChartModels.swift`
- Add `YearlyProjectDataPoint` model for individual data points
- Include project name, emoji, total hours, percentage
- Add current year filtering logic

**Testable Outcome**: New models compile and can be instantiated with test data

### 1.2 Extend ChartDataPreparer with Project Yearly Methods
- Add MARK comments: `// MARK: - Yearly Project Data`
- Create `YearlyPrepareProjectData()` method
- Implement current year session filtering
- Create aggregation method to sum duration by project
- Add method to get yearly project totals

**Testable Outcome**: Project yearly data preparation methods work and return testable data

### 1.3 Build YearlyProjectBarChartView
- Create `YearlyProjectBarChartView.swift` in Yearly folder
- Horizontal bar chart showing total duration by project
- Project name and emoji on left, left-aligned bars on right
- Sort in descending order
- Use existing theme colors and styling
- Include proper chart title and labels

**Testable Outcome**: Complete project yearly chart displays correctly with proper sorting and styling

## Phase 2: Activity Types Distribution Chart (Right Column Bottom) ✅ COMPLETE

### 2.1 Create Activity Types Yearly Data Models ✅
- ✅ Added `YearlyActivityTypeChartData` model to `ChartModels.swift`
- ✅ Added `YearlyActivityTypeDataPoint` model for individual data points
- ✅ Include activity name, emoji, total hours, percentage
- ✅ Reuse current year filtering logic
- ✅ **Filtering**: Only include active (non-archived) activity types

**Testable Outcome**: New models compile and can be instantiated with test data ✅

### 2.2 Extend ChartDataPreparer with Activity Types Yearly Methods ✅
- ✅ Added MARK comments: `// MARK: - Yearly Activity Types Data`
- ✅ Created `yearlyActivityTypeTotals()` method
- ✅ Created `aggregateYearlyActivityTypeTotals(from:)` method to sum duration by activity type
- ✅ Added method to get yearly activity type totals
- ✅ **Filtering**: Only include sessions for active activity types using `ActivityTypeManager.shared.getActiveActivityTypes()`

**Testable Outcome**: Activity types yearly data preparation methods work and return testable data ✅

### 2.3 Build YearlyActivityTypeBarChartView ✅
- ✅ Created `YearlyActivityTypeBarChartView.swift` in Yearly folder
- ✅ Horizontal bar chart showing total duration by activity type
- ✅ Activity name and emoji on left, left-aligned bars on right
- ✅ Sort in descending order
- ✅ **Styling**: Use accent color for all bars (no individual colors per activity type)
- ✅ **Visual Separation**: Rely on emoji differentiation and spacing between bars
- ✅ **Layout**: Match ProjectYearlyBarChartView structure exactly
- ✅ **Activity Names**: Use 160pt width for activity names (same as projects)
- ✅ **Hour Count**: Use 40pt width, right-aligned, textSecondary color, caption font
- ✅ **Spacing**: Use Theme.spacingMedium between bars, Theme.spacingSmall within elements
- ✅ **Bars**: Height 10pt, consistent with project chart
- ✅ **Background**: No background color (transparent)
- ✅ **Borders**: No secondary outline or overlay borders
- ✅ **Hidden Items**: Show "Activity types not shown" as bottom-right overlay, right-aligned, limited to 45% width only IF active activity count exceeds 10
- ✅ **Alignment**: Left-align all content, use consistent emoji sizing (16pt)
- ✅ **Data**: Show absolute hours with one decimal point (e.g., "123.4 h")
- ✅ **Tooltips**: Include activity name, total hours, and percentage on hover
- ✅ **Filtering**: Only display active (non-archived) activity types
- ✅ **Layout Optimization**: Uses 45% width allocation (vs 55% for projects) to better accommodate different content volumes (12 projects vs 7 activity types)
- ✅ **Enhanced Project Display**: Shows 13 projects (increased from 10) with "Projects not shown" section when active projects exceed 13

**Testable Outcome**: Complete activity types yearly chart displays correctly with consistent accent color styling, matching the established project chart design patterns ✅

## Phase 3: Monthly Activity Breakdown Chart (Left Column)

### 3.1 Create Monthly Yearly Data Models
- Add `YearlyMonthlyChartData` model to `ChartModels.swift`
- Add `YearlyMonthlyDataPoint` model for individual data points
- Include month name and activity breakdown data
- **Monthly Chart Design**: Total duration bar length with breakdown by activity types within each month
- **Visual Style**: Grouped bars with emojis for identification and accent color variations (lightness/opacity) for differentiation
- **Data Presentation**: Show absolute hours (not percentages)
- **Note**: Visual design now clarified - grouped bars with activity type breakdown

**Testable Outcome**: New models compile and can be instantiated with test data

### 3.2 Extend ChartDataPreparer with Monthly Yearly Methods
- Add MARK comments: `// MARK: - Yearly Monthly Data`
- Create `prepareYearlyMonthlyData()` method
- Create aggregation method to group sessions by month and activity type
- Add method to get monthly breakdown data

**Testable Outcome**: Monthly yearly data preparation methods work and return testable data

### 3.3 Build YearlyMonthlyActivityChartView
- Create `YearlyMonthlyActivityChartView.swift` in Yearly folder
- Vertical layout with months (Jan-Dec)
- Most likely broken down by activity types within each month
- Include proper chart title and month labels
- Consider summary frame below for year-end insights

**Testable Outcome**: Complete monthly chart displays with proper month layout and activity breakdown

### 3.4 Consider Summary Frame
- Evaluate need for additional summary frame below monthly chart
- Similar to editorial content on weekly dashboard
- Could provide year-end insights and summaries
- **Decision Point**: Determine during implementation based on visual layout

**Testable Outcome**: Monthly chart with or without summary frame, based on design decisions

## Phase 4: Integration & Polish

### 4.1 Connect Charts to YearlyDashboardView
- Replace placeholder views with actual chart implementations
- Wire up data binding between charts and data preparer
- Ensure proper data flow and updates

**Testable Outcome**: All three charts display live data from the app

### 4.2 Performance Optimization
- Add caching for yearly data (similar to weekly charts)
- Optimize data loading and aggregation
- Ensure smooth performance with large datasets

**Testable Outcome**: Charts load quickly and update efficiently

### 4.3 Final Testing
- Comprehensive testing of all charts
- Test with various data scenarios
- Verify navigation between weekly/yearly dashboards
- Ensure data consistency and accuracy

**Testable Outcome**: Complete, working yearly dashboard ready for use

## Phase 5: Future Enhancements (Separate Project)

### 5.1 Year Navigation System
- Implement year selector (previous/next year)
- Update data filtering for selected year
- Clean navigation UI between years
- **Note**: Separate from current implementation

## Key Technical Considerations

### Data Filtering
- Use current year interval for initial implementation
- Filter sessions to current year only
- Leverage existing session management systems

### Performance
- Follow existing caching patterns from weekly charts
- Use efficient aggregation methods
- Consider ProjectStatisticsCache for yearly data

### Consistency
- Follow existing chart patterns and styling from weekly dashboard
- Use Theme file for consistent colors and fonts
- Maintain similar interaction patterns

### Future-Proofing
- Design data models to support multiple years
- Keep year navigation logic separate for easy addition later
- Use clear naming conventions for yearly vs weekly data

## Questions for Design Decisions

### Monthly Chart Design
1. Should monthly chart show total duration per month, or break down by activity types?
2. What visual style works best for monthly breakdown?
3. Is a summary frame below the monthly chart needed for year-end insights?

### Data Presentation
1. What time period should we use for "current year" filtering?
2. Should charts show percentages or absolute values?
3. Any specific color schemes or visual styles to follow?

### User Experience
1. How should charts handle empty data scenarios?
2. What interactions (tooltips, clicks) should charts support?
3. Any specific loading states or animations needed?

## Success Criteria

Each phase must be:
- ✅ **Testable**: Can be opened, built, and visually verified
- ✅ **Functional**: Works with real data from the app
- ✅ **Consistent**: Matches existing UI/UX patterns
- ✅ **Performant**: Loads and updates efficiently

## Implementation Notes

### File Naming Convention
- **All yearly dashboard files must include "Yearly" prefix**:
  - `YearlyProjectBarChartView.swift`
  - `YearlyActivityTypeBarChartView.swift`
  - `YearlyMonthlyActivityChartView.swift`
  - Data models: `YearlyProjectChartData`, `YearlyActivityTypeChartData`, etc.
- This ensures clear separation and easy identification of yearly vs weekly components

### Activity Types Styling Approach
- **No individual colors per activity type** - use consistent accent color for all bars
- **Visual separation through**:
  - Distinct emojis for each activity type
  - Proper spacing between bars
  - Clear labels and titles
  - Consistent layout matching project chart

### Development Approach
- Start with simplest chart (Project Distribution) to establish visual style
- Use existing Theme system for consistent styling
- Leverage existing chart libraries and components
- Maintain separation between data logic and presentation
- Document any new data models or API changes
- Test each phase thoroughly before proceeding to next
