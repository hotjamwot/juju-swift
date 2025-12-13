# Juju Dashboard Refactoring Plan
 
## Overview
Streamlined two-page dashboard system focused on weekly and yearly views with modular, responsive components.

## Current Architecture

### File Structure
```
Juju/Features/Dashboard/
├── Shared/
│   └── ActiveSessionStatusView.swift (floating, always visible)
├── Weekly/
│   ├── WeeklyDashboardView.swift (main weekly dashboard with responsive layout)
│   ├── WeeklyEditorialView.swift (standalone editorial narrative component)
│   ├── WeeklyActivityBubbleChartView.swift (activity types visualization)
│   └── SessionCalendarChartView.swift (session distribution visualization)
├── Yearly/
│   ├── YearlyDashboardView.swift (complete yearly dashboard with all charts)
│   ├── YearlyTotalBarChartView.swift (projects breakdown)
│   ├── WeeklyStackedBarChartView.swift (52-week distribution)
│   └── StackedAreaChartCardView.swift (monthly trends)
├── SummaryMetricView.swift (metrics display)
└── DashboardRootView.swift (main container)
```

### Responsive Layout Architecture
```
WeeklyDashboardView (Responsive Layout)
├── ActiveSessionStatusView (floating, always visible)
├── Top Row: Two-Column Layout
│   ├── Left Column: WeeklyEditorialView (35-40% width, min 300px, max 500px)
│   └── Right Column: WeeklyActivityBubbleChartView (remaining space, min 300px)
└── Second Row: Full-Width Layout
    └── SessionCalendarChartView (full width, responsive height 45-55%, min 350px, max 500px)
```


### Performance Optimization (Next Priority)
**Objective**: Optimize performance and implement lazy loading

#### Tasks:
- [ ] Implement lazy loading for yearly data
- [ ] Add caching for yearly chart calculations
- [ ] Optimize session filtering for different time periods
- [ ] Add loading states for yearly dashboard
- [ ] Test performance with large datasets
- [ ] Implement background data preparation

#### Expected Outcome:
- Yearly data loads on demand
- Improved performance with large session datasets
- Smooth user experience
- Efficient data caching

### UI/UX Polish
**Objective**: Enhance user interface and experience

#### Tasks:
- [ ] Design and implement navigation animations
- [ ] Add visual indicators for current view
- [ ] Improve button styling and placement
- [ ] Add loading animations
- [ ] Implement chart entry animations
- [ ] Test accessibility features
- [ ] Polish overall visual design

#### Expected Outcome:
- Smooth, professional animations
- Clear visual feedback for navigation
- Enhanced user experience
- Polished interface

### Testing and Bug Fixes
**Objective**: Ensure stability and fix any issues

#### Tasks:
- [ ] Comprehensive testing of all navigation flows
- [ ] Test with various session data scenarios
- [ ] Fix any performance regressions
- [ ] Address edge cases and error conditions
- [ ] Test on different screen sizes
- [ ] Validate data accuracy across views
- [ ] Performance testing with large datasets

#### Expected Outcome:
- Stable, bug-free implementation
- Consistent performance across scenarios
- All edge cases handled
- Reliable data display

## Technical Implementation Details

### ChartDataPreparer Methods
```swift
// Weekly-only data preparation
func prepareWeeklyData(sessions: [SessionRecord], projects: [Project])

// Yearly-only data preparation  
func prepareYearlyData(sessions: [SessionRecord], projects: [Project])

// Preserved yearly calculation methods:
- yearlyProjectTotals()
- yearlyTotalHours()
- yearlyTotalSessions()
- yearlyAvgDurationString()
- monthlyProjectTotals()
- weeklyStackedBarChartData()
```

### Component Benefits
- **Modularity**: Each component is independent and reusable
- **Responsiveness**: Layout adapts gracefully to different window sizes
- **Maintainability**: Easier to update individual components
- **Performance**: Optimized data loading with weekly-only filtering
- **User Experience**: Cleaner, more organized layout with better space utilization

## Dependencies

### Internal Dependencies
- SessionManager (for data loading)
- ChartDataPreparer (for data preparation)
- EditorialEngine (for narrative generation)
- ProjectsViewModel (for project data)

### External Dependencies
- SwiftUI Charts framework
- Core Data (for session storage)
- Foundation framework (for date calculations)

## Success Metrics

### User Experience Metrics
- Clear navigation between views
- Focused weekly dashboard experience
- Comprehensive yearly analysis
- Professional, polished interface

### Code Quality Metrics
- Separation of concerns between views
- Reusable components
- Clean, maintainable code
- Comprehensive error handling