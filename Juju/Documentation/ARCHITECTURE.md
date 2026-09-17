# Juju Architecture Documentation

**Purpose**: Single source of truth for the system architecture, data models, component relationships, and data flow patterns. Any new developer or AI should start here to understand how Juju is structured.

## 🤖 How to Use This Documentation

**For AI Assistants and Developers:**
- **Architecture Overview**: Complete guide to the system structure and patterns
- **Data Models**: Exact type definitions for all business entities
- **Data Flow**: Component relationships and data movement patterns
- **Cross-Reference**: Use this as the single source of truth for architecture

**Key Relationships:**
- This file combines architecture patterns, data models, and data flow
- All data_packet types are defined in this file
- Component names map to actual Swift classes in the codebase
- See SWIFT_PATTERNS.md for coding conventions, threading, and antipatterns
- See AGENT.md for step-by-step feature development workflows

**When making changes:**
1. Update type definitions here when adding new business entities
2. Update AGENT.md for new development patterns
3. When changing **session CSV format or `SessionDataParser`**, update or add **unit tests** under `JujuTests/` (see **AGENT.md → Testing**)
4. Update **SWIFT_PATTERNS.md** if the change introduces a new pattern or antipattern

---

## 📋 Quick Reference

**Architecture**: MVVM + Managers (logic) + SwiftUI views  
**Data Storage**: CSV/JSON files only (no Core Data or cloud)  
**Session Management**: SessionManager is source of truth
**Threading**: Use @MainActor for SwiftUI-bound ViewModels  
**Async**: All asynchronous work uses async/await (no completion handlers)  
**Views**: Contain no business logic; ViewModels handle state and data flow  
**Singletons**: Avoid except where already used (SessionManager, MenuManager)  
**Automated tests**: `JujuTests` target (unit tests only); session CSV / `SessionDataParser` coverage in `JujuTests/SessionDataParserTests.swift`. Run and conventions: **AGENT.md → Testing**.

---

## 📁 Project Structure

