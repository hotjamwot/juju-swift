# Tooltip Implementation Plan for Session Calendar Chart

## Overview
This document outlines the comprehensive plan for implementing tooltips in the Session Calendar Chart view. The tooltips will display project name and session notes when hovering over session rectangles in the chart.

## Current State Analysis

### Existing Tooltip Implementation
- **File**: `Juju/Shared/TooltipView.swift`
- **Current Structure**: Simple tooltip with projectName and hours
- **Limitations**: 
  - Only shows project name and duration
  - Missing session notes
  - No positioning logic
  - No hover interaction handling

### Session Calendar Chart View
- **File**: `Juju/Features/Dashboard/SessionCalendarChartView.swift`
- **Current Features**:
  - Uses SwiftUI Charts framework
  - RectangleMark for session visualization
  - Each session shows project emoji and duration
  - Uses WeeklySession data model
- **Data Available**: day, startHour, endHour, projectName, projectColor, projectEmoji

### Data Models
- **WeeklySession**: Limited to basic session info (no notes)
- **SessionRecord**: Contains full session data including notes
- **ChartEntry**: Contains complete session data including notes

## Implementation Requirements

### 1. Enhanced Tooltip Data Structure
**Need to extend tooltip to show:**
- Project name (currently supported)
- Session notes (currently missing)
- Project emoji (currently missing from tooltip)

### 2. Hover Interaction System
**Requirements:**
- Detect hover over specific session rectangles
- Track mouse position for tooltip placement
- Handle hover state transitions
- Support both mouse and trackpad interactions

### 3. Tooltip Positioning Strategy
**Considerations:**
- Avoid tooltip overlap with chart elements
- Dynamic positioning based on available space
- Tooltip should follow cursor or appear near session rectangle
- Handle edge cases (tooltip near screen edges)

### 4. Data Integration
**Need to:**
- Extend WeeklySession model or create new tooltip data model
- Include session notes from SessionRecord
- Maintain data consistency between chart and tooltip

## Detailed Implementation Plan

### Phase 1: Data Model Enhancement
1. **Create TooltipSessionData model**
   ```swift
   struct TooltipSessionData: Identifiable {
       let id = UUID()
       let day: String
       let startHour: Double
       let endHour: Double
       let projectName: String
       let projectColor: String
       let projectEmoji: String
       let notes: String
       let duration: Double
   }
   ```

2. **Extend WeeklySession or create mapping**
   - Option A: Add notes field to WeeklySession
   - Option B: Create mapping function from SessionRecord to TooltipSessionData
   - **Recommended**: Option B to maintain separation of concerns

### Phase 2: Enhanced Tooltip View
1. **Update TooltipView.swift**
   - Add notes parameter
   - Add project emoji display
   - Improve layout for better readability
   - Add optional notes section (handle empty notes)

2. **New Tooltip Design**
   ```
   ┌─────────────────────────┐
   │ 🎬 Film Project         │
   │                         │
   │ "This is the session    │
   │  notes text that could  │
   │  wrap to multiple lines"│
   └─────────────────────────┘
   ```

### Phase 3: Hover Interaction Implementation
1. **Add hover state management**
   ```swift
   @State private var hoveredSession: TooltipSessionData? = nil
   @State private var tooltipPosition: CGPoint = .zero
   ```

2. **Implement hover detection**
   - Use `.onHover` modifier on RectangleMark
   - Track mouse position with `.simultaneousGesture`
   - Handle hover exit with timer for smooth transitions

3. **Chart Integration Strategy**
   ```swift
   RectangleMark(...)
       .onHover { isHovering in
           if isHovering {
               // Show tooltip
           } else {
               // Hide tooltip with delay
           }
       }
   ```

### Phase 4: Tooltip Positioning System
1. **Position calculation logic**
   - Calculate optimal position based on session rectangle position
   - Consider chart boundaries and available space
   - Implement smart positioning (above/below/left/right)

2. **Positioning algorithm**
   ```swift
   func calculateTooltipPosition(for session: TooltipSessionData, 
                                in chartFrame: CGRect) -> CGPoint {
       // Calculate optimal position
       // Return CGPoint for tooltip placement
   }
   ```

