# Swift Tuple Access Errors - Fix Plan

## Task Overview
Fix tuple access errors in BubbleChartCardView.swift and WeeklyProjectBubbleChartView.swift

## Errors to Fix
- Line 46-47 in BubbleChartCardView.swift: Tuple has no member 'bubble' and 'index'
- Line 47-48 in WeeklyProjectBubbleChartView.swift: Tuple has no member 'bubble' and 'index'

## Root Cause
The code creates tuples `(index, bubble, diameter: CGFloat)` but tries to access them as named properties instead of tuple elements.

## Implementation Steps
- [x] Create a struct to replace tuple for better type safety
- [x] Fix BubbleChartCardView.swift tuple access patterns
- [x] Fix WeeklyProjectBubbleChartView.swift tuple access patterns  
- [x] Test the fixes by compiling the code
- [x] Verify all errors are resolved

## Additional Improvements
- [x] Improved bubble sizing to prevent overflow
- [x] Enhanced packing algorithm to ensure proper centering of largest bubble
- [x] Consistent maxDiameter values between both chart views

## Files to Modify
- Juju/Features/Dashboard/BubbleChartCardView.swift
- Juju/Features/Dashboard/WeeklyProjectBubbleChartView.swift
