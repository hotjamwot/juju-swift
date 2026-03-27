# Juju Architecture Documentation

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
- DATA_FLOW.yaml provides machine-readable data flow specification

**When making changes:**
1. Update type definitions here when adding new business entities
2. Update DATA_FLOW.yaml to reflect new data_packet types
3. Update AI_DEVELOPMENT_GUIDE.md for new development patterns
4. When changing **session CSV format or `SessionDataParser`**, update or add **unit tests** under `JujuTests/` (see **AI_DEVELOPMENT_GUIDE.md → Testing**)

---

## 📋 Quick Reference

**Architecture**: MVVM + Managers (logic) + SwiftUI views  
**Data Storage**: CSV/JSON files only (no Core Data or cloud)  
**Session Management**: SessionManager is source of truth
**Threading**: Use @MainActor for SwiftUI-bound ViewModels  
**Async**: All asynchronous work uses async/await (no completion handlers)  
**Views**: Contain no business logic; ViewModels handle state and data flow  
**Singletons**: Avoid except where already used (SessionManager, MenuManager)  
**Automated tests**: `JujuTests` target (unit tests only); session CSV / `SessionDataParser` coverage in `JujuTests/SessionDataParserTests.swift`. Run and conventions: **AI_DEVELOPMENT_GUIDE.md → Testing**.

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

### DashboardData
**Purpose**: Dashboard data aggregation

```swift
struct DashboardData {
    let weeklySessions: [SessionRecord]
    let projectTotals: [String: Double]
    let activityTypeTotals: [String: Double]
    let narrativeHeadline: String
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
```

### Editorial Engine Data Models

```swift
struct PeriodSessionData {
    let id: UUID
    let period: ChartTimePeriod
    let sessions: [SessionRecord]
    let totalHours: Double
    let topActivity: (name: String, emoji: String)
    let topProject: (name: String, emoji: String)
    let milestones: [Milestone] // Note: Milestones here might need to consider the new isMilestone flag
    let averageDailyHours: Double
    let activityDistribution: [String: Double]
    let projectDistribution: [String: Double]
    let timeRange: DateInterval
}

struct ComparativeAnalytics {
    let id: UUID
    let current: PeriodSessionData
    let previous: PeriodSessionData
    let trends: AnalyticsTrends
}

struct AnalyticsTrends {
    let id: UUID
    let totalHoursChange: Double
    let topActivityChange: (from: String, to: String, change: Double)
    let topProjectChange: (from: String, to: String, change: Double)
    let milestoneCountChange: Int // This should now count sessions where isMilestone is true
    let averageDailyHoursChange: Double
    let activityDistributionChanges: [String: Double]
    let projectDistributionChanges: [String: Double]
}

enum ChartTimePeriod {
    case week, month, year, allTime
    // Computed: previousPeriod, durationInDays
}
```

### DashboardViewType Enum

