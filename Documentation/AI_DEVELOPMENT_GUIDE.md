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

### 1. Follow MVVM

Create ViewModel, avoid logic in Views.

```swift
class NewFeatureViewModel: ObservableObject {
    @Published var data: [DataType] = []   
    func loadData() async { /* Business logic */ }
}
```

### 2. Use Managers

- Session data: SessionManager
- Project data: ProjectManager
- Validation: DataValidator
- Notifications: NSNotificationCenter

### 3. Data Consistency

- Use projectID (projectName is legacy)
- Validate with DataValidator
- Handle notifications
- Follow existing patterns

---

## 🛠️ Modifying Data Models

### 1. Update Docs

- ARCHITECTURE.md: new data types
- DATA_FLOW.yaml: new data_packet types
- Maintain backward compatibility

### 2. Add Validation

```swift
func validateNewModel(_ model: NewModel) -> ValidationResult { /* Validation logic */ }
```

### 3. Handle Migration

- Support legacy data
- Use existing migration patterns
- Test with new/legacy data

---

## 📊 Working with Sessions

### 1. Use SessionManager

```swift
SessionManager.shared.startSession(for: "Project Name", projectID: "project-id")
SessionManager.shared.endSession(notes: "Session notes", mood: 8)
```

### 2. Handle Project IDs

```swift
SessionManager.shared.startSession(for: "Project Name", projectID: "project-uuid")
// Legacy support: SessionManager.shared.startSession(for: "Legacy Project Name")
```

### 3. Post Notifications

```swift
NotificationCenter.default.post(name: .sessionDidEnd, object: nil)
```

### 🗑️ Deleting Sessions
```swift
// Safe deletion - only removes specified session, preserves others
SessionManager.shared.deleteSession(id: "session-id-to-delete")

---

## 🎨 Modifying UI

### 1. Follow Theme

```swift
.padding(.horizontal, Theme.spacingMedium)
.background(Theme.Colors.surface)
.font(Theme.Fonts.body)
.dashboardPadding()
.chartPadding()
.loadingOverlay(isLoading: isLoading)
```

### 2. State Management

```swift
@StateObject private var viewModel = NewFeatureViewModel()
@State private var isEditing = false
```

### 3. Accessibility

- Implement labels
- Test light/dark mode
- Use consistent spacing/typography

---

## 🔄 Adding Logic

### 1. Place in Managers

```swift
class SessionManager {
    func calculateSessionMetrics() -> SessionMetrics { /* Business logic */ }
}
```

### 2. Use @MainActor

```swift
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var sessions: [SessionRecord] = []   
    func updateSessions() { sessions = SessionManager.shared.allSessions }
}
```

### 3. Implement Validation

```swift
guard DataValidator.shared.validateSession(session).isValid else { return false }
do { let result = try someOperation() } catch { ErrorHandler.shared.handleError(error, context: "ClassName.methodName") }
```

---

## 🚨 Error Handling

### 1. Use JujuError

```swift
enum JujuError: Error {
    case invalidSessionData(String)
    case fileOperationFailed(String)
    case dataMigrationFailed(String)
}
throw JujuError.invalidSessionData("Session \(id) has invalid start time")
```

### 2. Use ErrorHandler

```swift
ErrorHandler.shared.handleError(error, context: "SessionManager.startSession", severity: .error)
ErrorHandler.shared.logDebug("Starting operation", context: "ClassName.methodName")
ErrorHandler.shared.logPerformance("operation completed", duration: 150.0, context: "ClassName.methodName")
```

### 3. Provide Suggestions

```swift
case .fileError(let operation, let filePath, let reason, _):
    return "Check file permissions for '\(filePath)' and try again."
