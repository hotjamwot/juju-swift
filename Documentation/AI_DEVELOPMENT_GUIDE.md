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

**Phases:** Sessions reference phases by `projectPhaseID`. **Archived** phases remain valid for validation and session row display; pickers only offer non-archived phases. Removing a phase from a project (sidebar editor on save, or `deletePhase`) must clear `projectPhaseID` on affected sessions—use `SessionManager.shared.clearProjectPhaseForSessions(projectID:phaseIDs:)` when batching; it posts `.sessionDidEnd` with `userInfo["sessionID"] == "bulkPhaseClear"` so `SessionsView` can reload. Details: **Documentation/PHASE_ID_DATA_INTEGRITY.md**.

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

### What exists today (for AI / new contributors)

| Item | Detail |
|------|--------|
| **Target** | `JujuTests` — macOS **unit test bundle** (not UI tests) |
| **Host app** | `Juju.app` — tests load with `TEST_HOST` / `BUNDLE_LOADER` so `@testable import Juju` resolves |
| **Location** | `JujuTests/` at repo root (sibling of `Juju/`) |
| **Current focus** | (1) Session **CSV integrity** via `SessionDataParser`. (2) **Phase integrity**: `SessionPhaseIntegrity.clearingPhaseReferences` and `DataValidator.validateSession(_:projectList:)` with in-memory `Project` / `SessionRecord` fixtures — see `JujuTests/PhaseDataIntegrityTests.swift`. |
| **Main files** | `SessionDataParserTests.swift`, `PhaseDataIntegrityTests.swift` |

### How to run

- **Xcode**: scheme **Juju** → **Product → Test** (⌘U), or run only `SessionDataParserTests` from the Test navigator.

**Test navigator (◆) looks stale (e.g. only 6 tests)?** The sidebar list is refreshed from the last test build. Use **Product → Clean Build Folder** (hold ⌥), then **Product → Test** (⌘U) again; or **Product → Build For → Testing**. Confirm `PhaseDataIntegrityTests.swift` → File Inspector → **Target Membership** → **JujuTests** is checked. If it still lies, quit Xcode and delete this project’s folder under **Derived Data**, then reopen.
- **CLI** (full `JujuTests` suite):  
  `xcodebuild -scheme Juju -destination 'platform=macOS' test`
- **CLI** (single class):  
  `xcodebuild -scheme Juju -destination 'platform=macOS' test -only-testing:JujuTests/SessionDataParserTests`  
  `xcodebuild -scheme Juju -destination 'platform=macOS' test -only-testing:JujuTests/PhaseDataIntegrityTests`

### Conventions when adding tests

- Use `@testable import Juju` for types that are `internal` (e.g. `SessionDataParser`).
- Prefer **small fixtures** (inline CSV strings) and **XCTAssert** APIs; avoid UI / AppKit in this target unless you add UI tests later.
- If you change **CSV columns**, **parsing**, **`SessionRecord` persistence**, or **phase clear / validation** (`SessionPhaseIntegrity`, `validateSession`), extend `JujuTests/` and mention it in any PR summary.

### Not in scope yet

- UI tests, snapshot tests, and broad manager coverage are **optional follow-ups**. Existing guidance still applies: mock dependencies where singletons hurt testability, and cover legacy session file shapes when touching the parser.

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
| **ARCHITECTURE.md** | Data models, design, test layout summary |
| **SWIFT_PATTERNS.md** | Coding standards; testing patterns |
| **DATA_FLOW.yaml** | Component relationships |

---

**Read SWIFT_PATTERNS.md for detailed code patterns and conventions.**  
**See the Testing section above for the `JujuTests` target and how to run it.**
