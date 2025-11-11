# Plan: Replace BubbleChartView with Weekly Stacked Bar Chart

## Objective
Remove `BubbleChartView.swift` and its dependencies from `ChartDataPreparer.swift`, then replace it with a new vertical stacked bar chart showing every week of the current year with:
- X axis: Week of year (labeled with month abbreviations: J F M A M J J A S O N D)
- Y axis: Duration (hours)

## Phase 1: Analysis & Dependencies Mapping
- [x] Map all dependencies of BubbleChartView
- [x] Identify all bubble chart methods in ChartDataPreparer.swift
- [x] Document current data flow and usage patterns
- [x] Review existing chart components for reference

## Phase 2: Design New Data Structure
- [x] Design WeeklyStackedBarChart data model
- [x] Plan week-of-year aggregation logic
- [x] Design month label mapping for X-axis
- [x] Plan stacked bar data preparation
- [x] Define color scheme and project assignment strategy

## Phase 3: Extend ChartDataPreparer
- [x] Add new data model for weekly stacked bar chart
- [x] Create weekly data aggregation method
- [x] Add week-of-year calculation utilities
- [x] Create method to get weekly stacked bar chart data
- [x] Test data preparation logic

## Phase 4: Create New Chart View Component
- [x] Create WeeklyStackedBarChartView.swift
- [x] Implement SwiftUI Charts stacked bar chart
- [x] Add X-axis with month labels (J F M A M J J A S O N D)
- [x] Add Y-axis with duration formatting
- [x] Implement project color coding
- [x] Add hover/selection interactions
- [x] Handle empty data state
- [x] Apply theme consistency
- [x] Fix bar spacing and full year display

## Phase 5: Clean Up Bubble Chart Dependencies
- [x] Remove BubbleChartData struct from ChartDataPreparer.swift
- [x] Remove bubbleChartEntries() method from ChartDataPreparer.swift
- [x] Remove bubbleChartData() method from ChartDataPreparer.swift
- [x] Remove createLayeredPositions() helper method
- [x] Remove applySimpleCollisionAvoidance() helper method
- [x] Remove bubbleSize() helper method
- [x] Clean up any unused imports

## Phase 6: Remove BubbleChartView
- [x] Delete Juju/Features/Dashboard/BubbleChartView.swift file
- [x] Remove BubbleChartView_Previews struct if present elsewhere
- [x] Clean up any remaining bubble chart references

## Phase 7: Update Dashboard Integration
- [x] Import WeeklyStackedBarChartView in DashboardNativeSwiftChartsView.swift
- [x] Replace BubbleChartView() call with WeeklyStackedBarChartView()
- [x] Pass required data to new chart component
- [x] Adjust layout and spacing if needed
- [x] Test dashboard integration

## Phase 8: Testing & Verification
- [x] Test with empty data
- [x] Test with single project data
- [x] Test with multiple projects data
- [x] Verify week-of-year calculations
- [x] Verify month label mapping
- [x] Test responsiveness and layout
- [x] Verify theme consistency
- [x] Check for any compilation errors
- [x] Fix bar spacing and full year width display
- [x] Remove horizontal gridlines for cleaner look
- [x] Add centered month initials (J F M A M J J A S O N D)
- [x] Keep vertical gridlines only at month breaks

## Phase 9: Documentation & Cleanup
- [x] Update code documentation
- [x] Verify all TODO comments are resolved
- [x] Check for any remaining unused code
- [x] Final review of changes

## Technical Details

### Data Flow
1. Sessions → ChartDataPreparer → Weekly Data Aggregation → WeeklyStackedBarChartView

### New Data Model Structure
- WeeklyStackedBarChartData: Contains week number, month, and project hour breakdowns
- WeekOfYear: Calculated week number with month mapping
- ProjectWeeklyData: Individual project hours per week

### Chart Specifications
- Chart Type: Vertical Stacked Bar Chart (using SwiftUI Charts)
- X-axis: 52 weeks, labeled by month abbreviations
- Y-axis: Duration in hours
- Stacking: Projects stacked within each week bar
- Colors: Project-specific colors from existing project data
- Layout: Fixed 8px bars, no horizontal gridlines, vertical lines only at month boundaries
- Labeling: Single month initials centered in each month section

### Key Files Modified
- **Removed**: `Juju/Features/Dashboard/BubbleChartView.swift`
- **Modified**: `Juju/Core/Managers/ChartDataPreparer.swift`
- **Modified**: `Juju/Features/Dashboard/DashboardNativeSwiftChartsView.swift`
- **Created**: `Juju/Features/Dashboard/WeeklyStackedBarChartView.swift`
- **Modified**: `Juju/Core/Models/ChartModels.swift`

## Success Criteria - ALL COMPLETED ✅
- [x] BubbleChartView completely removed
- [x] All bubble chart methods removed from ChartDataPreparer
- [x] New weekly stacked bar chart displays correctly
- [x] X-axis shows weeks labeled with month abbreviations
- [x] Y-axis shows duration in hours
- [x] Multiple projects stack correctly within weekly bars
- [x] Chart handles empty data gracefully
- [x] Dashboard loads without errors
- [x] Theme consistency maintained
- [x] Full year displays across entire width
- [x] Appropriate bar spacing and sizing
- [x] Clean layout with no horizontal gridlines
- [x] Vertical gridlines only at month boundaries
- [x] Centered month initials for better readability
