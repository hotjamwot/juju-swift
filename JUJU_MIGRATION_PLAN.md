# Juju Dashboard Migration Plan: WKWebView to Native Swift

## Overview
This document outlines the migration plan for transforming the web-based Juju dashboard (currently using WKWebView and Chart.js) into a native Swift implementation using modern iOS/macOS charting libraries.

## Current State Analysis

### Current Implementation
- **Charts Tab**: WKWebView + Chart.js for data visualization
  - Yearly chart (line chart)
  - Weekly chart (line chart) 
  - Pie chart (project distribution)
  - Bar chart (project time breakdown)
  - Date range filters (Last 7 Days, Last Month, etc.)
- **Sessions Tab**: WKWebView + HTML table
  - Session listing with pagination
  - Project filtering
  - Date filtering
  - Export functionality (TXT, CSV, MD)
- **Projects Tab**: Already implemented natively in SwiftUI
  - Project grid management
  - Add/edit/delete projects
  - Color selection

### Key Dependencies
- Chart.js (via CDN)
- Custom JavaScript for data processing
- WKWebView for rendering
- Complex JavaScript-Swift bridge for data exchange

## Migration Strategy

### Phase 1: Setup and Dependencies
1. **Add Charting Library**
   - Implement Chart library (e.g., SwiftUI Charts or native Core Plot)
   - Set up package dependencies in Xcode

2. **Create Chart Components**
   - NativeSwiftChartsView.swift (main container)
   - YearlyChartView.swift (line chart)
   - WeeklyChartView.swift (line chart)
   - ProjectPieChartView.swift (pie chart)
   - ProjectBarChartView.swift (bar chart)

### Phase 2: Data Processing
1. **Migrate Chart Data Preparation**
   - Move JavaScript chart data logic to Swift
   - Create ChartDataPreparers.swift
   - Implement date range filtering logic

2. **Update Chart Models**
   - Create ChartModels for each chart type
   - Implement ChartViewModel for data management

### Phase 3: Dashboard Views
1. **NativeDashboardView.swift**
   - Replace WebDashboardView
   - Implement chart grid layout
   - Add date filter controls
   - Match existing UI styling

2. **SessionTableView.swift**
   - Replace SessionsView (if needed)
   - Implement native table with pagination
   - Add project and date filtering
   - Implement export functionality

### Phase 4: Integration
1. **Update SwiftUIDashboardRootView**
   - Replace WebDashboardView with NativeDashboardView
   - Remove WKWebView dependency
   - Update tab navigation logic

2. **Clean Up Bridge Code**
   - Remove DashboardWebViewController
   - Clean up WKWebView-related code
   - Remove JavaScript polyfills

### Phase 5: Testing and Optimization
1. **Performance Testing**
   - Compare rendering performance
   - Test memory usage
   - Validate chart responsiveness

2. **UI/UX Validation**
   - Ensure visual parity with web version
   - Test all interactions
   - Validate data accuracy

## Technical Implementation Details

### Chart Library Selection
- **SwiftUI Charts** (preferred for native macOS)
- **Core Plot** (alternative for more customization)
- **Charts** library (if SwiftUI Charts insufficient)

### Data Flow
```
SessionManager → ChartDataPreparer → ChartViewModel → ChartView
```

### UI Components
- **Charts Grid**: SwiftUI LazyVGrid matching web layout
- **Date Filters**: Native SwiftUI controls
- **Project Filters**: Reuse existing SwiftUI components
- **Session Table**: SwiftUI List with pagination

### File Structure Changes
```
Juju/
├── Views/
│   ├── Dashboard/
│   │   ├── NativeDashboardView.swift
│   │   ├── ChartViews/
│   │   │   ├── YearlyChartView.swift
│   │   │   ├── WeeklyChartView.swift
│   │   │   ├── ProjectPieChartView.swift
│   │   │   └── ProjectBarChartView.swift
│   │   └── ChartData/
│   │       ├── ChartDataPreparer.swift
│   │       ├── ChartModels.swift
│   │       └── ChartViewModel.swift
│   ├── Sessions/
│   │   ├── SessionTableView.swift
│   │   ├── SessionFilters.swift
│   │   └── SessionExport.swift
│   └── Projects/
│       └── (Already implemented)
├── WebDashboardView.swift → (Delete)
├── DashboardWebViewController.swift → (Delete)
└── dashboard-web/ → (Can be removed after migration)
```

## Migration Benefits
1. **Performance**: Native rendering without WebView overhead
2. **Memory Usage**: Reduced memory footprint
3. **Maintainability**: Swift codebase instead of mixed JS/Swift
4. **Integration**: Better integration with macOS ecosystem
5. **Offline Support**: Charts work without internet connection

## Risk Assessment
- **High Risk**: Complex chart visualizations may not have exact parity
- **Medium Risk**: Performance regression if not optimized properly
- **Low Risk**: Minor UI differences that can be adjusted

## Success Criteria
1. All charts render correctly with same data
2. Date filtering works identically to web version
3. Session table matches web version functionality
4. Export functionality works for all formats
5. Performance meets or exceeds current implementation
6. No WKWebView dependencies remain