- **App/**: App lifecycle and glue code
- **Core/**: Models, Managers, ViewModels (business logic)
- **Features/**: Feature-specific SwiftUI views + feature-specific viewmodels
- **Shared/**: Cross-cutting UI components, previews, extensions
- **JujuTests/**: XCTest unit tests (`@testable import Juju`); hosted by `Juju.app` (no UI tests in this target)

---

## 🏗️ Core Architectural Patterns

### 1. **Unidirectional Data Flow**
```
UI Components → ViewModels → Managers → File I/O
```
- **UI Layer**: Pure presentation, no business logic
- **ViewModel Layer**: State management and data transformation
- **Manager Layer**: Business logic and data validation
- **File Layer**: Persistence and I/O operations

### 2. **Event-Driven Architecture**
- **NotificationCenter**: Heavy use for reactive updates across components
- **Pattern**: Managers post notifications → Views react and refresh
- **Key Events**: `.sessionDidEnd`, `.projectsDidChange`, `.activityTypesDidChange`

### 3. **Caching Strategy**
- **ProjectStatisticsCache**: Intelligent caching with 30-second expiration
- **Thread Safety**: Uses concurrent queues with barriers for safe access
- **Performance**: Pre-computes statistics in batches to avoid overwhelming the system

### 4. **Thread Safety Patterns**
- **@MainActor**: All UI updates happen on main thread
- **Concurrent Queues**: Background operations use DispatchQueue with barriers
- **Async/Await**: Modern Swift concurrency for long-running operations

---

## 🔄 Manager Architecture

### SessionManager
- **Responsibility**: Session lifecycle and file operations
- **Key Pattern**: Delegates file I/O to SessionFileManager
- **Validation**: All operations pass through DataValidator
- **Notifications**: Posts `.sessionDidEnd` when sessions complete

### ProjectManager
- **Responsibility**: Project and phase management with archiving
- **Key Pattern**: Uses ProjectStatisticsCache for performance
- **Validation**: Ensures project integrity before saving
- **Notifications**: Posts `.projectsDidChange` for UI updates

### ChartDataPreparer
- **Responsibility**: Data aggregation for dashboard charts
- **Key Pattern**: Filters data by date intervals for performance
- **Optimization**: Weekly-only data for current dashboard performance
- **Thread Safety**: Uses @MainActor for UI-bound data

### DataValidator
- **Responsibility**: Centralized validation logic
- **Key Pattern**: Validates all data before persistence
- **Error Handling**: Provides detailed error messages
- **Migration**: Triggers automatic data migration when needed

---

## 📊 Core Business Entities

### 1. Session Model

**Purpose**: Represents a tracked work/time block. Codable for CSV persistence.

**Key Features**: Timestamp-based using `startDate`/`endDate` Date objects, supports projectID, automatic duration calculation. Sessions can now be associated with an "Action" and marked as a "Milestone".

#### SessionRecord Struct

`SessionRecord` conforms to `Identifiable`, `Codable`, and `Equatable` (synthesized — all properties are Equatable).

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | ✅ | Unique identifier |
| `startDate` | Date | ✅ | Start timestamp |
| `endDate` | Date | ✅ | End timestamp |
| `projectName` | String | ✅ | Backward compatibility |
| `projectID` | String? | ⚠️ | Required for new sessions |
| `activityTypeID` | String? | ❌ | Activity type identifier |
| `projectPhaseID` | String? | ❌ | Project phase identifier |
| `action` | String? | ❌ | Session action or description - captures the main achievement or task. |
| `isMilestone` | Bool | ✅ | Whether the session is marked as a significant milestone or achievement. |
| `notes` | String | ✅ | Session notes |
| `mood` | Int? | ❌ | Mood rating (0-10) |

**UI Integration**: The "Action" and "Is Milestone" fields are captured in the `NotesModalView` via a dedicated text field and a toggle switch, respectively. These fields are then passed through `NotesViewModel` and `NotesManager` to be persisted with the session.

#### SessionRecord Initializers

**Constructor:**
```swift
init(id: String = UUID().uuidString, startDate: Date, endDate: Date, projectID: String, activityTypeID: String? = nil, projectPhaseID: String? = nil, action: String? = nil, isMilestone: Bool = false, notes: String = "", mood: Int? = nil)
```

**Methods**: `overlaps(with interval: DateInterval) -> Bool` - checks date interval overlap

---

### 2. Project Model

**Purpose**: Represents tracked entities. Codable for JSON persistence.

#### Project Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | ✅ | Unique identifier |
| `name` | String | ✅ | Project name |
| `color` | String | ✅ | Project color (hex) |
| `about` | String? | ❌ | Description |
| `order` | Int | ✅ | Display order |
| `emoji` | String | ✅ | Emoji |
| `archived` | Bool | ✅ | Archive status |
| `phases` | [Phase] | ✅ | Project phases |

**Computed Properties**: `totalDurationHours`, `lastSessionDate`, `swiftUIColor` (uses cache for performance)

#### Project Initializers

```swift
// Full
init(id: String, name: String, color: String, about: String?, order: Int, emoji: String = "📁", phases: [Phase] = [])
// Basic
init(name: String, color: String = "#4E79A7", about: String? = nil, order: Int = 0, emoji: String = "📁", phases: [Phase] = [])
```

---

### 3. Phase Model

**Purpose**: Project subdivisions/milestones.

#### Phase Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | ✅ | Unique identifier |
| `name` | String | ✅ | Phase name |
| `order` | Int | ✅ | Display order |
| `archived` | Bool | ✅ | Archive status |

**Initializer**: `init(id: String = UUID().uuidString, name: String, order: Int = 0, archived: Bool = false)`

**Integrity**: Archiving a phase keeps session `projectPhaseID` valid and still resolves in the sessions table; removing a phase clears that field on affected sessions on save. Deleting a project migrates all associated sessions to another project first (see `ProjectsViewModel.deleteProjectWithMigration`). The only remaining edge case is bulk-imported CSV rows referencing unknown phase IDs (reported by `DataValidator` on load).

---

### 4. ActivityType Model

**Purpose**: Work type classification (e.g., Coding, Writing).

#### ActivityType Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | ✅ | Unique identifier |
| `name` | String | ✅ | Activity type name |
| `emoji` | String | ✅ | Emoji |
| `description` | String | ✅ | Description |
| `archived` | Bool | ✅ | Archive status |

**Initializer**: `init(id: String, name: String, emoji: String, description: String = "", archived: Bool = false)`

---

## 🔄 Supporting Data Types

### SessionData (Transfer Object)
**Purpose**: Session data creation DTO

```swift
struct SessionData {
    let startTime, endTime: Date
    let durationMinutes: Int
    let projectName: String
    let projectID: String
    let activityTypeID, projectPhaseID: String?
    let action: String?
    let isMilestone: Bool
    let notes: String
}
```

### YearlySessionFile
**Purpose**: Year-based file organization

```swift
struct YearlySessionFile {
    let year: Int
    let fileName: String
    let fileURL: URL
}
```

### DataMigrationResult
**Purpose**: Data migration results

```swift
struct DataMigrationResult {
    let success: Bool
    let migratedSessions: Int
    let createdProjects: [String]
    let errors: [String]
}
```

### DataIntegrityReport
**Purpose**: Data validation results

```swift
struct DataIntegrityReport {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
    let repairsPerformed: [String]
}
```

### DateRange & SessionsDateFilter
**Purpose**: Date filtering

```swift
struct DateRange {
    let id: UUID
    let startDate, endDate: Date
    // Computed: isValid, durationDescription
}

enum SessionsDateFilter {
    case today, thisWeek, thisMonth, thisYear, custom, clear
}
```

---

### Chart Data Models

```swift
struct ChartDataPoint {
    let label: String
    let value: Double
    let color: String // hex
}

struct BubbleChartDataPoint {
    let x, y, size: Double
    let label: String
    let color: String // hex
}

/// A single day's project breakdown for the 90-day timeline chart.
struct DayStack: Identifiable {
    let date: Date
    var isMilestone: Bool = false   // true when this day contains a milestone session
    var sessions: [SessionRecord] = [] // individual session records for the info panel
    var projects: [DayProjectInfo] = [] // per-project colour/name lookup for the info panel
    var id: Date { date }
    var totalHours: Double { sessions.reduce(0) { $0 + Double($1.durationMinutes) / 60.0 } }
}

/// Per-day project colour/name lookup (avoids file I/O per session card).
struct DayProjectInfo: Identifiable {
    let id: String        // project UUID
    let name: String
    let color: String     // hex
    let emoji: String
}

/// A single session rendered as a thin vertical sliver in the 90-day timeline.
struct DayTimelineSession: Identifiable {
    let id: UUID
    let date: Date          // start-of-day for the column
    let startHour: Double   // decimal hour of session start (e.g. 14.5)
    let endHour: Double     // decimal hour of session end (e.g. 16.25)
    let projectID: String
    let projectName: String
    let projectColor: String  // hex
    let projectEmoji: String
    var duration: Double { endHour - startHour }
}

/// Project trend data: rolling last-90-days hours vs yearly average per
/// 90-day period (rolling last-360-days total ÷ 4).
struct YearlyProjectChartData: Identifiable {
    let id = UUID()
    let projectName: String
    let color: String
    let emoji: String
    let recent90DaysHours: Double
    let yearlyAvgPer90Days: Double
}

/// Activity type trend data: rolling last-90-days hours vs yearly average per
/// 90-day period (rolling last-360-days total ÷ 4).
struct ActivityDistributionItem: Identifiable {
    let id = UUID()
    let activityName: String
    let sfSymbol: String
    let recent90DaysHours: Double
    let yearlyAvgPer90Days: Double
}
```

### Editorial Engine Data Models

```swift
/// Summary types for the narrative strip (top of Overview Dashboard).
/// Populated by NarrativeEngine.generateWeeklyHeadline() and consumed by
/// NarrativeSummaryCard in OverviewDashboardView.
/// - Total hours / delta are THIS WEEK.
/// - Top activities / projects are for the LAST 30 DAYS (rolling window).
/// - Delta compares the week against the average active week
///   over a rolling 12-month window (weeks with at least one session,
///   excluding the current partial week). Each historical week is
///   measured Monday → today's weekday offset (e.g., if today is
///   Thursday, each week is Mon→Thu), matching the current week's
///   partial-day range so the comparison is fair.

struct ActivitySummary: Equatable {
    let name: String
    let sfSymbol: String
}

struct ProjectSummary: Equatable {
    let name: String
    let emoji: String
}

struct NarrativeHeadline: Equatable {
    let totalHours: Double
    let topActivity: ActivitySummary
    let topProject: ProjectSummary
    let period: String
    // Computed: formattedHours, headlineText
}

struct ActivityTypeBreakdown: Identifiable, Equatable {
    let id: String        // activity type UUID or "uncategorized"
    let name: String
    let sfSymbol: String
    let hours: Double
}

struct ProjectBreakdown: Identifiable, Equatable {
    let id: String        // project UUID
    let name: String
    let emoji: String
    let color: String     // hex
    let hours: Double
}

/// Published as NarrativeEngine.weekSummary — drives the 3-card row.
struct NarrativeWeekSummary: Equatable {
    let totalHours: Double
    let formattedHours: String      // "12h 30m"
    let topActivities: [ActivityTypeBreakdown]   // sorted descending, top 3 (last 30 days)
    let topProjects: [ProjectBreakdown]          // sorted descending, top 3 (last 30 days)
    let averageWeeklyHours: Double               // rolling 12-month avg of active weeks
    let deltaHours: Double                       // current week − average weekly hours
}

enum ChartTimePeriod {
    case week, month, year, allTime
    // Computed: title, durationInDays, dateInterval
}
```

### DashboardViewType Enum

```swift
enum DashboardViewType {
    case overview, yearly
    // Computed: title, next
}
```

---

## 🎨 Color Support Extension

#### Color Extension

**Purpose**: Convert hex color strings to SwiftUI Color objects

**Initializer:**

```swift
init(hex: String)
```

**Parameters:**

- `hex: String` - Hex color string (e.g., "#FF5733")

**Implementation:**

- Supports both "#RRGGBB" and "RRGGBB" formats
- Parses hex values and converts to RGB components
- Creates SwiftUI Color with normalized RGB values (0.0-1.0)

---

## 📈 Data Flow Patterns

### Session Data Flow (Notes Modal)
1. **UI Input**: User enters "Action" text and optionally marks "Is Milestone" in `NotesModalView`.
2. **ViewModel**: `NotesViewModel` captures these values in its `@Published action` and `@Published isMilestone` properties.
3. **Manager**: `NotesManager` presents the modal and receives the data via `NotesViewModel`'s completion handler when the user saves.
4. **Session Persistence**: `MenuManager` calls `SessionManager.endSession()`, passing the `action` and `isMilestone` along with other session data.
5. **Storage**: `SessionManager` saves the session to a CSV file, including the new `action` and `is_milestone` columns.
6. **Notification**: `SessionManager` posts `.sessionDidEnd` notification.
7. **Cache Update**: `ProjectStatisticsCache` may update its cached values if relevant.
8. **UI Refresh**: Views (e.g., Sessions list, Dashboard) update in response to notifications or by observing `SessionManager.allSessions`.

### Dashboard Data Flow
1. **Initial Data Load (Orchestrated by `DashboardRootView`)**:
   - `DashboardRootView` calls `sessionManager.loadAllSessions()` to populate `sessionManager.allSessions` with the complete dataset.
   - This ensures all dashboard views start with a consistent, comprehensive session history.
2. **Dashboard-Specific Data Preparation**:
   - When a dashboard view (e.g., `OverviewDashboardView` or `YearlyDashboardView`) appears, it receives the already-populated `sessionManager.allSessions`.
   - It then calls `ChartDataPreparer.prepareWeeklyData()` or `ChartDataPreparer.prepareAllTimeData()`, passing the *complete* `sessionManager.allSessions`.
3. **Internal Filtering and Aggregation**:
   - `ChartDataPreparer` filters the received *complete* session list based on the dashboard's requirements (e.g., current week for `prepareWeeklyData`, current year for `prepareAllTimeData` when used by `YearlyDashboardView`).
   - Aggregates the filtered sessions by activity type, project, etc., for chart display. The new `isMilestone` field can be used to filter or highlight milestone sessions in charts.
4. **Caching (ProjectStatisticsCache)**:
   - Project-level statistics are cached by `ProjectStatisticsCache` for performance, which `ChartDataPreparer` might utilize.
5. **Display**:
   - Charts within the respective dashboard view (`OverviewDashboardView`, `YearlyDashboardView`) display the aggregated data provided by `ChartDataPreparer`.

This flow ensures that `sessionManager.allSessions` serves as the single source of truth for all session data, preventing race conditions where a dashboard view might populate this shared state with incomplete, view-specific data.

### Project Management Flow
1. **UI Input**: User creates/edits project
2. **Validation**: DataValidator validates project data
3. **Storage**: ProjectManager stores via JSON files
4. **Notification**: Posts `.projectsDidChange` notification
5. **Cache Update**: ProjectStatisticsCache updates cached values
6. **UI Refresh**: Views update in response to notifications

---

## 🛠️ Key Architectural Decisions

### 1. **Date-Based Session Architecture (MIGRATION COMPLETE)**
- **Before**: `date` + `startTime` + `endTime` + `durationMinutes` (computed properties)
- **After**: `startDate` + `endDate` (Date objects, single source of truth)
- **Benefits**: 
  - Better performance (no repeated string parsing)
  - Type safety (strong typing with Date objects)
  - Maintainability (centralized duration calculation)

### 2. **Backward Compatibility Strategy**
- **SessionDataParser**: Automatically detects and converts legacy CSV formats
- **Column Index Mapping**: Builds dynamic index map from CSV header, handles any column order
- **Migration**: Transparent conversion during data loading
- **Error Handling**: Graceful handling of corrupted or invalid data
- **Flexible Parsing**: Supports CSV with `action` and `is_milestone` columns in any position

### 3. **Performance Optimization**
- **Caching**: ProjectStatisticsCache with intelligent expiration
- **Filtering**: Date-based filtering for dashboard performance
- **Batching**: Processes projects in batches to avoid overwhelming system
- **Lazy Loading**: Only loads data when needed

### 4. **Error Handling Philosophy**
- **Graceful Degradation**: App continues functioning even with data errors
- **User Feedback**: Detailed error messages for validation failures
- **Data Recovery**: Automatic migration and fallback mechanisms
- **Validation**: All data validated before storage, not silently corrected

### 5. **Inline Session Editing Architecture**
- **SessionsRowView**: Supports inline editing via popover components
- **Full Update Method**: All inline edits use `updateSessionFull` for complete validation
- **UI Synchronization**: Robust refresh mechanism with multiple timing attempts
- **Midnight Session Handling**: Automatic end date adjustment for sessions crossing midnight
- **Project/Phase Validation**: Automatic phase clearing when project changes to incompatible project
- **Data Consistency**: All inline edits maintain data integrity through centralized validation

### 6. **Action and Milestone Fields**
- **Purpose**: Capture session action/achievement (`action`) and mark significant sessions (`isMilestone`).
- **UI Capture**: Implemented in `NotesModalView` with a text field for "Action" and a toggle for "Is Milestone".
- **Data Flow**: Values flow through `NotesViewModel` to `NotesManager`, then to `MenuManager`, and finally to `SessionManager` for persistence.
- **CSV Persistence**: CSV format includes `action` and `is_milestone` columns.

### 7. **Active Session Live Capture Architecture**
- **Purpose**: Allow inline editing of all session fields in the dashboard while a session is live, with no mid-session CSV writes.
- **Live-Capture Properties** (on `SessionManager`):
  | Property | Type | Description |
  |----------|------|-------------|
  | `currentNotes` | String | Live notes captured during active session |
  | `currentAction` | String | Live action/achievement text |
  | `currentMood` | Int? | Live mood rating (0-10, nil = unset) |
  | `currentIsMilestone` | Bool | Live milestone flag |
  | `currentActivityTypeID` | String? | Already existed, reused for live edits |
  | `currentProjectPhaseID` | String? | Already existed, reused for live edits |
- **Reset**: All live-capture fields are reset to defaults in `startSession()` and cleared in `endSession()`.
- **No mid-session CSV writes**: All live edits stay in memory until `endSession()` is called.
- **Last-write-wins**: Dashboard edits pre-fill the end-session modal; modal edits are final.
- **Smart Defaults** (in `ActiveSessionStatusView.applySmartDefaults()`): When the dashboard controls first appear, the most recent session for the current project populates the activity type and phase pickers — mirroring the logic in `NotesViewModel.setSmartDefaults()`.
- **Pre-fill to Modal**: When ending a session, `MenuManager.endCurrentSession()` passes all live-capture values as prefill parameters to `NotesManager.presentNotes()`, which forwards them to `NotesViewModel.present()`. The prefill values are applied **after** `prepareForPresentation()` (which runs Smart Defaults), so live values override Smart Defaults.
- **Cancel preserves live values**: If the user cancels the modal, the session stays active and all dashboard values persist unchanged.
- **Collapsible Dashboard Panel** (`ActiveSessionStatusView`): The detail panel is toggled by tapping the header row. It contains:
  - Action text field
  - Notes text editor
  - Activity Type picker (with SF Symbols from `ActivityType.sfSymbol`)
  - Phase picker (filtered to active phases, disabled when no project)
  - Mood slider (0-10, displayed as neutral 5 when unset)
  - Milestone toggle (disabled when Action is empty)

### 8. **Helper Extensions Architecture**
- **Purpose**: Provide reusable, focused utilities for common operations
- **Design Principles**: Single responsibility, non-destructive, chainable, safe
- **Extension Categories**:
  - **Date+SessionExtensions**: Session-specific date manipulation utilities
  - **SessionRecord+Filtering**: Session filtering and validation utilities
  - **Array+SessionExtensions**: Session array manipulation utilities
  - **View+DashboardExtensions**: Dashboard-specific view composition utilities
- **Benefits**: 
  - Improved code readability and maintainability
  - Reduced code duplication across components
  - Enhanced AI-friendliness with clear method boundaries
  - Better testability with focused, single-purpose methods

### 9. **Bulk Session Editing Architecture**
- **Purpose**: Allow users to select multiple sessions and apply bulk changes to Project, Phase, or Mood fields.
- **Activation**: Double-click any session row enters bulk edit mode and selects that session. The filter bar auto-opens and transforms into a bulk action bar.
- **Selection Mechanism**: 
  - `FilterExportState` holds `selectedSessionIDs: Set<String>`, `lastSelectedSessionID`, and `isBulkEditing`
  - Single click in bulk edit mode toggles selection; shift-click selects a contiguous range using a flat ordered list of visible sessions
  - The `toggleSessionSelection()` method on `FilterExportState` handles both single and shift-click logic
- **Visual Feedback**: Selected rows display a 3px accent-coloured bar on their left edge (rendered in `SessionsRowView` when `isSelected && isBulkEditing`)
- **Bulk Action Bar** (within `BottomFilterBar`):
  - Replaces the normal filter dropdowns with: selection count badge, Project dropdown, Phase dropdown (greyed out if mixed projects), Mood popover button, Save & Exit button, Cancel button
  - The bar uses an accent-coloured border to distinguish from filter mode
- **Save Flow**: 
  1. **Save & Exit** triggers `handleManualRefresh()`, which detects `isBulkEditing`
  2. Iterates over all selected sessions, calling `updateSessionFull()` with pending bulk values (or preserving existing if no change)
  3. Calls `exitBulkEditMode()` to reset state, then refreshes the filtered view
- **Phase Rules**: Phase editing disabled when sessions span multiple projects (checked via `resolveBulkPhaseProject()`). A bulk project selection overrides and enables that project's phases.
- **Dependencies**: Uses existing `MoodSelectionPopover`, `updateSessionFull()`, and the `BottomFilterBar` UI infrastructure.
---

## 📋 Coding Conventions

### 1. **Error Handling**
```swift
// ✅ DO: Wrap file I/O in do-catch
do {
    let data = try Data(contentsOf: url)
} catch {
    errorHandler.handleFileError(error, operation: "read", filePath: url.path)
}

// ✅ DO: Validate before storage
guard validator.validateProject(project).isValid else {
    return // Reject invalid data
}
```

### 2. **Thread Safety**
```swift
// ✅ DO: Use @MainActor for UI updates
@MainActor
class ChartDataPreparer: ObservableObject {
    // UI-bound operations
}

// ✅ DO: Use concurrent queues for shared data
private let cacheQueue = DispatchQueue(label: "com.juju.cache", attributes: .concurrent)
cacheQueue.async(flags: .barrier) {
    // Thread-safe updates
}
```

### 3. **Data Flow**
```swift
// ✅ DO: Use notifications for cross-component communication
NotificationCenter.default.post(name: .projectsDidChange, object: nil)

// ✅ DO: Keep UI components pure
// ViewModels handle state, Views handle presentation
```

---

## 🎯 Future Architecture Considerations

- **Scalability**: Monitor cache effectiveness as data grows
- **Extensibility**: Managers are well-separated for easy extension
- **Testing**: Session CSV parsing has a baseline XCTest suite (`JujuTests`). Expand with manager-level tests, fixtures for `DataValidator`, and migration edge cases as needed; keep **AGENT.md → Testing** in sync.

---

## 📊 Component Relationships

#### Session Management Flow
```
MenuManager → SessionManager → SessionFileManager → CSV Files
     ↓              ↓                    ↓
  UI Actions → Business Logic → File Operations → Persistence
```

#### Dashboard Data Flow
```
DashboardRootView → SessionManager (loadAllSessions) → [SessionRecord] (allSessions)
       ↓                     ↓                           ↓
  Dashboard Views → ChartDataPreparer (filter/aggregate) → Chart Data
       ↓                     ↓                           ↓
  UI Display → Views (consume chart data) → User Interface
```

#### Dashboard Greeting Ambience (`Shared/JujuAmbience.swift`)
The top of `OverviewDashboardView` frames the greeting (Te reo + gloss via
`ShimmerTeReoText`) with the "settled page" treatment: a hairline `Divider` rule
with three tiny warm atoms (Theme `glow`/`warmAccent`) resting on it. It is pure
presentation — no data, no hit testing.

- **Entrance**: the group eases in with `Theme.Design.spring` on dashboard open and
  again on return (supported for free because `switch selected` in
  `DashboardRootView` rebuilds `OverviewDashboardView` each time). Falls back to a
  plain `0.2s` opacity fade with Reduce Motion.
- **Sparse pulse**: one atom fires every ~4s, driven by a single repeating 1s
  `Timer` in `JujuAmbienceController` that only mutates published state when a
  transition is due — so the intervening seconds are idle (no `TimelineView`, no
  continuous rendering).
- **Lightweight / dormant guarantee**: the view owns the controller as a
  `@StateObject` and invalidates the timer on `.onDisappear` and in the
  controller's `deinit`. Closing the dashboard window (or leaving the section)
  tears the view down and stops the timer, so this costs nothing while the app
  sits in the menu tray.

#### Tooltip Pattern (Unified Across All Charts)
```
Hover → onHover/onContinuousHover → Set @State hoveredItem
  → TooltipContainer (shared style) → TooltipRow per breakdown item
```

**Tooltip Component Stack** (defined in `Shared/TooltipViews.swift`):
- **TooltipContainer<Content>**: Wraps any content in consistent surface, cornerRadius, shadow, and border
- **TooltipRow**: Color dot + emoji + name + hours
- **TooltipDivider**: Matched divider styling

Reused identically by: `SessionCalendarChartView`, `YearlyProjectBarChartView`, `YearlyActivityTypeBarChartView`.

**Rule**: Never create inline tooltip styling. Always reuse these shared components.

**Exception — 90-Day Chart Info Panel**: The 90-Day Timeline Chart does not use a floating tooltip. Instead, hover state is lifted to the parent (`OverviewDashboardView`) via a `@Binding var hoveredDay: DayStack?`. The `DaySessionInfoPanel` does NOT sit below the chart — it cross-fades in over the merged Trends card at the bottom of the dashboard, replacing the trend charts inside the same fixed-height container (`max(distributionCardHeight, DaySessionInfoPanel.panelMaxHeight)`). This removes all layout pushdown when hovering. The panel displays a horizontal timeline rail with per-session cards (activity type, action, notes preview, phase pill, time range, duration, milestone badge) for the hovered day. Cards alternate above and below the timeline bar and are positioned proportionally to their start time within a fixed 6am–11pm window. The panel is presentation-only — its card chrome (surface + shadow) is supplied by the parent swap container.

**Chart hover detection pattern**: Always use `chartOverlay { proxy in }` with `ChartProxy.value(atX:atY:)` for coordinate conversion. Never use a ZStack sibling with manual `plotFrame` math — it causes coordinate drift and misaligned tooltips.

**Cross-highlight pattern**: When two sibling views need to communicate hover state (e.g., hovering a Notable Moment highlights a bar in the intensity chart), lift a shared `@State` property to the parent view and pass bindings down to both children.

#### 90-Day Timeline Chart Layout
- Sessions render as thin vertical slivers (`RectangleMark`s) positioned by decimal start/end hour within their calendar-day column
- Y-axis: fixed 6am–11pm (`6.0...23.0`), matching the weekly calendar chart; grid lines at 6/9/12/15/18/21/23 with 12-hour am/pm labels
- X-axis: 90-day lookback window with automatic date labels (`MMM d`)
- Hover anywhere in a day column (not just a sliver) sets the `@Binding var hoveredDay: DayStack?` — slivers in the hovered day brighten to full opacity (plain mark brightness: hovered 1.0, rest 0.85). NO annotation overlays for the highlight — conditional annotations pop in/out on every column change and flicker
- Hover state changes use a short `.easeInOut(0.15)` — NEVER a spring on chart state (spring overshoot wobbles the rendered marks)
- X-domain extends 3 days past each edge day so edge columns get real breathing margins; Y domain is `5.5...23.5` (extreme gridlines inset so axis labels stay inside the frame)
- `DaySessionInfoPanel` cross-fades in over the merged Trends card (fixed-height swap container sized by `DaySessionInfoPanel.panelMaxHeight`), showing the horizontal timeline rail with alternating above/below session cards for the hovered day — no layout pushdown
- Cross-midnight sessions split into two slivers: one clipped to 24:00 on the start day and a continuation from 0:00 on the next day
- Data source: `DayTimelineSession` built by `ChartDataPreparer.prepare90DayTimeline()`; `DayStack.sessions` powers the info panel and `DayStack.projects` provides per-project colour/name lookup (avoids file I/O per session card)
- Today's column gets a subtle divider-tint highlight behind its slivers
- Session slivers show: project colour, opacity 0.85 (1.0 when the day is hovered)

#### Calendar Chart Hover Behavior
- Uses `chartOverlay { proxy in }` for hover detection — the overlay lives **inside** the Chart's coordinate space, ensuring pixel-to-value conversion is accurate
- `ChartProxy.value(atX:)` and `proxy.value(atY:)` convert hover pixel positions directly to chart domain values (day name, hour)
- **Important**: Never use a ZStack sibling overlay with manual `plotFrame` mapping — the Chart's coordinate space can drift from the ZStack's. Always use `chartOverlay` for hover detection in SwiftUI Charts
- Hovered session gets full opacity (1.0), others 0.85 (plain mark brightness, no annotation overlays)
- Hover state changes use a short `.easeInOut(0.15)` — never a spring on chart state (spring overshoot wobbles the marks)
- Floating tooltip positioned using edge-aware helpers (`tooltipTooltipX`/`tooltipTooltipY`) that flip direction near chart boundaries; `chartCard()` uses a non-clipping rounded background so tooltips can float past the card edge

#### Trend Charts (dual-bar: last 90 days vs yearly average)
- `yearlyProjectTotals()`: Builds per-project 90-day and 360-day totals in one O(n) pass over the rolling 360-day window
- `yearlyActivityTypeTotals()`: Builds per-activity-type 90-day and 360-day totals in one O(n) pass over the rolling 360-day window
- The 360-day total is divided by 4 at the model level (`yearlyAvgPer90Days`) so the two bars are directly comparable on one scale
- Rolling windows (last 90 / 360 days including today), NOT calendar year — callers must pass ALL sessions; the preparer filters internally
- Charts are purely visual: no on-chart numbers. Rows render name + two bars via shared `TrendBarPair` (solid = last 90 days, light = yearly avg). BOTH charts live in ONE merged "Trends" card with a SINGLE shared `TrendChartLegend` rendered by the parent (`OverviewDashboardView`)
- The ENTIRE row is the hover target (name + bars); hovering shows a numbers-only tooltip: both values plus a % trend delta

#### Project Management Flow
```
ProjectsView → ProjectsViewModel → ProjectManager → JSON Files
     ↓              ↓                    ↓
  User Input → State Management → Business Logic → Persistence
```

#### Data Validation Flow
```
Data Input → DataValidator → Error Handling → User Feedback
     ↓              ↓                    ↓
  Validation → Repair Logic → Data Integrity → Clean State
```

#### File Organization Hierarchy
```
Juju/
├── App/                    # App lifecycle and main entry points
│   ├── AppDelegate.swift   # App initialization and setup
│   ├── DashboardWindowController.swift  # Dashboard window management
│   ├── JujuUtils.swift    # Utility extensions (Color hex init, etc.)
│   └── main.swift         # Application entry point
├── Core/                   # Core business logic and data models
│   ├── SessionPhaseIntegrity.swift  # Phase integrity checks
│   ├── Extensions/         # Core-level extensions
│   │   ├── Array+SessionExtensions.swift
│   │   ├── Date+SessionExtensions.swift
│   │   └── SessionRecord+Filtering.swift
│   ├── Managers/           # Business logic coordinators
│   │   ├── SessionManager.swift      # Session lifecycle management
│   │   ├── ProjectManager.swift      # Project CRUD operations
│   │   ├── ChartDataPreparer.swift   # Dashboard data aggregation
│   │   ├── DataValidator.swift       # Data integrity validation
│   │   ├── ErrorHandler.swift        # Error handling and logging
│   │   ├── NarrativeEngine.swift     # AI narrative generation
│   │   ├── MenuManager.swift         # Menu system management
│   │   ├── IconManager.swift         # Icon management
│   │   ├── ShortcutManager.swift     # Keyboard shortcuts
│   │   ├── SidebarStateManager.swift # Sidebar state management
│   │   ├── Data/            # Data parsing and migration
│   │   │   ├── SessionDataParser.swift
│   │   │   └── SessionMigrationManager.swift
│   │   └── File/            # File I/O operations
│   │       ├── SessionCSVManager.swift
│   │       └── SessionFilePersistenceManager.swift
│   ├── Models/             # Data models and value types
│   │   ├── SessionModels.swift       # Session data structures
│   │   ├── Project.swift             # Project data model
│   │   ├── ActivityType.swift        # Activity type model
│   │   ├── ChartDataModels.swift     # Chart data structures (incl. DayStack)
│   │   ├── JujuError.swift           # Error types
│   │   └── SessionQuery.swift        # Query parameters
│   └── ViewModels/         # UI state management
│       ├── ProjectsViewModel.swift   # Projects UI state
│       └── ProjectStoryViewModel.swift # Project timeline derivation
├── Features/               # Feature-specific implementations
│   ├── Dashboard/          # Dashboard functionality
│   │   ├── DashboardRootView.swift   # Main dashboard container
│   │   ├── Overview/         # Overview dashboard views (weekly summary)
│   │   │   ├── OverviewDashboardView.swift
│   │   │   └── SessionCalendarChartView.swift
│   │   ├── Shared/           # Shared dashboard components
│   │   │   ├── ActiveSessionStatusView.swift
│   │   │   ├── Session90DayTimelineView.swift
│   │   │   └── DaySessionInfoPanel.swift
│   │   └── Yearly/          # Yearly dashboard views
│   │       ├── YearlyProjectBarChartView.swift
│   │       └── YearlyActivityTypeBarChartView.swift
│   ├── Sessions/           # Session management UI
│   │   ├── SessionsView.swift        # Main sessions list
│   │   ├── SessionsRowView.swift     # Individual session row
│   │   └── Components/      # Session UI components
│   │       ├── BottomFilterBar.swift
│   │       ├── FilterToggleButton.swift
│   │       └── InlineSelectionPopover.swift
│   ├── Projects/           # Project management UI
│   │   ├── ProjectsView.swift        # Main projects list
│   │   ├── ProjectSidebarEditView.swift  # Project editing
│   │   └── ProjectStory/      # Project biography/timeline feature
│   │       ├── ProjectStoryContainerView.swift
│   │       └── ProjectStoryView.swift
│   ├── ActivityTypes/      # Activity type management
│   │   ├── ActivityTypeView.swift    # Activity type list
│   │   ├── ActivityTypesViewModel.swift  # Activity types state
│   │   └── ActivityTypeSidebarEditView.swift  # Activity type editing
│   ├── Notes/              # Notes functionality
│   │   ├── NotesManager.swift        # Notes presentation
│   │   ├── NotesModalView.swift      # Notes modal dialog
│   │   └── NotesViewModel.swift      # Notes state management
│   └── Sidebar/            # Sidebar UI
│       ├── SidebarView.swift         # Main sidebar container
│       └── SidebarEditView.swift     # Sidebar editing
├── Shared/                 # Cross-cutting concerns
│   ├── Theme.swift         # App theming, fonts, spacing, layout constants
│   ├── TooltipViews.swift  # Reusable tooltip components (TooltipContainer, TooltipRow, TooltipDivider)
│   └── Extensions/
│       └── ButtonTheme.swift         # Button theming
└── Resources/              # App resources
    └── Assets.xcassets/    # Asset catalog
        ├── AppIcon.appiconset/
        ├── Icons.imageset/
        ├── status-active.imageset/
        ├── status-idle.imageset/
        ├── juju_logo.imageset/
        └── *.colorset/               # Color definitions (Background, Surface, etc.)
```

#### Key Integration Points

**Session → Project Integration:**
- SessionManager validates project references via ProjectManager
- ProjectManager provides project statistics to SessionManager
- DataValidator ensures referential integrity between sessions and projects

**Dashboard → Data Integration:**
- `DashboardRootView` orchestrates initial data loading into `SessionManager`.
- `ChartDataPreparer` instances filter and aggregate data for their specific views.
- Real-time updates flow through `@Published` properties and `NotificationCenter`.

**UI → Business Logic Integration:**
- Views use ViewModels for state management.
- ViewModels coordinate with Managers for business logic.
- Managers handle data persistence and validation.

**Error Handling Integration:**
- ErrorHandler provides centralized error logging.
- DataValidator performs data integrity checks.
- Managers handle specific error scenarios with user feedback.

---

## 📖 ProjectStory Feature

### Overview
ProjectStory provides a read-only narrative timeline for individual projects, showing how work evolved over time through phases, sessions, and milestones. The current design is **"The Braid"** — a dual-track timeline that handles the reality that phases are not always chronological (they can be sub-projects, collaborators, or interleaved).

### Architecture Flow
```
Project → ProjectStoryViewModel → Timeline Items (Chapters + Gaps) + PhaseLanes → ProjectStoryView
```

### Data Derivation Pipeline

1. **Input Sources**:
   - `SessionManager.allSessions` - All session records
   - `ProjectsViewModel.projects` - Project + phase definitions
   - `Calendar` - For weekly density bucketing

2. **Derivation Steps** (in `ProjectStoryViewModel`):
   - **Phase Grouping** (`deriveTimelineItems`): Sessions grouped by `projectPhaseID` (nil/unknown → "Unphased")
   - **Chapter Creation**: One chapter per phase with aggregated data
   - **Density Calculation**: Weekly aggregation of session duration + mood
   - **Milestone Extraction**: Filter sessions with `isMilestone=true` and non-empty action
   - **Timeline Assembly**: Chapters sorted by start date, gaps inserted at future thresholds
   - **Phase Lane Derivation** (`derivePhaseLanes`): One `PhaseLane` per phase used by the project's sessions. Unlike `derivePhaseTimeline`, lanes do **not** assume phases are contiguous or chronological — a lane is a facet (phase / sub-project / collaborator) whose sessions may be scattered across the whole project span. Lanes are sorted by total duration descending, with the unphased lane pinned to the bottom.

### Data Models

| Type | Purpose |
|------|---------|
| `Chapter` | A phase period with sessions, density, and milestones |
| `Milestone` | A significant session with action description |
| `DensityBucket` | Weekly session aggregation (duration, mood, count) |
| `PhaseSegment` | Visual segment for the (legacy) phase timeline bar — kept for backward compatibility, no longer used by the view |
| `PhaseLane` | One row in the Braid: a phase facet with chronological sessions, stats, recent action lines, and weekly density |
| `Gap` | A future period with no sessions (for timeline visualization) |

### Timeline Items Enum
```swift
enum TimelineItem {
    case chapter(Chapter)
    case gap(Gap)
}
```

### View Composition

**ProjectStoryView**:
- Header with project name, emoji, dates, and duration
- Summary stats row (total time, sessions, mood, phases)
- **`ProjectStoryBraidView`** (the core Braid component):
  - **Spine** (top track): chronological session bars, positioned by date, height scaled by duration, coloured by phase (milestone bars in gold)
  - **Phase lanes** (bottom tracks): one `PhaseLaneRow` per phase — a fixed-width title label + a track of small date-positioned marks
  - **Axis labels**: start / mid / end dates (`MMM yyyy`)
  - **`PhaseDetailPanel`**: a pinned strip shown when a phase is highlighted, with date range, total time, avg mood, milestone count, and up to 3 recent distinct non-milestone action lines
- Notable moments section listing milestone sessions (**hoverable** — triggers cross-highlight in the Braid's spine and phase lanes)

### Interactive Features

**Phase Lane Hover**:
- Hovering a `PhaseLaneRow` sets `highlightedPhaseID` (lifted to `ProjectStoryView` as `@State`)
- The spine dims non-matching bars to 18% opacity; the matching lane's bars stay at full opacity
- The lane row itself dims to 35% opacity if another phase is highlighted
- A pinned `PhaseDetailPanel` appears below the lanes with `.transition(.opacity)` and `.animation(.easeOut(duration: 0.15), value: highlightedPhaseID)`

**Spine Bar Hover**:
- Hovering a session bar in the spine sets `highlightedPhaseID` to that session's phase, cross-highlighting its lane

**Milestone Cross-Highlight**:
- A shared `@State highlightedMilestoneSessionID: String?` lives in the parent view (`ProjectStoryView` or preview canvas)
- Passed as a binding to `ProjectStoryNotableMomentsView` and as a value to `ProjectStoryBraidView`
- Hovering a Notable Moment card sets the highlighted ID; the spine dims all non-matching bars to 20% opacity
- The matching milestone bar glows brighter (from `#F5A623` to `#FFD060`)
- The Notable Moment card also calls `onHoverPhase(milestone.phaseID)` so the Braid highlights that phase's lane too
- The Notable Moment card itself also highlights: accent bar turns gold, background brightens, star icon glows

### Reactive Updates
- Listens to `.projectsDidChange` and `.sessionDidEnd` notifications
- Calls `viewModel.reload()` on data changes

This consolidated architecture documentation provides a complete reference for understanding the Juju codebase structure, data models, and component relationships.
