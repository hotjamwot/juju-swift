# Swift Tuple Access Errors - Fix Plan

## Task Overview
Fix tuple access errors in BubbleChartCardView.swift and WeeklyProjectBubbleChartView.swift

## Errors to Fix
- Line 46-47 in BubbleChartCardView.swift: Tuple has no member 'bubble' and 'index'
- Line 47-48 in WeeklyProjectBubbleChartView.swift: Tuple has no member 'bubble' and 'index'

## Root Cause
The code creates tuples `(index, bubble, diameter: CGFloat)` but tries to access them as named properties instead of tuple elements.

## Implementation Steps
- [ ] Create a struct to replace tuple for better type safety
- [ ] Fix BubbleChartCardView.swift tuple access patterns
- [ ] Fix WeeklyProjectBubbleChartView.swift tuple access patterns  
- [ ] Test the fixes by compiling the code
- [ ] Verify all errors are resolved

## Files to Modify
- Juju/Features/Dashboard/BubbleChartCardView.swift
- Juju/Features/Dashboard/WeeklyProjectBubbleChartView.swift
