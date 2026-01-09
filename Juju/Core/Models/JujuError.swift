import Foundation

// MARK: - Centralized Error Handling
/// Enhanced error types with context-rich messages for AI-friendly error handling
///
/// **AI Context**: This enum provides specific error types with detailed context
/// to help AI assistants understand what went wrong and how to fix it. Each error
/// includes specific field information, operation context, and actionable recovery steps.
///
/// **Error Categories**:
/// - Validation: Input validation failures with field-specific details
/// - Data: Data integrity and parsing issues with specific reasons
/// - File: File system operations with path and operation context
/// - Session: Session management with operation and state context
/// - Project: Project management with entity and operation context
/// - Migration: Data migration with version and compatibility context
/// - Network: Network operations (for future cloud features)
///
/// **Usage Pattern**:
/// ```swift
/// // BEFORE: Generic error
/// return .invalid(reason: "Invalid data")
///
/// // AFTER: Context-rich error
/// case .dataError(operation: "parse", entity: "session", reason: "missing required field 'id'")
/// ```
enum JujuError: Error, LocalizedError {
    /// Input validation failed with specific field and reason
    /// - Parameters:
    ///   - field: The field that failed validation
    ///   - reason: Specific reason for validation failure
    ///   - value: The invalid value (optional, for debugging)
    case validationError(field: String, reason: String, value: String? = nil)
    
    /// Data operation failed with specific context
    /// - Parameters:
    ///   - operation: The operation that failed (parse, migrate, validate, etc.)
    ///   - entity: The data entity involved (session, project, activity, etc.)
    ///   - reason: Specific reason for the failure
    ///   - context: Additional context about where the error occurred
    case dataError(operation: String, entity: String, reason: String, context: String? = nil)
    
    /// File system operation failed with path and operation context
    /// - Parameters:
    ///   - operation: The file operation that failed (read, write, delete, etc.)
    ///   - filePath: The file path involved
    ///   - reason: Specific reason for the failure
    ///   - permissions: Current file permissions (optional)
    case fileError(operation: String, filePath: String, reason: String, permissions: String? = nil)
    
    /// Session management operation failed with state context
    /// - Parameters:
    ///   - operation: The session operation that failed (start, end, update, etc.)
    ///   - sessionID: The session identifier (if available)
    ///   - reason: Specific reason for the failure
    ///   - state: Current session state (optional)
    case sessionError(operation: String, sessionID: String? = nil, reason: String, state: String? = nil)
    
    /// Project management operation failed with entity context
    /// - Parameters:
    ///   - operation: The project operation that failed (create, update, archive, etc.)
    ///   - projectID: The project identifier (if available)
    ///   - reason: Specific reason for the failure
    ///   - entity: The related entity (phase, milestone, etc.)
    case projectError(operation: String, projectID: String? = nil, reason: String, entity: String? = nil)
    
    /// Data migration failed with version context
    /// - Parameters:
    ///   - fromVersion: Source data version
    ///   - toVersion: Target data version
    ///   - reason: Specific reason for migration failure
    ///   - affectedRecords: Number of records affected
    case migrationError(fromVersion: String, toVersion: String, reason: String, affectedRecords: Int = 0)
    
    /// Network operation failed (for future cloud features)
    /// - Parameters:
    ///   - operation: The network operation that failed
    ///   - url: The URL involved
    ///   - statusCode: HTTP status code (if available)
    ///   - reason: Specific reason for the failure
    case networkError(operation: String, url: String, statusCode: Int? = nil, reason: String)
    