```swift
enum DashboardViewType {
    case weekly, yearly
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
   - When a dashboard view (e.g., `WeeklyDashboardView` or `YearlyDashboardView`) appears, it receives the already-populated `sessionManager.allSessions`.
   - It then calls `ChartDataPreparer.prepareWeeklyData()` or `ChartDataPreparer.prepareAllTimeData()`, passing the *complete* `sessionManager.allSessions`.
3. **Internal Filtering and Aggregation**:
   - `ChartDataPreparer` filters the received *complete* session list based on the dashboard's requirements (e.g., current week for `prepareWeeklyData`, current year for `prepareAllTimeData` when used by `YearlyDashboardView`).
   - Aggregates the filtered sessions by activity type, project, etc., for chart display. The new `isMilestone` field can be used to filter or highlight milestone sessions in charts.
4. **Caching (ProjectStatisticsCache)**:
   - Project-level statistics are cached by `ProjectStatisticsCache` for performance, which `ChartDataPreparer` might utilize.
5. **Display**:
   - Charts within the respective dashboard view (`WeeklyDashboardView`, `YearlyDashboardView`) display the aggregated data provided by `ChartDataPreparer`.

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

### 7. **Helper Extensions Architecture**
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
- **Testing**: Session CSV parsing has a baseline XCTest suite (`JujuTests`). Expand with manager-level tests, fixtures for `DataValidator`, and migration edge cases as needed; keep **AI_DEVELOPMENT_GUIDE.md → Testing** in sync.

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
│   └── main.swift         # Application entry point
├── Core/                   # Core business logic and data models
│   ├── Managers/          # Business logic coordinators
│   │   ├── SessionManager.swift      # Session lifecycle management
│   │   ├── ProjectManager.swift      # Project CRUD operations
│   │   ├── ChartDataPreparer.swift   # Dashboard data aggregation
│   │   ├── DataValidator.swift       # Data integrity validation
│   │   ├── ErrorHandler.swift        # Error handling and logging
│   │   ├── NarrativeEngine.swift     # AI narrative generation
│   │   ├── MenuManager.swift         # Menu system management
│   │   ├── IconManager.swift         # Icon management
│   │   ├── ShortcutManager.swift     # Keyboard shortcuts
│   │   └── SidebarStateManager.swift # Sidebar state management
│   ├── Models/            # Data models and value types
│   │   ├── SessionModels.swift       # Session data structures
│   │   ├── Project.swift             # Project data model
│   │   ├── ChartDataModels.swift     # Chart data structures
│   │   ├── JujuError.swift           # Error types
│   │   ├── SessionQuery.swift        # Query parameters
│   │   └── DashboardViewType.swift   # Dashboard view types
│   └── ViewModels/        # UI state management
│       └── ProjectsViewModel.swift   # Projects UI state
├── Features/              # Feature-specific implementations
│   ├── Dashboard/         # Dashboard functionality
│   │   ├── DashboardRootView.swift   # Main dashboard container
│   │   ├── Weekly/          # Weekly dashboard views
│   │   │   ├── WeeklyDashboardView.swift
│   │   │   ├── WeeklyEditorialView.swift
│   │   │   ├── SessionCalendarChartView.swift
│   │   │   └── WeeklyActivityBubbleChartView.swift
│   │   └── Yearly/          # Yearly dashboard views
│   │       ├── YearlyDashboardView.swift
│   │       ├── YearlyProjectBarChartView.swift
│   │       ├── YearlyActivityTypeBarChartView.swift
│   │       └── MonthlyActivityTypeGroupedBarChartView.swift
│   ├── Sessions/          # Session management UI
│   │   ├── SessionsView.swift        # Main sessions list
│   │   ├── SessionsRowView.swift     # Individual session row
│   │   └── Components/      # Session UI components
│   │       ├── BottomFilterBar.swift
│   │       ├── FilterToggleButton.swift
│   │       └── InlineSelectionPopover.swift
│   ├── Projects/          # Project management UI
│   │   ├── ProjectsView.swift        # Main projects list
│   │   └── ProjectSidebarEditView.swift  # Project editing
│   ├── ActivityTypes/     # Activity type management
│   │   ├── ActivityTypeView.swift    # Activity type list
│   │   └── ActivityTypeSidebarEditView.swift  # Activity type editing
│   ├── Notes/             # Notes functionality
│   │   ├── NotesModalView.swift      # Notes modal dialog
│   │   └── NotesViewModel.swift      # Notes state management
│   └── Sidebar/           # Sidebar UI
│       ├── SidebarView.swift         # Main sidebar container
│       └── SidebarEditView.swift     # Sidebar editing
├── Shared/                # Cross-cutting concerns
│   ├── Theme.swift        # App theming and styling
│   ├── TooltipView.swift  # Tooltip component
│   ├── Extensions/        # Swift extensions
│   │   ├── ButtonTheme.swift         # Button theming
│   │   └── NSColor+SwiftUI.swift     # Color extensions
│   └── Preview/           # Preview helpers
│       └── SimplePreviewHelpers.swift  # Preview utilities
└── Resources/             # App resources
    └── Assets.xcassets/   # Asset catalog
        ├── AppIcon.appiconset/       # App icons
        ├── Icons.imageset/          # UI icons
        ├── status-active.imageset/  # Active status icon
        ├── status-idle.imageset/    # Idle status icon
        └── *.colorset/              # Color definitions
```

#### Key Integration Points

**Session → Project Integration:**
- SessionManager validates project references via ProjectManager
- ProjectManager provides project statistics to SessionManager
- DataValidator ensures referential integrity between sessions and projects

**Dashboard → Data Integration:**
- `DashboardRootView` orchestrates initial data loading into `SessionManager`.
- Individual dashboard views (`WeeklyDashboardView`, `YearlyDashboardView`) consume `sessionManager.allSessions` and pass it to their `ChartDataPreparer` instances.
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

This consolidated architecture documentation provides a complete reference for understanding the Juju codebase structure, data models, and component relationships.
