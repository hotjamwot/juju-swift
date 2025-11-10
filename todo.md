# Dashboard Layout and Chart Changes - Implementation Plan

## Task Overview
Implement significant changes to the Dashboard layout and charts as requested:
1. Move BubbleChartCardView to its own pane below the current second pane
2. Replace the BubbleChartCardView in the second pane with a new YearlyTotalBarChart
3. Create a new minimalist bubble chart view that visualizes all recorded work sessions
4. Update the Dashboard layout to accommodate these changes

## Current Layout Analysis
- DashboardNativeSwiftChartsView contains the main dashboard layout
- Current second pane has BubbleChartCardView on left and Summary Metrics on right
- BubbleChartCardView is currently in the second pane
- SummaryMetricView shows total hours, sessions, and average duration

## Implementation Steps

### Phase 1: Layout Changes
- [x] Modify DashboardNativeSwiftChartsView to restructure the layout
- [x] Move BubbleChartCardView to a new third pane
- [x] Replace BubbleChartCardView in second pane with YearlyTotalBarChart
- [x] Update the layout to have 3 panes instead of 2

### Phase 2: YearlyTotalBarChart Implementation
- [x] Create new YearlyTotalBarChartView.swift file
- [x] Implement horizontal bar chart with project labels and values
- [x] Add project icons to the left side of bars
- [x] Implement descending sort by hours
- [x] Add inline value display (104.5 h) at end of bars
- [x] Implement minimal gridlines/axis

### Phase 3: New BubbleChart Implementation
- [x] Create new BubbleChartView.swift file
- [x] Implement Canvas-based bubble chart visualization
- [x] Implement X position mapping from 1 Jan → 31 Dec
- [x] Implement Y position with jittered placement
- [x] Implement bubble size based on session duration
- [x] Implement bubble color from project color
- [x] Implement transparency based on mood tag
- [x] Add optional month dividers
- [x] Implement frame size of ~1000 × 300 px
- [x] Add transition animations for bubbles

### Phase 4: Data Integration
- [x] Update ChartDataPreparer to provide necessary session data for new bubble chart
- [x] Ensure data flows properly to new chart components
- [x] Test with existing data

### Phase 5: Testing and Refinement
- [x] Test new YearlyTotalBarChart with sample data
- [x] Test new BubbleChartView with sample data
- [x] Verify layout changes work correctly
- [x] Ensure all data is properly displayed
- [x] Optimize performance for large datasets
- [x] Fix compilation errors in BubbleChartView

## Files to Create/Modify

### New Files:
- Juju/Features/Dashboard/YearlyTotalBarChartView.swift
- Juju/Features/Dashboard/BubbleChartView.swift

### Modified Files:
- Juju/Features/Dashboard/DashboardNativeSwiftChartsView.swift

## Technical Details

### YearlyTotalBarChart Requirements:
- Left side: category labels (project) with optional icons
- Right side: horizontal bars scaled to represent hours logged
- Exact value displayed inline at bar's end (104.5 h)
- Sorted descending from most to least hours
- Minimal gridlines/axis
- Use SwiftUI with horizontal BarMark

### BubbleChartView Requirements:
- Size: ~1000 × 300 px (responsive width; fixed visual ratio)
- No axes or labels - purely visual composition
- Canvas for efficient rendering of 600+ bubbles
- X Position: date mapped linearly from 1 Jan → 31 Dec
- Y Position: Randomised or project-based offset
- Size: session duration scaled by duration
- Colour: project colour from projects.json
- Transparency: based on session 'mood' tag
- Shadow: optional soft shadow for layering depth
- Visual Style: Organic scatter pattern, no grid, lines, or axis indicators
- Optional faint month dividers (12 subtle vertical lines)
- Slight alpha blending for dense periods
- Bubbles fade in/out on appearance or data refresh

## Implementation Approach

1. First, analyze the current layout structure in DashboardNativeSwiftChartsView
2. Create the new YearlyTotalBarChartView with proper SwiftUI implementation
3. Create the new BubbleChartView with Canvas-based rendering
4. Update the layout to accommodate the new structure
5. Ensure data flows properly between ChartDataPreparer and new chart components
6. Test all components with sample data
