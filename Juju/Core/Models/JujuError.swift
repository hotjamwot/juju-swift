import Foundation

// MARK: - Centralized Error Handling
enum JujuError: Error, LocalizedError {
    case validationError(field: String, reason: String)
    case dataError(reason: String)
    case fileError(reason: String)
    case sessionError(reason: String)
    case projectError(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .validationError(let field, let reason):
            return "Invalid \(field): \(reason)"
        case .dataError(let reason):
            return "Data error: \(reason)"
        case .fileError(let reason):
            return "File error: \(reason)"
        case .sessionError(let reason):
            return "Session error: \(reason)"
        case .projectError(let reason):
            return "Project error: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .validationError:
            return "Please check the input and try again"
        case .dataError:
            return "The data may be corrupted. Try restarting the app or contact support"
        case .fileError:
            return "Check file permissions and disk space"
        case .sessionError:
            return "Try restarting the session or contact support"
        case .projectError:
            return "Check project settings and try again"
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