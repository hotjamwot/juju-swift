# Filter & Export System Implementation Plan

## Overview
Replace the current combined FilterExportControls with a modern bottom-floating filter bar system that provides better separation of concerns and improved user experience.

## Design Requirements
- Bottom-floating filter bar that appears on hover
- Hidden by default, reveals from bottom of window
- All controls in a single horizontal row
- No titles or text labels - just dropdowns and icons
- Confirm and Export buttons on the same row as filter dropdowns
- Native macOS export dialog

## Current State Analysis

### Current Implementation
- **File**: `Juju/Features/Sessions/Components/FilterExportControls.swift`
- **Integration**: `Juju/Features/Sessions/SessionsView.swift`
- **Issues**:
  - Combined filter and export functionality
  - Takes up vertical space when expanded
  - No activity type filtering
  - Automatic refresh prevents seeing filtered results during editing
  - Export uses simple dropdown instead of native dialog

### Current Components
1. **FilterExportControls** - Combined filter and export panel
2. **FilterExportState** - State management for filters and export
3. **SessionsDateFilter** - Date filter enum (Today, This Week, This Month, This Year, Custom, Clear)
4. **ExportFormat** - Export format enum (CSV, TXT, Markdown)

## New Implementation Plan

### 1. Enhanced State Management

#### New FilterState Class
```swift
class FilterState: ObservableObject {
    @Published var isExpanded: Bool = false
    
    // Filter state
    @Published var projectFilter: String = "All"
    @Published var activityTypeFilter: String = "All"
    @Published var selectedDateFilter: SessionsDateFilter = .thisWeek
    @Published var customDateRange: DateRange? = nil
    
    // Manual refresh control
    @Published var shouldRefresh: Bool = false
    
    func requestManualRefresh() {
        shouldRefresh.toggle()
    }
    
    func clearFilters() {
        projectFilter = "All"
        activityTypeFilter = "All"
        selectedDateFilter = .thisWeek
        customDateRange = nil
    }
}
```

### 2. Bottom Floating Filter Bar

#### BottomFilterBar Component
- **Location**: `Juju/Features/Sessions/Components/BottomFilterBar.swift`
- **Features**:
  - Hidden by default, slides up from bottom
  - Connects to bottom of window
  - Single horizontal row layout
  - All controls inline (no titles/text)
  - Minimal downward chevron to close

#### Layout Structure
```
┌─────────────────────────────────────────────────────────┐
│ [📁 Project ▼] [🎨 Activity ▼] [📅 Date ▼] [✅] [⬇️] [▲] │
└─────────────────────────────────────────────────────────┘
```

**Controls (left to right)**:
1. **Project Dropdown** - Project selection with emoji
2. **Activity Type Dropdown** - Activity type selection with emoji
3. **Date Filter Dropdown** - Date range selection
4. **Confirm Button** - Apply filters and refresh sessions
5. **Export Button** - Native macOS export dialog
6. **Close Chevron** - Hide filter bar

### 3. Hover Activation System

#### FilterToggleButton Component
- **Location**: `Juju/Features/Sessions/Components/FilterToggleButton.swift`
- **Features**:
  - Hidden by default
  - Appears when cursor hovers bottom 20% of window
  - Minimal upward chevron icon
  - Smooth fade/slide animation

#### Activation Logic
```swift
// Detect hover in bottom 20% of window
.onHover { hovering in
    if hovering {
        let windowFrame = NSApplication.shared.keyWindow?.frame ?? .zero
        let bottomArea = windowFrame.height * 0.2
        if mouseLocation.y < bottomArea {
            showFilterBar = true
        }
    }
}
```

### 4. Native Export System

#### NativeExportButton Component
- **Location**: `Juju/Features/Sessions/Components/NativeExportButton.swift`
- **Features**:
  - Triggers native macOS NSSavePanel
  - Exports currently filtered sessions
  - Auto-generates filename with date range
  - Supports CSV, TXT, Markdown formats
  - No format dropdown needed

#### Export Flow
1. User clicks export button
2. Native NSSavePanel appears
3. User selects location and filename
4. System exports filtered sessions
5. Success notification

### 5. Activity Type Filtering

#### Enhanced Activity Type Support
- **Integration**: Use existing `ActivityTypeManager.shared`
- **Display**: Show emoji + name in dropdown
- **Filtering**: Filter sessions by activity type ID
- **Fallback**: Handle legacy sessions without activity types

#### Activity Type Dropdown
```swift
Picker("Activity", selection: $filterState.activityTypeFilter) {
    Text("All").tag("All")
    ForEach(activityTypesViewModel.activeActivityTypes) { type in
        HStack {
            Text(type.emoji)
            Text(type.name)
        }.tag(type.id)
    }
}
.pickerStyle(.menu)
```