### Phase 5: Session Data Integration
1. **Data preparation in SessionCalendarChartView**
   - Create mapping from sessions to TooltipSessionData
   - Include notes from SessionRecord if available
   - Handle missing notes gracefully

2. **Update chart data flow**
   ```swift
   let tooltipSessions: [TooltipSessionData] = sessions.map { session in
       // Transform WeeklySession to TooltipSessionData
       // Include notes from SessionRecord
   }
   ```

### Phase 6: Visual Enhancements
1. **Session rectangle hover effects**
   - Add subtle scaling or border effects
   - Improve visual feedback for hover state
   - Maintain accessibility standards

2. **Tooltip styling improvements**
   - Better typography hierarchy
   - Improved spacing and padding
   - Enhanced shadow and background
   - Support for dark mode

## Technical Considerations

### SwiftUI Charts Limitations
- **Challenge**: Limited hover support in native Charts framework
- **Solution**: Use overlay approach with custom gesture handling
- **Alternative**: Consider custom chart implementation if needed

### Performance Optimization
- **Lazy tooltip creation**: Only create tooltip view when needed
- **Efficient hover detection**: Minimize gesture handling overhead
- **Memory management**: Proper cleanup of hover states

### Accessibility
- **Keyboard navigation**: Support for keyboard users
- **Screen reader**: Ensure tooltip content is accessible
- **Focus management**: Proper focus handling for tooltips

### Edge Cases
1. **No notes available**: Handle empty or missing notes gracefully
2. **Long notes**: Implement text truncation with "..." for very long notes
3. **Multiple sessions**: Handle overlapping sessions appropriately
4. **Screen boundaries**: Ensure tooltip doesn't go off-screen
5. **Small screens**: Adapt tooltip for different screen sizes

## Implementation Timeline

### Week 1: Foundation
- [ ] Create TooltipSessionData model
- [ ] Update TooltipView with enhanced design
- [ ] Implement basic hover detection

### Week 2: Integration
- [ ] Integrate hover system with SessionCalendarChartView
- [ ] Implement tooltip positioning logic
- [ ] Add session data mapping

### Week 3: Polish & Testing
- [ ] Add visual enhancements and hover effects
- [ ] Implement accessibility features
- [ ] Test edge cases and fix issues
- [ ] Performance optimization

### Week 4: Finalization
- [ ] Cross-platform testing (macOS)
- [ ] User testing and feedback
- [ ] Final refinements
- [ ] Documentation and cleanup

## Success Criteria

### Functional Requirements
- [ ] Tooltips appear on hover over session rectangles
- [ ] Tooltips display project name, emoji, notes, and duration
- [ ] Tooltips position correctly without overlapping chart elements
- [ ] Smooth hover transitions and animations
- [ ] Handles edge cases gracefully

### Performance Requirements
- [ ] No noticeable performance impact on chart rendering
- [ ] Smooth hover interactions (60fps)
- [ ] Efficient memory usage

### User Experience Requirements
- [ ] Intuitive and discoverable interaction
- [ ] Clear visual feedback for hover states
- [ ] Accessible to all users including keyboard navigation
- [ ] Consistent with app design language

## Risk Assessment

### High Risk
- **Charts framework limitations**: May require custom implementation
- **Performance impact**: Complex hover detection could affect performance

### Medium Risk
- **Data consistency**: Ensuring tooltip data matches session data
- **Cross-platform compatibility**: macOS-specific hover behavior

### Low Risk
- **Visual design**: Tooltip styling and positioning
- **Edge case handling**: Various screen sizes and orientations

## Dependencies
- **SessionRecord data**: Access to complete session information including notes
- **Project data**: Access to project emoji and color information
- **Theme system**: Consistent styling with app theme

## Future Enhancements
- **Clickable tooltips**: Allow clicking on tooltip for more actions
- **Rich text support**: Support for formatted notes
- **Multi-session tooltips**: Handle multiple overlapping sessions
- **Animation enhancements**: More sophisticated tooltip animations
