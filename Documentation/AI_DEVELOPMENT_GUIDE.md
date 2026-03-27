# AI Development Guide: Adding Features to Juju

**[AI_QUICK_REFERENCE]** Step-by-step feature development. For code patterns, see SWIFT_PATTERNS.md.

---

## 🎯 BEFORE STARTING

Read these in order:
1. **ARCHITECTURE.md** - System design
2. **SWIFT_PATTERNS.md** - Coding standards & threading
3. **DATA_FLOW.yaml** - Component relationships

---

## ✨ ADDING A NEW FEATURE

### Step 1: Analyze Architecture
- Where does this fit? (Which Manager?)
- What data models?
- File storage? (CSV or JSON?)

### Step 2: Design Data Model
- Add to ARCHITECTURE.md
- Update DATA_FLOW.yaml if new component

### Step 3: Implement Manager Methods
```swift
func featureOperation() async -> FeatureResult {
    // 1. Validate
    guard isValid else { return .failure }
    
    // 2. Perform work
    let result = try performOperation()
    
    // 3. Persist
    try await saveToStorage()
    
    // 4. Notify UI
    NotificationCenter.default.post(name: .featureDidChange, object: nil)
    
    return .success(result)
}
```

### Step 4: Create ViewModel
```swift
@MainActor
class FeatureViewModel: ObservableObject {
    @Published var data: [FeatureModel] = []
    
    func load() async {
        data = try await FeatureManager.shared.loadData()
    }
}
```

### Step 5: Build UI (Pure Presentation)
- Use ViewModel for state
- Follow Theme styling
- Add doc comments

### Step 6: Handle Errors
```swift
do {
    result = try await operation()
} catch {
    ErrorHandler.shared.handleError(error, context: "ClassName.methodName")
}
```

### Step 7: Post Notifications
- Observers refresh automatically
- Update cache invalidation

---

## 🐛 FIXING A BUG

1. **Reproduce** - Write minimal test case
2. **Root Cause** - Check error handling, threading, notifications
3. **Fix** - Implement fix, not workaround
4. **Verify** - Confirm fix, check for regressions

---

## ⚡ OPTIMIZATION CHECKLIST

- [ ] Using cached data? (`SessionManager.allSessions`, `ProjectStatisticsCache`)
- [ ] File I/O on background?
- [ ] Lists lazy loaded?
- [ ] Dashboard using `ChartDataPreparer` for filtering?

---

## 📊 SESSION OPERATIONS

Common `SessionManager` usage. Full flow and persistence details are in **ARCHITECTURE.md** (session data flow).

### Domain errors

Prefer `JujuError` for typed failures (see `Juju/Core/Models/JujuError.swift`):

```swift
throw JujuError.sessionError(operation: "end", sessionID: id, reason: "No active session", state: "idle")
throw JujuError.dataError(operation: "parse", entity: "session", reason: "Missing project_id", context: "CSV row 42")
throw JujuError.migrationError(fromVersion: "1", toVersion: "2", reason: "Unsupported column layout", affectedRecords: 0)
```

### Load all sessions
```swift
let allSessions = await SessionManager.shared.loadAllSessions()
// `SessionManager.shared.allSessions` holds the cached in-memory array
```

### Start / end session
```swift
SessionManager.shared.startSession(for: "Project display name", projectID: "project-uuid")
// ... user works ...
SessionManager.shared.endSession(
    notes: "What shifted today",
    mood: 8,
    activityTypeID: "optional-activity-type-id",
    projectPhaseID: "optional-phase-id",
    action: "Shipped the feature",
    isMilestone: false
)
```

### Delete session
```swift
SessionManager.shared.deleteSession(id: "session-uuid")
```

---

## 📈 PROJECT OPERATIONS

```swift
let projects = ProjectManager.shared.projects
let project = Project(name: "New", color: "#4E79A7", emoji: "📁")
ProjectManager.shared.createProject(project)

let duration = ProjectStatisticsCache.shared.getTotalDuration(for: projectID)
```

---

## 🎨 UI PATTERNS

```swift
// Use Theme
.padding(.horizontal, Theme.spacingMedium)
.background(Theme.Colors.surface)
.font(Theme.Fonts.body)

// State in ViewModel, not View
@StateObject private var viewModel = FeatureViewModel()

// Views are pure presentation
struct SessionsView: View {
    @StateObject private var viewModel = SessionsViewModel()
    var body: some View {
        List(viewModel.sessions) { session in
            SessionsRowView(session: session)
        }
    }
}
```

---

## 🚨 ERROR HANDLING

```swift
do {
    result = try await operation()
} catch {
    ErrorHandler.shared.handleError(error, context: "ClassName.methodName")
}
```

**Never use** `try?` or `try!`

---

## 🧪 TESTING

- Unit tests for Managers
- Mock objects for dependencies
- Test with new AND legacy data
- Test error scenarios

---

## ⚠️ COMMON MISTAKES

1. **projectName instead of projectID** → Use UUID
2. **Block main thread with I/O** → Use async/await
3. **Forget notifications** → UI won't update
4. **Missing error handling** → Silent crashes
5. **Race conditions** → Use @MainActor
6. **No validation before persist** → Corrupted data

---

## 📚 DOCUMENTATION FILES

| File | Purpose |
|------|---------|
| **ARCHITECTURE.md** | Data models, design |
| **SWIFT_PATTERNS.md** | Coding standards |
| **DATA_FLOW.yaml** | Component relationships |

---

**Read SWIFT_PATTERNS.md for detailed code patterns and conventions.**