    var errorDescription: String? {
        switch self {
        case .validationError(let field, let reason, let value):
            let valueInfo = value.map { " (value: '\($0)')" } ?? ""
            return "Invalid \(field): \(reason)\(valueInfo)"
            
        case .dataError(let operation, let entity, let reason, let context):
            let contextInfo = context.map { " in \($0)" } ?? ""
            return "Data \(operation) failed for \(entity)\(contextInfo): \(reason)"
            
        case .fileError(let operation, let filePath, let reason, let permissions):
            let permissionInfo = permissions.map { " (permissions: \($0))" } ?? ""
            return "File \(operation) failed for '\(filePath)'\(permissionInfo): \(reason)"
            
        case .sessionError(let operation, let sessionID, let reason, let state):
            let sessionInfo = sessionID.map { " (session: \($0))" } ?? ""
            let stateInfo = state.map { " (state: \($0))" } ?? ""
            return "Session \(operation) failed\(sessionInfo)\(stateInfo): \(reason)"
            
        case .projectError(let operation, let projectID, let reason, let entity):
            let projectInfo = projectID.map { " (project: \($0))" } ?? ""
            let entityInfo = entity.map { " (\($0))" } ?? ""
            return "Project \(operation) failed\(projectInfo)\(entityInfo): \(reason)"
            
        case .migrationError(let fromVersion, let toVersion, let reason, let affectedRecords):
            let recordInfo = affectedRecords > 0 ? " (\(affectedRecords) records affected)" : ""
            return "Migration from \(fromVersion) to \(toVersion) failed\(recordInfo): \(reason)"
            
        case .networkError(let operation, let url, let statusCode, let reason):
            let statusInfo = statusCode.map { " (status: \($0))" } ?? ""
            return "Network \(operation) failed for '\(url)'\(statusInfo): \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .validationError(let field, _, _):
            return "Check the \(field) field format and try again. Ensure it meets the required criteria."
            
        case .dataError(let operation, let entity, _, _):
            switch operation {
            case "parse":
                return "The \(entity) data may be corrupted. Try restarting the app or restoring from backup."
            case "migrate":
                return "Data migration failed. Contact support for assistance with data recovery."
            case "validate":
                return "Check the \(entity) data format and ensure all required fields are present."
            default:
                return "The \(entity) data may have integrity issues. Try restarting the app."
            }
            
        case .fileError(let operation, let filePath, _, _):
            switch operation {
            case "read":
                return "Check that the file '\(filePath)' exists and has read permissions."
            case "write":
                return "Check file permissions for '\(filePath)' and ensure there's enough disk space."
            case "delete":
                return "Check file permissions for '\(filePath)' and ensure the file is not in use."
            default:
                return "Check file permissions for '\(filePath)' and try again."
            }
            
        case .sessionError(let operation, _, _, _):
            switch operation {
            case "start":
                return "Ensure no other session is active, then try starting the session again."
            case "end":
                return "Try ending the session again, or restart the app if the issue persists."
            case "update":
                return "Check the session data and try the update operation again."
            default:
                return "Try the session operation again, or restart the app if the issue persists."
            }
            
        case .projectError(let operation, _, _, _):
            switch operation {
            case "create":
                return "Check project name uniqueness and try creating the project again."
            case "update":
                return "Check project data and try the update operation again."
            case "archive":
                return "Ensure the project exists and try archiving again."
            default:
                return "Check project settings and try the operation again."
            }
            
        case .migrationError:
            return "Data migration failed. Contact support for assistance with data recovery."
            
        case .networkError:
            return "Check your internet connection and try the operation again."
        }
    }
    
    /// Get a detailed error report for debugging
    /// **AI Context**: This method provides comprehensive error information
    /// for debugging and logging purposes, including all context details
    var detailedErrorReport: String {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium)
        
        return """
        =¨ Juju Error Report
        Time: \(timestamp)
        Error: \(errorDescription ?? "Unknown error")
        Suggestion: \(recoverySuggestion ?? "No suggestion available")
        
        Error Details:
        \(errorDetails)
        
        Next Steps:
        1. \(recoverySuggestion ?? "Check the error message above")
        2. If the problem persists, restart the application
        3. Contact support with this error report if needed
        """
    }
    
    /// Get specific error details for logging
    private var errorDetails: String {
        switch self {
        case .validationError(let field, let reason, let value):
            return """
            Type: Validation Error
            Field: \(field)
            Reason: \(reason)
            Value: \(value ?? "N/A")
            """
            
        case .dataError(let operation, let entity, let reason, let context):
            return """
            Type: Data Error
            Operation: \(operation)
            Entity: \(entity)
            Reason: \(reason)
            Context: \(context ?? "N/A")
            """
            
        case .fileError(let operation, let filePath, let reason, let permissions):
            return """
            Type: File Error
            Operation: \(operation)
            File: \(filePath)
            Reason: \(reason)
            Permissions: \(permissions ?? "N/A")
            """
            
        case .sessionError(let operation, let sessionID, let reason, let state):
            return """
            Type: Session Error
            Operation: \(operation)
            Session ID: \(sessionID ?? "N/A")
            Reason: \(reason)
            State: \(state ?? "N/A")
            """
            
        case .projectError(let operation, let projectID, let reason, let entity):
            return """
            Type: Project Error
            Operation: \(operation)
            Project ID: \(projectID ?? "N/A")
            Reason: \(reason)
            Entity: \(entity ?? "N/A")
            """
            
        case .migrationError(let fromVersion, let toVersion, let reason, let affectedRecords):
            return """
            Type: Migration Error
            From Version: \(fromVersion)
            To Version: \(toVersion)
            Reason: \(reason)
            Affected Records: \(affectedRecords)
            """
            
        case .networkError(let operation, let url, let statusCode, let reason):
            return """
            Type: Network Error
            Operation: \(operation)
            URL: \(url)
            Status Code: \(statusCode.map { String($0) } ?? "N/A")
            Reason: \(reason)
            """
        }
    }
}

// MARK: - Error Recovery Strategies
struct ErrorRecovery {
    static func handle(error: Error) -> String {
        let errorMessage: String
        
        if let jujuError = error as? JujuError {
            errorMessage = jujuError.errorDescription ?? "An error occurred"
        } else {
            errorMessage = error.localizedDescription
        }
        
        // Log error for debugging
        print("Juju Error: \(errorMessage)")
        
        return errorMessage
    }
    
    static func showErrorAlert(error: Error, completion: @escaping (Bool) -> Void) {
        let errorMessage = handle(error: error)
        let recoverySuggestion = (error as? JujuError)?.recoverySuggestion ?? "Please try again"
        
        // This would integrate with your UI framework for showing alerts
        print("Show alert: \(errorMessage)\nSuggestion: \(recoverySuggestion)")
        
        completion(true) // For now, just complete successfully
    }
}