# AI Development Guide for Juju

## 🤖 Quick Start

**Architecture**: MVVM + Managers + SwiftUI
**Data Flow**: UI → ViewModels → Managers → File I/O
**Storage**: Local CSV/JSON files
**Threading**: @MainActor for UI, async/await for background

**Key Files**:
- SessionManager: Session operations
- ProjectManager: Project lifecycle
- ChartDataPreparer: Dashboard data
- Theme.swift: UI utilities

**Navigation**:
- [Common AI Tasks](#common-ai-tasks)
- [Error Handling](#error-handling-patterns)
- [Performance](#performance-best-practices)
- [Testing](#testing-guidelines)

---

## 🎯 When Adding New Features

### 1. Follow MVVM Pattern
```swift
// ✅ DO: Create ViewModel for new feature
class NewFeatureViewModel: ObservableObject {
    @Published var data: [DataType] = []
    
    func loadData() async {
        // Business logic coordination
    }
}

// ❌ DON'T: Put business logic in views
struct NewFeatureView: View {
    // Only presentation logic here
}
```

### 2. Use Existing Managers
- **Session data**: Always use SessionManager, never access CSV files directly
- **Project data**: Always use ProjectManager, never access JSON files directly
- **Validation**: Use DataValidator for all data integrity checks
- **Notifications**: Post appropriate NSNotificationCenter events

### 3. Maintain Data Consistency
- **Always use projectID** for new sessions (projectName is legacy)
- **Validate before storage** with DataValidator
- **Handle notifications** for UI updates
- **Follow existing patterns** for error handling

---

## 🛠️ When Modifying Data Models

### 1. Update Documentation
- Update ARCHITECTURE.md with new data types
- Update DATA_FLOW.yaml for new data_packet types
- Maintain backward compatibility with existing data formats

### 2. Add Validation
```swift
// Add validation rules to DataValidator
func validateNewModel(_ model: NewModel) -> ValidationResult {
    // Validation logic
}
```

### 3. Handle Migration
- Support legacy data formats during transition
- Use automatic migration patterns from existing code
- Test with both new and legacy data

---

## 📊 When Working with Sessions

### 1. Use SessionManager
```swift
// ✅ DO: Use SessionManager for all session operations
SessionManager.shared.startSession(for: "Project Name", projectID: "project-id")
SessionManager.shared.endSession(notes: "Session notes", mood: 8)

// ❌ DON'T: Access CSV files directly
```

### 2. Handle Project IDs
```swift
// ✅ DO: Always use projectID for new sessions
SessionManager.shared.startSession(for: "Project Name", projectID: "project-uuid")

// Legacy support (project name only)
SessionManager.shared.startSession(for: "Legacy Project Name")
```

### 3. Post Notifications
```swift
// Always post notifications for data changes
NotificationCenter.default.post(name: .sessionDidEnd, object: nil)
```

---

## 🎨 When Modifying UI Components

### 1. Follow Theme Guidelines
```swift
// ✅ DO: Use Theme constants
.padding(.horizontal, Theme.spacingMedium)
.background(Theme.Colors.surface)
.font(Theme.Fonts.body)

// ✅ DO: Use consolidated extensions from Theme.swift
.dashboardPadding()
.chartPadding()
.loadingOverlay(isLoading: isLoading)
```

### 2. State Management
```swift
// ✅ DO: Use @StateObject for expensive view model initialization
@StateObject private var viewModel = NewFeatureViewModel()

// ✅ DO: Use @State for simple UI state
@State private var isEditing = false
```

### 3. Accessibility
- Implement proper accessibility labels
- Test with both light and dark mode themes
- Use consistent spacing and typography

---

## 🔄 When Adding Business Logic

### 1. Place Logic in Managers
```swift
// ✅ DO: Place business logic in appropriate Manager
class SessionManager {
    func calculateSessionMetrics() -> SessionMetrics {
        // Business logic here
    }
}

// ❌ DON'T: Put business logic in Views or ViewModels
```

### 2. Use @MainActor for UI Operations
```swift
// ✅ DO: Use @MainActor for UI-bound operations
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var sessions: [SessionRecord] = []
    
    func updateSessions() {
        // This runs on main thread automatically
        sessions = SessionManager.shared.allSessions
    }
}
```

### 3. Implement Proper Validation
```swift
// ✅ DO: Validate before operations
guard DataValidator.shared.validateSession(session).isValid else {
    return false
}

// ✅ DO: Handle errors explicitly
do {
    let result = try someOperation()
} catch {
    ErrorHandler.shared.handleError(error, context: "ClassName.methodName")
}
```

---

## 🚨 Error Handling Patterns

### 1. Use JujuError Enum
```swift
// ✅ DO: Use specific JujuError types
enum JujuError: Error {
    case invalidSessionData(String)
    case fileOperationFailed(String)
    case dataMigrationFailed(String)
}

// When throwing errors, provide context
throw JujuError.invalidSessionData("Session \(id) has invalid start time")
```

### 2. Handle Errors with ErrorHandler
```swift
// ✅ DO: Use ErrorHandler for consistent error handling
ErrorHandler.shared.handleError(error, context: "SessionManager.startSession", severity: .error)

// ✅ DO: Log debug information
ErrorHandler.shared.logDebug("Starting operation", context: "ClassName.methodName")
ErrorHandler.shared.logPerformance("operation completed", duration: 150.0, context: "ClassName.methodName")
```

### 3. Provide Recovery Suggestions
```swift
// ✅ DO: Always include actionable error messages
case .fileError(let operation, let filePath, let reason, _):
    return "Check file permissions for '\(filePath)' and try again."
```

---

## ⚡ Performance Best Practices

### 1. Data Loading
```swift
// ✅ DO: Use query-based loading for large datasets
let query = SessionQuery(
    startDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
    endDate: Date(),
    limit: 1000
)
let sessions = try await SessionManager.shared.loadSessions(query: query)

// ✅ DO: Implement caching for expensive calculations
let cachedResult = ProjectStatisticsCache.shared.getStatistics(for: projectID)
```

### 2. UI Performance
```swift
// ✅ DO: Use @StateObject for expensive view model initialization
@StateObject private var viewModel = ExpensiveViewModel()

// ✅ DO: Implement proper view lifecycle management
.onAppear {
    Task {
        await viewModel.loadData()
    }
}
```

### 3. Background Operations
```swift
// ✅ DO: Use async/await for file operations
func loadDataInBackground() async {
    await Task.detached {
        let data = try await SessionManager.shared.loadAllSessions()
        await MainActor.run {
            // Update UI with loaded data
        }
    }
}
```

---

## 🧪 Testing Guidelines

### 1. Unit Tests
```swift
class SessionManagerTests: XCTestCase {
    var sessionManager: SessionManager!
    var mockFileManager: MockSessionFileManager!
    
    override func setUp() {
        super.setUp()
        mockFileManager = MockSessionFileManager()
        sessionManager = SessionManager(fileManager: mockFileManager)
    }
    
    func testStartSession_ValidProject_CreatesSession() async throws {
        // Given
        let projectID = "test-project"
        mockFileManager.mockProjects = [Project(id: projectID, name: "Test Project")]
        
        // When
        let result = try await sessionManager.startSession(projectID: projectID)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.savedSessions.count, 1)
        XCTAssertEqual(mockFileManager.savedSessions.first?.projectID, projectID)
    }
}
```

### 2. Mock Objects
```swift
class MockSessionFileManager: SessionFileManagerProtocol {
    var mockSessions: [SessionRecord] = []
    var savedSessions: [SessionRecord] = []
    var deletedSessionIDs: [String] = []
    
    func loadSessions() throws -> [SessionRecord] {
        return mockSessions
    }
    
    func saveSession(_ session: SessionRecord) throws {
        savedSessions.append(session)
    }
    
    func deleteSession(_ sessionID: String) throws {
        deletedSessionIDs.append(sessionID)
    }
}
```

### 3. Integration Tests
- Test complete workflows from UI to persistence
- Verify notification patterns work correctly
- Test with both new and legacy data formats
- Validate dashboard data aggregation accuracy

---

## 🎯 Common AI Tasks

### Adding a New Feature
1. **Analyze existing architecture** and identify appropriate manager
2. **Design data models** following existing patterns
3. **Implement manager methods** with proper validation
4. **Create view models** for UI state management
5. **Build UI components** following Theme.swift
6. **Add comprehensive documentation**
7. **Update architecture documentation files**
8. **Test with both new and existing data**

### Fixing Bugs
1. **Reproduce the issue** with specific steps
2. **Identify the root cause** in the appropriate layer
3. **Check existing error handling patterns**
4. **Implement fix** following existing patterns
5. **Add or update tests** to prevent regression
6. **Verify fix works** with both new and legacy data

### Performance Optimization
1. **Use SessionQuery** for filtered data loading
2. **Implement caching** for expensive calculations
3. **Use @MainActor** for UI updates only
4. **Batch file operations** when possible
5. **Implement lazy loading** for large datasets

---

## 🚨 Common Pitfalls to Avoid

1. **Direct File Access**: Never access CSV/JSON files directly - always use managers
2. **Business Logic in Views**: Keep views focused on presentation only
3. **Missing Notifications**: Always post notifications for data changes
4. **Inconsistent Error Handling**: Use consistent error patterns throughout
5. **Hardcoded Values**: Use Theme.swift for colors, spacing, and constants
6. **Blocking UI Operations**: Use async/await for file operations
7. **Ignoring Legacy Data**: Always support backward compatibility

---

## 📚 Resources

- **Architecture**: See ARCHITECTURE.md for complete system overview and data models
- **Data Flow**: See DATA_FLOW.yaml for component relationships
- **UI Patterns**: Follow examples in Features/ directories
- **Error Handling**: Use ErrorHandler.shared for consistent patterns
- **Code Conventions**: See CODE_CONVENTIONS.md for essential coding standards

---

## 🔄 Development Workflow

### For New Features:
1. Analyze existing architecture and identify appropriate manager
2. Design data models following existing patterns
3. Implement manager methods with proper validation
4. Create view models for UI state management
5. Build UI components following Theme.swift
6. Add comprehensive documentation
7. Update architecture documentation files
8. Test with both new and existing data

### For Bug Fixes:
1. Reproduce the issue with specific steps
2. Identify the root cause in the appropriate layer
3. Check existing error handling patterns
4. Implement fix following existing patterns
5. Add or update tests to prevent regression
6. Verify fix works with both new and legacy data

### For Performance Issues:
1. Profile the application to identify bottlenecks
2. Use query-based loading for large datasets
3. Implement caching for expensive calculations
4. Optimize UI rendering with proper state management
5. Use background operations for file I/O
6. Test performance improvements with realistic data

This guide provides essential information for AI assistants working with the Juju codebase while maintaining code quality and architectural consistency.