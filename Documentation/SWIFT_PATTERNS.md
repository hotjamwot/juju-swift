# Juju Swift Development Patterns

**Purpose**: Single reference for code patterns, naming, threading, and workflows. Optimized for AI tools.

**[AI_QUICK_START]**
- **Architecture**: MVVM + Managers + SwiftUI
- **Threading**: @MainActor for UI, async/await for background
- **Data**: Use SessionManager.allSessions as source of truth
- **Key Rule**: Always use projectID, never projectName

---

## 📋 NAMING CONVENTIONS

| Category | Pattern | Example |
|----------|---------|---------|
| **Classes/Structs** | PascalCase | `SessionManager`, `ProjectStatisticsCache` |
| **Methods** | camelCase verb-noun | `loadSessions()`, `isSessionActive` |
| **Variables** | camelCase descriptive | `sessionStartTime`, `currentProjectID` |
| **IDs** | Always `*ID` | `projectID` (never projectName) |
| **Constants** | Grouped in structs | `Theme.Colors.primary`, `Theme.Spacing.medium` |
| **Booleans** | `is*` prefix | `isLoading`, `hasError`, `isSessionActive` |

---

## 🧵 THREADING RULES

**[AI_MARKER_CRITICAL]** Violating threading rules causes crashes. NO EXCEPTIONS.

### @MainActor (UI Classes)
```swift
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var sessions: [SessionRecord] = []
    // Automatically runs on main thread
}
```

### Background Tasks
```swift
Task {
    let data = try await expensiveOperation()
    await MainActor.run {
        self.uiProperty = data  // Update on main thread only
    }
}
```

---

## 📁 FILE STRUCTURE & HEADERS

Add this header to ALL new files:
```swift
/// [FileName].swift
/// Purpose: [Brief summary]
/// AI Notes: [Key architectural decision or important pattern]
```

### Directory Organization
```
Core/Managers/           ← SessionManager, ProjectManager, ChartDataPreparer
Core/Models/             ← SessionRecord, Project, Phase
Core/ViewModels/         ← Complex UI state management
Features/[FeatureName]/  ← Feature-specific views
Shared/                  ← Reusable components, Theme, Extensions
```

---

## 📝 DOCUMENTATION (REQUIRED)

**[AI_MARKER_IMPORTANT]** Every public method + complex private methods need doc comments.

### Minimum Standard
```swift
/// One-line purpose
/// - Parameters: description
/// - Returns: what type and why
func methodName() -> ReturnType
```

### For Complex Methods (Add These Sections)
```swift
/// **Purpose**: What and why
/// **AI Context**: Design patterns, coordination role
/// **Business Rules**: Invariants, preconditions
/// **State Changes**: What gets modified
/// **Error Cases**: What can fail
/// **Thread Safety**: @MainActor? async/await?
/// **Notifications**: What UI updates triggered
```

---

## 🚨 ERROR HANDLING

**[AI_MARKER_CRITICAL]** Never use `try?` or `try!`. Always catch and report.

```swift
do {
    let result = try operation()
} catch {
    ErrorHandler.shared.handleError(error, context: "ClassName.methodName", severity: .error)
    return // Fail gracefully
}
```

### Use JujuError for Domain Errors
```swift
throw JujuError.invalidSessionData("Session \(id) missing projectID")
```

---

## 🎯 STATE MANAGEMENT

**[AI_MARKER_IMPORTANT]** Views = pure presentation. All logic goes in ViewModels or Managers.

### View (Dumb)
```swift
struct SessionsView: View {
    @StateObject private var viewModel = SessionsViewModel()
    
    var body: some View {
        List(viewModel.sessions) { session in
            SessionsRowView(session: session)
        }
    }
}
```

### ViewModel (Smart)
```swift
@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [SessionRecord] = []
    
    func load() async {
        sessions = SessionManager.shared.allSessions
    }
}
```

---

## ⚡ PERFORMANCE RULES

| Operation | DO ✅ | DON'T ❌ |
|-----------|---------|-----------|
| **Load Sessions** | Use `SessionManager.allSessions` (cached) | Don't reload from disk every time |
| **Calculate Stats** | Use `ProjectStatisticsCache` (30s TTL) | Don't recalculate per view update |
| **File I/O** | Background via `Task` or `async/await` | Don't block main thread |
| **List Rendering** | Lazy load via `List` + `ForEach` | Don't render all at once |

---

## 🧪 TESTING PATTERN

### Mock Objects
```swift
class MockSessionFileManager: SessionFileManagerProtocol {
    var savedSessions: [SessionRecord] = []
    func saveSession(_ session: SessionRecord) { savedSessions.append(session) }
}
```

### Test Cases
```swift
func testStartSession_ValidProject_CreatesSession() async throws {
    // Given
    let projectID = "test-project"
    
    // When
    let result = try await sessionManager.startSession(projectID: projectID)
    
    // Then
    XCTAssertTrue(result)
}
```

---

## ❌ ANTIPATTERNS (AVOID)

1. **Direct file access** → Use SessionFileManager
2. **Logic in Views** → Move to ViewModel
3. **Missing error handling** → Always catch
4. **projectName instead of projectID** → Use ID only
5. **Blocking main thread** → Use async/await
6. **Race conditions** → Use @MainActor or locks
7. **Ignoring notifications** → Subscribe to invalidation events
8. **Force unwrap** → Use guard let or ?? instead

---

## 🔑 KEY MANAGERS

| Manager | Responsibility | When to Use |
|---------|-----------------|-------------|
| **SessionManager** | Session lifecycle, CSV I/O, state | Start/end sessions, load sessions |
| **ProjectManager** | Project CRUD, JSON I/O | Create/edit projects, resolve IDs |
| **ChartDataPreparer** | Dashboard data aggregation | Prepare chart data for views |
| **DataValidator** | Validation, data integrity | Before persistence |
| **ErrorHandler** | Error logging, user feedback | When errors occur |
| **ProjectStatisticsCache** | Cached project statistics | Get expensive calculations |

---

## 🔄 COMMON WORKFLOWS

### Load Dashboard Data
```swift
// In DashboardRootView.onAppear:
await sessionManager.loadAllSessions()  // Populate allSessions once

// Then dashboard views consume:
let sessions = sessionManager.allSessions  // All views use same cached data
```

### Create Session
```swift
SessionManager.shared.startSession(for: "Project", projectID: "uuid")
// ... user works ...
SessionManager.shared.endSession(notes: "note", mood: 8, action: "Built feature")
```

### Update Project
```swift
var project = ProjectManager.shared.getProject(id: projectID)
project.name = "New Name"
ProjectManager.shared.updateProject(project)
```

---

## 📖 QUICK REFERENCES

- **ARCHITECTURE.md**: System design, data models, flows
- **DATA_FLOW.yaml**: Component dependencies
- **AI_DEVELOPMENT_GUIDE.md**: Feature development workflow

---

**Last Updated**: January 2026  
**For AI Tools**: Copilot, Cline, Cursor