### 6. Manual Refresh System

#### Refresh Logic
- **Current Behavior**: Filters auto-apply when changed
- **New Behavior**: Filters only apply when Confirm button is clicked
- **Session Editing**: Changes don't auto-refresh filters
- **User Control**: Explicit control over when filters take effect

#### Implementation
```swift
// In SessionsView
.onChange(of: filterState.shouldRefresh) { _ in
    Task {
        await applyCurrentFilters()
    }
}

// Confirm button action
func confirmFilters() {
    filterState.requestManualRefresh()
}
```

## Implementation Steps

### Phase 1: State Management & Core Components
1. ✅ Create enhanced `FilterState` class with activity type support
2. ✅ Create `BottomFilterBar` component
3. ✅ Create `FilterToggleButton` component
4. ✅ Create `NativeExportButton` component

### Phase 2: Integration & Filtering
5. ✅ Add activity type filtering to SessionsView
6. ✅ Implement manual refresh system
7. ✅ Update session filtering logic
8. ✅ Add hover detection for filter toggle

### Phase 3: Polish & Testing
9. ✅ Add animations and transitions
10. ✅ Test with various screen sizes
11. ✅ Verify export functionality
12. ✅ Performance optimization

## File Structure Changes

### New Files
```
Juju/Features/Sessions/Components/
├── BottomFilterBar.swift          # Main floating filter panel
├── FilterToggleButton.swift       # Hover-activated toggle button
├── NativeExportButton.swift       # Native macOS export dialog
└── FilterState.swift              # Enhanced state management
```

### Modified Files
```
Juju/Features/Sessions/
├── SessionsView.swift             # Update to use new components
└── Components/
    └── FilterExportControls.swift # Mark as deprecated/replace
```

## UI/UX Improvements

### Visual Design
- **Minimal**: No titles, just icons and dropdowns
- **Consistent**: Same height and padding for all controls
- **Clear**: Obvious visual separation between filter and action buttons
- **Native**: Standard macOS UI patterns

### Animations
- **Smooth**: 0.3s ease-in-out transitions
- **Subtle**: Gentle slide-up from bottom
- **Responsive**: Quick hover detection (0.1s delay)

### Accessibility
- **Keyboard**: Full keyboard navigation support
- **Screen Reader**: Proper accessibility labels
- **Contrast**: High contrast for all elements

## Technical Considerations

### Performance
- **Lazy Loading**: Only load filter bar when needed
- **Efficient Filtering**: Use existing session data structures
- **Memory**: Clean up observers when filter bar hidden

### Compatibility
- **Window Sizes**: Responsive design for different window sizes
- **macOS Versions**: Support for macOS 12.0+
- **Screen Sizes**: Adapt to various screen resolutions

### Future Extensibility
- **New Filters**: Easy to add mood, phase, or other filters
- **Bulk Operations**: Foundation for future bulk edit features
- **Presets**: Potential for saved filter presets

## Success Criteria

### Functional Requirements
- [ ] Filter bar appears on hover in bottom 20% of window
- [ ] All controls in single horizontal row
- [ ] No titles or text labels
- [ ] Confirm button applies filters
- [ ] Export button uses native macOS dialog
- [ ] Activity type filtering works correctly
- [ ] Manual refresh system prevents auto-updates

### User Experience
- [ ] Clean, modern interface
- [ ] Intuitive hover activation
- [ ] Smooth animations and transitions
- [ ] Responsive to different window sizes
- [ ] Accessible keyboard navigation

### Technical Quality
- [ ] Clean, maintainable code
- [ ] Proper state management
- [ ] Efficient filtering algorithms
- [ ] No memory leaks or performance issues
- [ ] Comprehensive error handling

## Risk Assessment

### Low Risk
- UI layout and styling
- Basic filtering functionality
- Export dialog integration

### Medium Risk
- Hover detection accuracy
- Window size responsiveness
- State synchronization

### Mitigation Strategies
- Thorough testing on different window sizes
- Clear separation of concerns between components
- Comprehensive error handling and user feedback

## Timeline Estimate
- **Phase 1**: 2-3 days
- **Phase 2**: 2-3 days  
- **Phase 3**: 1-2 days
- **Total**: 5-8 days

## Dependencies
- Existing `ActivityTypeManager` for activity type filtering
- `SessionManager` for session data and export functionality
- `Theme` system for consistent styling
- `NSOpenPanel`/`NSSavePanel` for native file dialogs
