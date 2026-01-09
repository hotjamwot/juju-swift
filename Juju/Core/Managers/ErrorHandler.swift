//
// ErrorHandler.swift
// Juju Project Tracking App
//
// MARK: - CENTRALIZED ERROR HANDLING SYSTEM
//
// Provides consistent error handling, user notifications, and recovery mechanisms
// across the entire application.
//

import Foundation
import SwiftUI

// MARK: - ErrorHandler Singleton
/// Enhanced error handling system with comprehensive logging and AI-friendly error reporting
///
/// **AI Context**: This class provides centralized error handling with detailed logging,
/// structured error information, and recovery strategies. It's designed to help AI assistants
/// understand error patterns and provide better debugging assistance.
///
/// **Key Features**:
/// - Structured error logging with severity levels
/// - Comprehensive debug logging for complex operations
/// - Automatic error recovery with retry mechanisms
/// - Detailed error reports for debugging
/// - Integration with JujuError for context-rich error messages
///
/// **Usage Pattern**:
/// ```swift
/// // BEFORE: Basic error handling
/// print("Error: \(error.localizedDescription)")
///
/// // AFTER: Enhanced error handling with context
/// ErrorHandler.shared.handleError(error, context: "SessionManager.startSession", severity: .error)
/// ```
class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    // MARK: - Error Severity Levels
    
    enum ErrorSeverity: Int, Comparable {
        case warning = 1    // Non-critical, can continue
        case error = 2      // Critical, may need user action
        case fatal = 3      // App cannot continue
        
        static func < (lhs: ErrorSeverity, rhs: ErrorSeverity) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Error Information Structure
    
    struct ErrorInfo: Identifiable {
        let id = UUID()
        let error: Error
        let severity: ErrorSeverity
        let context: String
        let timestamp: Date
        let canRetry: Bool
        let suggestedAction: String?
        let userMessage: String?
        
        init(error: Error, severity: ErrorSeverity, context: String, canRetry: Bool = false, suggestedAction: String? = nil, userMessage: String? = nil) {
            self.error = error
            self.severity = severity
            self.context = context
            self.timestamp = Date()
            self.canRetry = canRetry
            self.suggestedAction = suggestedAction
            self.userMessage = userMessage
        }
    }
    
    // MARK: - Error Logging
    
    private var errorLog: [ErrorInfo] = []
    private let maxLogSize = 100
    
    // MARK: - Public Error Handling Methods
    
    /// Handle an error with appropriate user feedback and logging
    /// - Parameters:
    ///   - error: The error to handle
    ///   - context: Context where the error occurred
    ///   - severity: Severity level of the error
    func handleError(_ error: Error, context: String, severity: ErrorSeverity = .error) {
        let errorInfo = ErrorInfo(
            error: error,
            severity: severity,
            context: context,
            canRetry: severity == .error, // Only allow retry for errors, not warnings or fatal
            suggestedAction: getSuggestedAction(for: error, context: context),
            userMessage: getUserMessage(for: error, context: context, severity: severity)
        )
        
        // Log the error
        logError(errorInfo)
        
        // Show user notification if needed
        if severity >= .error {
            showUserError(errorInfo)
        }
        
        // Handle fatal errors
        if severity == .fatal {
            handleFatalError(errorInfo)
        }
    }
    
    /// Show a user-friendly error message
    /// - Parameter errorInfo: The error information to display
    func showUserError(_ errorInfo: ErrorInfo) {
        // In a SwiftUI app, this would typically use a state management system
        // For now, we'll log the error message
        print("🚨 User Error (\(errorInfo.severity)): \(errorInfo.userMessage ?? errorInfo.error.localizedDescription)")
        
        if let suggestedAction = errorInfo.suggestedAction {
            print("💡 Suggested Action: \(suggestedAction)")
        }
        
        if errorInfo.canRetry {
            print("🔄 This operation can be retried")
        }
    }
    
    /// Log error information for debugging
    /// - Parameter errorInfo: The error information to log
    func logError(_ errorInfo: ErrorInfo) {
        // Add to error log
        errorLog.append(errorInfo)
        
        // Keep log size manageable
        if errorLog.count > maxLogSize {
            errorLog.removeFirst(errorLog.count - maxLogSize)
        }
        
        // Print to console for debugging
        print("📋 Error Log Entry:")
        print("  Severity: \(errorInfo.severity)")
        print("  Context: \(errorInfo.context)")
        print("  Error: \(errorInfo.error.localizedDescription)")
        print("  Timestamp: \(errorInfo.timestamp)")
        
        if let suggestedAction = errorInfo.suggestedAction {
            print("  Suggested Action: \(suggestedAction)")
        }
    }
    
    /// Retry a failed operation with exponential backoff
    /// - Parameters:
    ///   - operation: The operation to retry
    ///   - maxRetries: Maximum number of retry attempts
    ///   - baseDelay: Base delay between retries in milliseconds
    func retryOperation<T>(
        _ operation: @escaping () async throws -> T,
        maxRetries: Int = 3,
        baseDelay: UInt32 = 1000
    ) async -> Result<T, Error> {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                let result = try await operation()
                if attempt > 0 {
                    print("✅ Operation succeeded on attempt \(attempt + 1)")
                }
                return .success(result)
            } catch {
                lastError = error
                if attempt < maxRetries {
                    let delay = UInt64(baseDelay * UInt32(pow(2.0, Double(attempt))))
                    print("⚠️ Operation failed on attempt \(attempt + 1), retrying in \(delay)ms...")
                    try? await Task.sleep(nanoseconds: delay * 1_000_000)
                }
            }
        }
        
        if let error = lastError {
            print("❌ Operation failed after \(maxRetries + 1) attempts")
            return .failure(error)
        } else {
            fatalError("retryOperation: No error captured")
        }
    }
    
    /// Get recent errors from the log
    /// - Parameter severity: Filter by minimum severity level
    /// - Returns: Array of recent errors
    func getRecentErrors(minSeverity: ErrorSeverity = .error) -> [ErrorInfo] {
        return errorLog.filter { $0.severity >= minSeverity }
    }
    
    /// Clear the error log
    func clearErrorLog() {
        errorLog.removeAll()
        print("🗑️ Error log cleared")
    }
    
    // MARK: - Private Helper Methods
    
    /// Get a suggested action for the given error
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: The context where the error occurred
    /// - Returns: A suggested action string
    private func getSuggestedAction(for error: Error, context: String) -> String? {
        // Check for specific error types and provide tailored suggestions
        // Note: SessionDataManager.DataError doesn't exist, so we'll use generic file error handling
        if error.localizedDescription.contains("file") || error.localizedDescription.contains("File") {
            return "Check that the data file exists and is accessible"
        } else if error.localizedDescription.contains("format") || error.localizedDescription.contains("Format") {
            return "The data file may be corrupted. Try restoring from backup"
        } else if error.localizedDescription.contains("write") || error.localizedDescription.contains("Write") {
            return "Check file permissions and disk space"
        } else if error.localizedDescription.contains("read") || error.localizedDescription.contains("Read") {
            return "Check file permissions and try again"
        }
        
        // Generic suggestions based on context
        switch context {
        case "SessionDataManager":
            return "Try restarting the application or restoring from backup"
        case "ProjectManager":
            return "Check your project data and try again"
        case "ActivityTypeManager":
            return "Check your activity type data and try again"
        default:
            return "Contact support if this problem persists"
        }
    }
    
    /// Get a user-friendly error message
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: The context where the error occurred
    ///   - severity: The severity of the error
    /// - Returns: A user-friendly error message
    private func getUserMessage(for error: Error, context: String, severity: ErrorSeverity) -> String {
        let baseMessage: String
        
        switch severity {
        case .warning:
            baseMessage = "Warning: "
        case .error:
            baseMessage = "Error: "
        case .fatal:
            baseMessage = "Critical Error: "
        }
        
        // Check for specific error types
        // Note: SessionDataManager.DataError doesn't exist, so we'll use generic error detection
        if error.localizedDescription.contains("file") || error.localizedDescription.contains("File") {
            return baseMessage + "Could not find the required data file"
        } else if error.localizedDescription.contains("format") || error.localizedDescription.contains("Format") {
            return baseMessage + "The data file format is invalid or corrupted"
        } else if error.localizedDescription.contains("write") || error.localizedDescription.contains("Write") {
            return baseMessage + "Failed to save data. Check file permissions and disk space"
        } else if error.localizedDescription.contains("read") || error.localizedDescription.contains("Read") {
            return baseMessage + "Failed to read data. Check file permissions"
        }
        
        // Generic messages based on context
        switch context {
        case "SessionDataManager":
            return baseMessage + "Failed to manage session data"
        case "ProjectManager":
            return baseMessage + "Failed to manage project data"
        case "ActivityTypeManager":
            return baseMessage + "Failed to manage activity type data"
        case "DataValidator":
            return baseMessage + "Data validation failed"
        default:
            return baseMessage + "An unexpected error occurred"
        }
    }
    
    /// Handle fatal errors that require app shutdown
    /// - Parameter errorInfo: The fatal error information
    private func handleFatalError(_ errorInfo: ErrorInfo) {
        print("💀 Fatal error occurred. App cannot continue.")
        print("Error: \(errorInfo.error.localizedDescription)")
        print("Context: \(errorInfo.context)")
        
        // In a real app, you might want to:
        // 1. Save critical state
        // 2. Show a fatal error dialog to the user
        // 3. Log the error to a file for debugging
        // 4. Exit gracefully
        
        // For now, we'll just print the error
        // fatalError("Fatal error: \(errorInfo.error.localizedDescription)")
    }
    
    // MARK: - Debug Logging Methods
    
    /// Log debug information for complex operations
    /// **AI Context**: This method provides structured debug logging for complex operations
    /// to help AI assistants understand execution flow and identify potential issues
    /// - Parameters:
    ///   - operation: The operation being performed
    ///   - context: Additional context about the operation
    ///   - data: Optional data to log (will be converted to string)
    func logDebug(_ operation: String, context: String? = nil, data: Any? = nil) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let contextInfo = context.map { " (\($0))" } ?? ""
        let dataInfo = data.map { " | Data: \($0)" } ?? ""
        
        print("🔍 [\(timestamp)] DEBUG: \(operation)\(contextInfo)\(dataInfo)")
    }
    
    /// Log performance metrics for operations
    /// **AI Context**: This method logs timing information to help identify performance bottlenecks
    /// - Parameters:
    ///   - operation: The operation being timed
    ///   - duration: Duration in milliseconds
    ///   - context: Additional context about the operation
    func logPerformance(_ operation: String, duration: TimeInterval, context: String? = nil) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let contextInfo = context.map { " (\($0))" } ?? ""
        let performanceLevel: String
        
        if duration < 100 {
            performanceLevel = "✅ Fast"
        } else if duration < 1000 {
            performanceLevel = "⚠️ Moderate"
        } else {
            performanceLevel = "❌ Slow"
        }
        
        print("⏱️ [\(timestamp)] PERFORMANCE: \(operation)\(contextInfo) - \(duration)ms (\(performanceLevel))")
    }
    
    /// Log state changes for debugging
    /// **AI Context**: This method logs state transitions to help track application state
    /// - Parameters:
    ///   - state: The state being changed
    ///   - fromValue: Previous state value
    ///   - toValue: New state value
    ///   - context: Additional context about the state change
    func logStateChange(_ state: String, fromValue: Any?, toValue: Any?, context: String? = nil) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let contextInfo = context.map { " (\($0))" } ?? ""
        let fromInfo = fromValue.map { "from '\($0)'" } ?? "nil"
        let toInfo = toValue.map { "to '\($0)'" } ?? "nil"
        
        print("🔄 [\(timestamp)] STATE: \(state)\(contextInfo) - \(fromInfo) → \(toInfo)")
    }
    
    /// Log data validation results
    /// **AI Context**: This method logs validation results to help track data quality
    /// - Parameters:
    ///   - entity: The entity being validated
    ///   - isValid: Whether validation passed
    ///   - details: Additional validation details
    func logValidation(_ entity: String, isValid: Bool, details: String? = nil) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let status = isValid ? "✅ Valid" : "❌ Invalid"
        let detailsInfo = details.map { " | Details: \($0)" } ?? ""
        
        print("📋 [\(timestamp)] VALIDATION: \(entity) - \(status)\(detailsInfo)")
    }
    
    /// Log file operations with detailed information
    /// **AI Context**: This method provides detailed logging for file operations
    /// - Parameters:
    ///   - operation: The file operation (read, write, delete, etc.)
    ///   - filePath: The file path involved
    ///   - success: Whether the operation succeeded
    ///   - size: File size in bytes (optional)
    ///   - duration: Operation duration in milliseconds (optional)
    func logFileOperation(_ operation: String, filePath: String, success: Bool, size: Int? = nil, duration: TimeInterval? = nil) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let status = success ? "✅ Success" : "❌ Failed"
        let sizeInfo = size.map { " | Size: \($0) bytes" } ?? ""
        let durationInfo = duration.map { " | Duration: \($0)ms" } ?? ""
        
        print("📁 [\(timestamp)] FILE: \(operation) '\(filePath)' - \(status)\(sizeInfo)\(durationInfo)")
    }
    
    /// Log session lifecycle events
    /// **AI Context**: This method logs session state changes for debugging session management
    /// - Parameters:
    ///   - event: The session event (start, end, update, etc.)
    ///   - sessionID: The session identifier
    ///   - details: Additional session details
    func logSessionEvent(_ event: String, sessionID: String, details: String? = nil) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let detailsInfo = details.map { " | \($0)" } ?? ""
        
        print("⏱️ [\(timestamp)] SESSION: \(event) (ID: \(sessionID))\(detailsInfo)")
    }
    
    /// Log project management events
    /// **AI Context**: This method logs project state changes for debugging project management
    /// - Parameters:
    ///   - event: The project event (create, update, archive, etc.)
    ///   - projectID: The project identifier
    ///   - projectName: The project name
    ///   - details: Additional project details
    func logProjectEvent(_ event: String, projectID: String, projectName: String, details: String? = nil) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let detailsInfo = details.map { " | \($0)" } ?? ""
        
        print("📁 [\(timestamp)] PROJECT: \(event) '\(projectName)' (ID: \(projectID))\(detailsInfo)")
    }
    
    // MARK: - Enhanced Error Handling with JujuError
    
    /// Handle JujuError with enhanced context and logging
    /// **AI Context**: This method provides specialized handling for JujuError types
    /// with detailed logging and context preservation
    /// - Parameters:
    ///   - jujuError: The JujuError to handle
    ///   - context: Additional context about where the error occurred
    ///   - severity: Severity level of the error
    func handleJujuError(_ jujuError: JujuError, context: String, severity: ErrorSeverity = .error) {
        // Log detailed error information
        print("🚨 [\(Date())] JUJU ERROR DETECTED")
        print("Context: \(context)")
        print("Severity: \(severity)")
        print("Error Details:")
        print(jujuError.detailedErrorReport)
        
        // Handle with standard error handling
        handleError(jujuError, context: context, severity: severity)
    }
    
    /// Handle operation with automatic error conversion and logging
    /// **AI Context**: This method wraps operations and automatically converts errors
    /// to JujuError format with context preservation
    /// - Parameters:
    ///   - operation: The operation name
    ///   - context: The operation context
    ///   - entity: The entity being operated on
    ///   - operationBlock: The operation to perform
    func handleOperation<T>(
        _ operation: String,
        context: String,
        entity: String? = nil,
        _ operationBlock: () throws -> T
    ) throws -> T {
        let startTime = Date()
        
        logDebug("Starting \(operation)", context: context)
        
        do {
            let result = try operationBlock()
            let duration = Date().timeIntervalSince(startTime) * 1000
            logPerformance("\(operation) completed", duration: duration, context: context)
            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            
            // Convert to JujuError if needed
            let jujuError: JujuError
            if let existingJujuError = error as? JujuError {
                jujuError = existingJujuError
            } else {
                // Create a generic JujuError from the caught error
                jujuError = .dataError(
                    operation: operation,
                    entity: entity ?? "unknown",
                    reason: error.localizedDescription,
                    context: context
                )
            }
            
            logPerformance("\(operation) failed", duration: duration, context: context)
            handleJujuError(jujuError, context: context, severity: .error)
            throw jujuError
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Handle file I/O errors with appropriate messaging
    /// - Parameters:
    ///   - error: The file I/O error
    ///   - operation: The operation that failed (read, write, etc.)
    ///   - filePath: The file path involved
    func handleFileError(_ error: Error, operation: String, filePath: String) {
        let context = "File I/O (\(operation))"
        let severity: ErrorSeverity = error.localizedDescription.contains("write") ? .error : .warning
        
        handleError(error, context: context, severity: severity)
    }
    
    /// Handle data validation errors
    /// - Parameters:
    ///   - error: The validation error
    ///   - dataType: The type of data being validated
    func handleValidationError(_ error: Error, dataType: String) {
        handleError(error, context: "DataValidator (\(dataType))", severity: .error)
    }
    
    /// Handle migration errors
    /// - Parameters:
    ///   - error: The migration error
    ///   - migrationType: The type of migration
    func handleMigrationError(_ error: Error, migrationType: String) {
        handleError(error, context: "DataMigration (\(migrationType))", severity: .error)
    }
    
    /// Handle user action errors (e.g., invalid input)
    /// - Parameters:
    ///   - error: The user action error
    ///   - action: The user action that failed
    func handleUserActionError(_ error: Error, action: String) {
        handleError(error, context: "UserAction (\(action))", severity: .warning)
    }
}
