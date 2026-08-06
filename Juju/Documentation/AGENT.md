# AI Development Guide: Adding Features to Juju

**Purpose**: Step-by-step guide for adding features, fixing bugs, and following the Juju development workflow. Start here when you need to implement something new or debug an issue.

**[AI_QUICK_REFERENCE]** Step-by-step feature development. For code patterns, see SWIFT_PATTERNS.md.

---

## 🎯 BEFORE STARTING

Read these in order:
1. **ARCHITECTURE.md** - System design, data models, and flows
2. **SWIFT_PATTERNS.md** - Coding standards, threading, antipatterns

---

## ✨ ADDING A NEW FEATURE

### Step 1: Analyze Architecture
- Where does this fit? (Which Manager?)
- What data models?
- File storage? (CSV or JSON?)

### Step 2: Design Data Model
- Add to ARCHITECTURE.md

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

**Phases:** Sessions reference phases by `projectPhaseID`. **Archived** phases remain valid for validation and session row display; pickers only offer non-archived phases. Removing a phase from a project (sidebar editor on save, or `deletePhase`) must clear `projectPhaseID` on affected sessions—use `SessionManager.shared.clearProjectPhaseForSessions(projectID:phaseIDs:)` when batching; it posts `.sessionDidEnd` with `userInfo["sessionID"] == "bulkPhaseClear"` so `SessionsView` can reload. The clearing logic is in `SessionPhaseIntegrity.clearingPhaseReferences()` (sets `projectPhaseID` to `nil`); tested in `JujuTests/PhaseDataIntegrityTests.swift`.

```swift
let projects = ProjectManager.shared.projects
let project = Project(name: "New", color: "#4E79A7", emoji: "📁")
ProjectManager.shared.createProject(project)

let duration = ProjectStatisticsCache.shared.getTotalDuration(for: projectID)
```

---

## 🎨 UI PATTERNS

### Reusable Tooltip Components
When adding chart tooltips, always use the shared components from `Juju/Shared/TooltipViews.swift`:
- `TooltipContainer` — wraps tooltip content in consistent surface, cornerRadius, shadow, and border
- `TooltipRow` — colour dot + emoji + name + hours
- `TooltipDivider` — matched divider styling

**Rule**: Never create inline tooltip styling. Reuse these components to ensure visual consistency across all charts and views (Dashboard, ProjectStory, etc.).

### Chart Hover Detection Pattern
**Always use `chartOverlay`** for hover detection in SwiftUI Charts — never place a hover overlay as a ZStack sibling of the Chart.

```swift
// ✅ CORRECT: chartOverlay keeps coordinates in the Chart's space
.chartOverlay { proxy in
    GeometryReader { geo in
        Color.clear
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    // proxy.value(atX:) and proxy.value(atY:) convert
                    // pixel positions to chart domain values directly
                    let day: String? = proxy.value(atX: location.x)
                    let hour: Double? = proxy.value(atY: location.y)
                    // ... match against data
                case .ended:
                    // clear hover state
                }
            }
    }
}

// ❌ WRONG: ZStack sibling causes coordinate drift
ZStack {
    Chart { ... }
    Color.clear
        .onContinuousHover { location in
            // location is in the ZStack's space, not the Chart's
            // manual plotFrame math is fragile and breaks
        }
}
```

**Why**: The Chart's internal coordinate space (accounting for axis labels, padding) can drift from the ZStack's coordinate space. `ChartProxy.value(atX:atY:)` handles this correctly.

### Edge-Aware Tooltip Positioning
When floating tooltips near the cursor, use edge-aware helpers that flip direction near chart boundaries:

```swift
private func tooltipX(in size: CGSize) -> CGFloat {
    let idealX = cursorX + padding + tooltipWidth / 2
    if idealX + tooltipWidth / 2 > size.width {
        // Flip to left of cursor when near right edge
        return max(cursorX - padding - tooltipWidth / 2, tooltipWidth / 2)
    }
    return min(idealX, size.width - tooltipWidth / 2)
}
```

### Cross-Highlight Pattern (Sibling View Communication)
When two sibling views need to react to the same hover state (e.g., hovering a Notable Moment highlights a bar in the ProjectStory Braid's spine):

1. **Lift** a shared `@State` property to the **parent** view
2. **Pass a binding** to the source view (e.g., `NotableMomentsView`)
3. **Pass the value** to the target view (e.g., `ProjectStoryBraidView`)
4. The source writes to the binding on hover; the target reads it to adjust rendering

```swift
// In parent view:
@State private var highlightedSessionID: String? = nil
@State private var highlightedPhaseID: String? = nil

// Source view (writes):
NotableMomentsView(
    highlightedSessionID: $highlightedSessionID,
    onHoverPhase: { highlightedPhaseID = $0 }
)

// Target view (reads):
ProjectStoryBraidView(
    highlightedSessionID: highlightedSessionID,
    highlightedPhaseID: $highlightedPhaseID
)
```

### SwiftUI Preview Pattern for Complex Views
For views that depend on singletons (e.g., `ProjectsViewModel.shared`), create a preview-specific wrapper that bypasses singletons:

```swift
#Preview("Feature – Dashboard Size") {
    // Create mock data
    let viewModel = FeatureViewModel(
        dataProvider: { mockData }
    )
    viewModel.reload()
    
    return FeaturePreviewCanvas(viewModel: viewModel)
        .frame(width: 1200, height: 900)
        .background(Theme.Colors.background)
}

// Wrapper that accepts a pre-built view model
private struct FeaturePreviewCanvas: View {
    @StateObject private var viewModel: FeatureViewModel
    init(viewModel: FeatureViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    var body: some View { ... }
}
```

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
| **Current focus** | (1) Session **CSV integrity** via `SessionDataParser`. (2) **Phase integrity**: `SessionPhaseIntegrity.clearingPhaseReferences` and `DataValidator.validateSession(_:projectList:)` with in-memory `Project` / `SessionRecord` fixtures — see `JujuTests/PhaseDataIntegrityTests.swift`. (3) **ProjectStory derivation**: `deriveTimelineItems`, `deriveWeeklyDensity`, and `derivePhaseLanes` (the Braid's lane model) — see `JujuTests/ProjectStoryDerivationTests.swift`. |
| **Main files** | `SessionDataParserTests.swift`, `PhaseDataIntegrityTests.swift`, `ProjectStoryDerivationTests.swift` |

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
| **SWIFT_PATTERNS.md** | Coding standards, threading, antipatterns |
| **ROADMAP.md** | Project status, completed features, ongoing work, deferred priorities |
| **CHANGELOG.md** | Chronological log of significant features, changes, and fixes |

---

**Read SWIFT_PATTERNS.md for detailed code patterns and conventions.**  
**See the Testing section above for the `JujuTests` target and how to run it.**
