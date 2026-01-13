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

---

## 📋 Quick Reference

**Architecture**: MVVM + Managers (logic) + SwiftUI views  
**Data Storage**: CSV/JSON files only (no Core Data or cloud)  
**Session Management**: SessionManager is source of truth
**Threading**: Use @MainActor for SwiftUI-bound ViewModels  
**Async**: All asynchronous work uses async/await (no completion handlers)  
**Views**: Contain no business logic; ViewModels handle state and data flow  
**Singletons**: Avoid except where already used (SessionManager, MenuManager)

---

## 📁 Project Structure

- **App/**: App lifecycle and glue code
- **Core/**: Models, Managers, ViewModels (business logic)
- **Features/**: Feature-specific SwiftUI views + feature-specific viewmodels
- **Shared/**: Cross-cutting UI components, previews, extensions

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

**Key Features**: Timestamp-based using `startDate`/`endDate` Date objects, supports projectID, automatic duration calculation.

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
| `milestoneText` | String? | ❌ | Milestone text |
| `notes` | String | ✅ | Session notes |
| `mood` | Int? | ❌ | Mood rating (0-10) |

#### SessionRecord Initializers

**Modern (preferred):**
```swift
init(id: String = UUID().uuidString, startDate: Date, endDate: Date, projectName: String, projectID: String, activityTypeID: String? = nil, projectPhaseID: String? = nil, milestoneText: String? = nil, notes: String = "", mood: Int? = nil)
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
    let activityTypeID, projectPhaseID, milestoneText: String?
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
    let milestones: [Milestone]
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
    let milestoneCountChange: Int
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

### Session Data Flow
1. **UI Input**: User creates/edits session
2. **Validation**: DataValidator validates session data
3. **Storage**: SessionManager stores via SessionFileManager
4. **Notification**: Posts `.sessionDidEnd` notification
5. **Cache Update**: ProjectStatisticsCache updates cached values
6. **UI Refresh**: Views update in response to notifications

### Dashboard Data Flow
1. **Data Loading**: ChartDataPreparer loads all sessions
2. **Filtering**: Filters to current week only for performance
3. **Aggregation**: Aggregates by activity type and project
4. **Caching**: Uses cached statistics for performance
5. **Display**: Charts display aggregated data

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
- **Migration**: Transparent conversion during data loading
- **Error Handling**: Graceful handling of corrupted or invalid data

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

### 6. **Helper Extensions Architecture**
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
- **Testing**: Each manager should have comprehensive tests

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
SessionManager → ChartDataPreparer → Dashboard Views → UI
     ↓              ↓                    ↓
  Raw Sessions → Aggregated Data → Visualizations → User Interface
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
- ChartDataPreparer aggregates data from SessionManager
- Dashboard views subscribe to data changes via @Published properties
- Real-time updates flow through ObservableObject pattern

**UI → Business Logic Integration:**
- Views use ViewModels for state management
- ViewModels coordinate with Managers for business logic
- Managers handle data persistence and validation

**Error Handling Integration:**
- ErrorHandler provides centralized error logging
- DataValidator performs data integrity checks
- Managers handle specific error scenarios with user feedback

This consolidated architecture documentation provides a complete reference for understanding the Juju codebase structure, data models, and component relationships.