```

---

## ⚡ Performance

### 1. Data Loading

```swift
let query = SessionQuery(startDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()), endDate: Date(), limit: 1000)
let sessions = try await SessionManager.shared.loadSessions(query: query)
let cachedResult = ProjectStatisticsCache.shared.getStatistics(for: projectID)
```

### 2. UI Performance

```swift
@StateObject private var viewModel = ExpensiveViewModel()
.onAppear { Task { await viewModel.loadData() } }
```

### 3. Background

```swift
func loadDataInBackground() async {
    await Task.detached {
        let data = try await SessionManager.shared.loadAllSessions()
        await MainActor.run { /* Update UI */ }
    }
}
```

---

## 🧪 Testing

### 1. Unit Tests

```swift
class SessionManagerTests: XCTestCase {
    var sessionManager: SessionManager!
    var mockFileManager: MockSessionFileManager!
    override func setUp() { super.setUp(); mockFileManager = MockSessionFileManager(); sessionManager = SessionManager(fileManager: mockFileManager) }
    func testStartSession_ValidProject_CreatesSession() async throws {
        let projectID = "test-project"; mockFileManager.mockProjects = [Project(id: projectID, name: "Test Project")]
        let result = try await sessionManager.startSession(projectID: projectID)
        XCTAssertTrue(result); XCTAssertEqual(mockFileManager.savedSessions.count, 1); XCTAssertEqual(mockFileManager.savedSessions.first?.projectID, projectID)
    }
}
```

### 2. Mock Objects

```swift
class MockSessionFileManager: SessionFileManagerProtocol {
    var mockSessions: [SessionRecord] = []
    var savedSessions: [SessionRecord] = []
    var deletedSessionIDs: [String] = []
    func loadSessions() throws -> [SessionRecord] { return mockSessions }
    func saveSession(_ session: SessionRecord) throws { savedSessions.append(session) }
    func deleteSession(_ sessionID: String) throws { deletedSessionIDs.append(sessionID) }
}
```

### 3. Integration Tests

- Test UI to persistence
- Verify notifications
- Test new/legacy data
- Validate dashboard data

---

## 🎯 AI Tasks

### Add Feature

1. Analyze architecture
2. Design data models
3. Implement manager methods
4. Create view models
5. Build UI
6. Document
7. Update architecture
8. Test

### Fix Bug

1. Reproduce
2. Identify root cause
3. Check error handling
4. Implement fix
5. Add/update tests
6. Verify

### Optimize

1. Profile
2. Use SessionQuery
3. Implement caching
4. Use @MainActor
5. Batch operations
6. Lazy load

---

## 🚨 Avoid

1. Direct File Access
2. Logic in Views
3. Missing Notifications
4. Inconsistent Errors
5. Hardcoded Values
6. Blocking UI
7. Ignoring Legacy Data

---

## 📚 Resources

- ARCHITECTURE.md: System overview
- DATA_FLOW.yaml: Component relationships
- Features/: UI patterns
- ErrorHandler.shared: Error patterns
- CODE_CONVENTIONS.md: Coding standards

---

## 🔄 Workflow

### New Feature

1. Analyze architecture
2. Design data models
3. Implement manager methods
4. Create view models
5. Build UI
6. Document
7. Update architecture
8. Test

### Bug Fix

1. Reproduce
2. Identify root cause
3. Check error handling
4. Implement fix
5. Add/update tests
6. Verify

### Performance

1. Profile
2. Use SessionQuery
3. Implement caching
4. Optimize UI
5. Use background operations
6. Test

This guide helps AI assistants work with Juju while maintaining code quality.
</final_file_content>

IMPORTANT: For any future changes to this file, use the final_file_content shown above as your reference. This content reflects the current state of the file, including any auto-formatting (e.g., if you used single quotes but the formatter converted them to double quotes). Always base your SEARCH/REPLACE operations on this final version to ensure accuracy.<environment_details>
# Visual Studio Code Visible Files
Juju/Core/Models/JujuError.swift

# Visual Studio Code Open Tabs
Documentation/DATA_FLOW.yaml
Refactor Plans/AI_Friendly_Codebase_Improvement_Plan.md
Juju/Core/Models/JujuError.swift
Juju/Features/Sessions/SessionsView.swift

# Current Time
13/01/2026, 9:03:29 pm (Asia/Bangkok, UTC+7:00)

# Context Window Usage
110,087 / 1,048.576K tokens used (10%)

# Current Mode
ACT MODE