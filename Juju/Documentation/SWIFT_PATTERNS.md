# Juju Swift Development Patterns

**Purpose**: Definitive reference for code patterns, naming conventions, threading rules, error handling, and project workflows. Read this alongside ARCHITECTURE.md before writing any code so your contributions match the project style. Optimized for AI tools.

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
| **Cache Access** | Use `CacheManager` for invalidation | Don't bypass notification system |

---

## 🧪 TESTING PATTERN

### Current repo (`JujuTests`)

- **Target**: `JujuTests` (macOS unit test bundle; **no UI tests**). **Host**: `Juju.app`.
- **Import**: `@testable import Juju` for internal types (e.g. `SessionDataParser`).
- **Existing coverage**: `JujuTests/SessionDataParserTests.swift` — CSV parse, legacy layouts, round-trip, optionals, midnight-spanning duration.
- **Run / add tests**: **AGENT.md → Testing** (Xcode ⌘U and `xcodebuild` examples).

When you add parsers, validators, or CSV columns, add or extend tests in `JujuTests/` before merging.

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

## 🔧 EXTENSION PATTERNS

### Date+SessionExtensions
Handles date calculations for session timing, midnight-crossing detection, and week/year boundaries.

### Array+SessionExtensions  
Provides session filtering, grouping, and aggregation utilities for dashboard data preparation.

### View+DashboardExtensions
Dashboard-specific view modifiers for consistent styling and layout patterns.

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
| **SessionStateManager** | Session state and data creation | Managing session state transitions |
| **SessionCSVManager** | CSV formatting and year-based file routing | CSV write operations |
| **SessionFileManager** | Thread-safe file I/O with proper quoting | Direct file operations |
| **SessionPersistenceManager** | Session persistence coordination | Persistence workflow |
| **ProjectManager** | Project CRUD, JSON I/O | Create/edit projects, resolve IDs |
| **ActivityTypeManager** | Activity type CRUD, JSON I/O | Load/save activity types |
| **ChartDataPreparer** | Dashboard data aggregation | Prepare chart data for views |
| **DataValidator** | Validation, data integrity | Before persistence |
| **ErrorHandler** | Error logging, user feedback | When errors occur |
| **ProjectStatisticsCache** | Cached project statistics | Get expensive calculations |
| **CacheManager** | Cache invalidation management | Cache state updates |
| **DataMigrationManager** | Legacy data migration | Data version upgrades |
| **NarrativeEngine** | Dashboard editorial content | Generate headlines |
| **ProjectStoryViewModel** | Project timeline derivation | Project story views |

---

## 🟢 LIVE-CAPTURE PATTERN (ACTIVE SESSION)

When you need inline editing of session metadata **during** an active session without triggering CSV writes, use the live-capture pattern on `SessionManager`:

### Properties
```swift
// Add to SessionManager:
@Published var currentNotes: String = ""
@Published var currentAction: String = ""
@Published var currentMood: Int? = nil
@Published var currentIsMilestone: Bool = false
// currentActivityTypeID and currentProjectPhaseID already existed — reuse for live edits
```

### Rules
1. **No mid-session CSV writes** — all edits stay in memory until `endSession()`.
2. **Reset on session start** — clear all live-capture fields in `startSession()`.
3. **Clear on session end** — reset fields after CSV persist in `endSession()`.
4. **Last-write-wins** — dashboard edits pre-fill the end-session modal; modal edits are final.
5. **Cancel preserves** — if the user cancels the modal, session stays active and values persist.

### Prefill-to-Modal Flow
When ending a session from the dashboard or menu bar, pass live values as prefill parameters:

```swift
// In MenuManager.endCurrentSession():
NotesManager.shared.presentNotes(
    projectID: sessionManager.currentProjectID,
    projectName: sessionManager.currentProjectName,
    projects: self.projects,
    prefillNotes: sessionManager.currentNotes,
    prefillAction: sessionManager.currentAction,
    prefillMood: sessionManager.currentMood,
    prefillActivityTypeID: sessionManager.currentActivityTypeID,
    prefillProjectPhaseID: sessionManager.currentProjectPhaseID,
    prefillIsMilestone: sessionManager.currentIsMilestone
) { ... }
```

The prefill values are applied **after** `prepareForPresentation()` (which runs Smart Defaults), so live values override Smart Defaults. This ensures the most recent dashboard edits — not historical defaults — appear in the modal.

### Smart Defaults for Dashboard Controls
Apply the same logic as `NotesViewModel.setSmartDefaults()` in dashboard views:

```swift
private func applySmartDefaults() {
    guard sessionManager.currentActivityTypeID == nil,
          let projectID = sessionManager.currentProjectID else { return }
    
    let sessions = sessionManager.allSessions
        .filter { $0.projectID == projectID }
        .sorted { $0.startDate > $1.startDate }
    
    for session in sessions {
        if let activityID = session.activityTypeID,
           ActivityTypeManager.shared.getActivityType(id: activityID) != nil {
            sessionManager.currentActivityTypeID = activityID
            sessionManager.currentProjectPhaseID = session.projectPhaseID
            break
        }
    }
}
```

Call this in `.onAppear` on the dashboard view.

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

### Info Panel Pattern (Chart Hover)
When a chart needs to show rich detail on hover (more than a tooltip can fit), lift hover state to the parent and use an info panel below the chart:

```swift
// Parent view owns the hover state
@State private var hoveredDay: DayStack? = nil

// Chart exposes hover via a binding
Session90DayBarChartView(dayStacks: stacks, hoveredDay: $hoveredDay)

// Info panel reads the same state
DaySessionInfoPanel(dayStack: hoveredDay)
```

**Rules:**
- The chart view accepts a `@Binding var hoveredDay: DayStack?` — never `@State`
- The parent resolves which data to show (chart hover takes priority over milestone hover)
- Sibling views (e.g., milestone list) can also write to the hover state via callbacks
- The info panel is a pure presentation view — no business logic, no singletons

**Used by**: 90-Day Stacked Bar Chart (`Session90DayBarChartView` → `DaySessionInfoPanel`).

### Collapsible Dashboard Panel Pattern
Use `VStack` with a tappable header and conditionally-rendered detail panel for collapsible sections in the dashboard:

```swift
@State private var isExpanded: Bool = false

var body: some View {
    VStack(spacing: 0) {
        headerRow
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        
        if isExpanded {
            Divider()
            detailPanel
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
```

---

## 📖 QUICK REFERENCES

- **ARCHITECTURE.md**: System design, data models, flows
- **AGENT.md**: Feature development workflow
- **ROADMAP.md**: Project status, completed features, ongoing work, deferred priorities
- **CHANGELOG.md**: Chronological log of significant features, changes, and fixes

---

**Last Updated**: May 2026  
**For AI Tools**: Copilot, Cline, Cursor