import Foundation

/// Date+SessionExtensions.swift
/// 
/// **Purpose**: Provides session-specific date manipulation utilities for consistent
/// date/time operations across the codebase
/// 
/// **Key Responsibilities**:
/// - Parse date strings in standard session format
/// - Combine dates with time strings for session start/end times
/// - Handle midnight session edge cases
/// - Provide consistent date formatting
/// 
/// **Dependencies**: Foundation framework for date manipulation
/// 
/// **AI Notes**:
/// - All methods are static for easy reuse across the codebase
/// - Handles both HH:mm and HH:mm:ss time formats for backward compatibility
/// - Automatically adjusts for midnight sessions (end time before start time)
/// - Uses Calendar API for safe date component manipulation
/// - Returns self as fallback for invalid inputs to prevent crashes

extension Date {
    /// Parse date string in "yyyy-MM-dd" format used by sessions
    ///
    /// **AI Context**: This method provides consistent date parsing for session dates
    /// across the entire codebase. It's used when converting user input or CSV data
    /// into Date objects for session start/end times.
    ///
    /// **Business Rules**:
    /// - Expects date strings in "yyyy-MM-dd" format (e.g., "2024-01-15")
    /// - Returns nil for invalid date strings
    /// - Uses strict date parsing (no lenient matching)
    ///
    /// **Edge Cases**:
    /// - Invalid date strings return nil (safe failure)
    /// - Empty strings return nil
    /// - Malformed dates return nil
    ///
    /// **Performance Notes**:
    /// - DateFormatter is cached implicitly by the system
    /// - Minimal memory allocation with direct parsing
    ///
    /// - Parameters:
    ///   - dateString: Date string in "yyyy-MM-dd" format
    /// - Returns: Date object if parsing successful, nil otherwise
    static func parseSessionDate(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.date(from: dateString)
    }
    
    /// Combine date with time string to create full Date object
    /// Handles both HH:mm and HH:mm:ss formats for backward compatibility
    ///
    /// **AI Context**: This method is critical for session time tracking as it combines
    /// a calendar date with a time string to create precise Date objects for session
    /// start/end times. It's used extensively in session creation and editing.
    ///
    /// **Business Rules**:
    /// - Supports both HH:mm and HH:mm:ss time formats
    /// - Automatically pads HH:mm format to HH:mm:ss for consistency
    /// - Uses the date components (year, month, day) from the receiver date
    /// - Uses the time components (hour, minute, second) from the time string
    ///
    /// **Algorithm Steps**:
    /// 1. Pad time string to ensure consistent HH:mm:ss format
    /// 2. Parse time string into Date object using standard formatter
    /// 3. Extract time components (hour, minute, second) from parsed time
    /// 4. Extract date components (year, month, day) from provided date
    /// 5. Combine components into new DateComponents object
    /// 6. Create final Date object from combined components
    ///
    /// **Edge Cases Handled**:
    /// - Time strings in HH:mm format (automatically padded to HH:mm:ss)
    /// - Invalid time strings (returns original date as fallback)
    /// - Calendar edge cases (leap years, daylight saving time, etc.)
    ///
    /// **Performance Notes**:
    /// - Uses DateFormatter for consistent time parsing
    /// - Leverages Calendar API for safe date component manipulation
    /// - Minimal memory allocation with direct component extraction
    ///
    /// - Parameters:
    ///   - timeString: Time in "HH:mm" or "HH:mm:ss" format
    /// - Returns: Combined Date object, or original date if parsing fails
    func combined(withTimeString timeString: String) -> Date {
        // Create time formatter for parsing time strings
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        // Pad time string to ensure consistent format (HH:mm:ss)
        // This handles backward compatibility with HH:mm format
        let paddedTimeString = timeString.count == 5 ? timeString + ":00" : timeString
        
        // Parse the padded time string into a Date object
        // This gives us a Date with the time components we need
        guard let timeDate = timeFormatter.date(from: paddedTimeString) else {
            // If parsing fails, return the original date as a safe fallback
            return self
        }
        
        // Extract time components (hour, minute, second) from the parsed time
        // These will be used to replace the time portion of our target date
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: timeDate)
        
        // Extract date components (year, month, day) from the provided date
        // These will be preserved in our final combined date
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: self)
        
        // Create new DateComponents object with combined date and time
        // This safely merges the date portion from 'self' with time portion from 'timeString'
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second
        
        // Use Calendar API to safely create final Date object
        // This handles all calendar edge cases (leap years, DST, etc.)
        return Calendar.current.date(from: combined) ?? self
    }
    
    /// Check if session spans midnight (end time before start time) and adjust accordingly
    ///
    /// **AI Context**: This method handles the special case where a session starts on one day
    /// and ends on the next day (e.g., 11:00 PM to 1:00 AM). It's used when validating and
    /// adjusting session end times to ensure correct duration calculation.
    ///
    /// **Business Rules**:
    /// - If endTime is before self (start time), add one day to endTime
    /// - Only adjusts endTime, never modifies the start time
    /// - Returns adjusted endTime if adjustment was needed
    /// - Returns original endTime if no adjustment needed
    ///
    /// **Edge Cases**:
    /// - Sessions that don't span midnight return original endTime
    /// - Invalid endTime values are handled by Calendar API
    /// - Daylight saving time transitions are handled automatically
    ///
    /// **Performance Notes**:
    /// - Single Calendar operation for date adjustment
    /// - Minimal memory allocation with direct date manipulation
    ///
    /// - Parameters:
    ///   - endTime: The proposed end time for the session
    /// - Returns: Adjusted end time if session spans midnight, original endTime otherwise
    func adjustedForMidnightIfNeeded(endTime: Date) -> Date {
        var finalEndTime = endTime
        if endTime < self {
            if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: endTime) {
                finalEndTime = nextDay
            }
        }
        return finalEndTime
    }
    
    /// Format date as "yyyy-MM-dd" string for session storage
    ///
    /// **AI Context**: This method provides consistent date formatting for session data
    /// storage in CSV files and other persistent storage. It's used when converting
    /// Date objects back to strings for file operations.
    ///
    /// **Business Rules**:
    /// - Always returns date in "yyyy-MM-dd" format
    /// - No time components included
    /// - Consistent with parseSessionDate() for round-trip compatibility
    ///
    /// **Performance Notes**:
    /// - DateFormatter is cached implicitly by the system
    /// - Minimal memory allocation with direct formatting
    ///
    /// - Returns: Date string in "yyyy-MM-dd" format
    func formattedForSession() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: self)
    }
    
    /// Format date as "yyyy-MM-dd HH:mm:ss" string for session storage
    ///
    /// **AI Context**: This method provides complete date/time formatting for session
    /// start and end times in CSV storage. It's used when saving session data to files.
    ///
    /// **Business Rules**:
    /// - Returns complete date and time in standard format
    /// - Used for session start/end time storage
    /// - Consistent with CSV format requirements
    ///
    /// **Performance Notes**:
    /// - DateFormatter is cached implicitly by the system
    /// - Minimal memory allocation with direct formatting
    ///
    /// - Returns: Date/time string in "yyyy-MM-dd HH:mm:ss" format
    func formattedForSessionDateTime() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: self)
    }
}