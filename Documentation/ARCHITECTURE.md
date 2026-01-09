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

**Purpose**: Represents a single block of tracked work/time. Must be Codable for CSV persistence.

**Key Features:**

- ✅ **Timestamp-Based**: Uses `startDate` and `endDate` (Date objects) as single source of truth
- ✅ **Migration Complete**: No longer uses computed properties - uses full Date objects
- ✅ **ProjectID Required**: New sessions require projectID parameter
- ✅ **Automatic Duration**: Duration calculated on-demand using `session.durationMinutes` computed property

#### SessionRecord Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | ✅ | Unique identifier |
| `startDate` | Date | ✅ | Full timestamp: 2024-12-15 22:30:00 |
| `endDate` | Date | ✅ | Full timestamp: 2024-12-16 00:02:00 |
| `projectName` | String | ✅ | Kept for backward compatibility |
| `projectID` | String? | ⚠️ | Required for new sessions, optional for legacy |
| `activityTypeID` | String? | ❌ | Activity type identifier |
| `projectPhaseID` | String? | ❌ | Project phase identifier |
| `milestoneText` | String? | ❌ | Milestone text |
| `notes` | String | ✅ | Session notes |
| `mood` | Int? | ❌ | Mood rating (0-10) |

#### SessionRecord Initializers

**Legacy Session (backward compatibility):**

```swift
init(id: String, date: String, startTime: String, endTime: String, durationMinutes: Int, projectName: String, notes: String, mood: Int?)
```

**Full Session (all fields):**

```swift
init(id: String, date: String, startTime: String, endTime: String, durationMinutes: Int, projectName: String, projectID: String?, activityTypeID: String?, projectPhaseID: String?, milestoneText: String?, notes: String, mood: Int?)
```

**Modern Session (preferred for new sessions):**

```swift
init(id: String = UUID().uuidString, startDate: Date, endDate: Date, projectName: String, projectID: String, activityTypeID: String? = nil, projectPhaseID: String? = nil, milestoneText: String? = nil, notes: String = "", mood: Int? = nil)
```

#### SessionRecord Methods

**`overlaps(with interval: DateInterval) -> Bool`**

- **Purpose**: Check if session overlaps with a date interval
- **Returns**: `true` if session overlaps with the given interval

---

### 2. Project Model

**Purpose**: Represents the entities being tracked. Must be Codable for JSON persistence.

#### Project Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | ✅ | Unique identifier |
| `name` | String | ✅ | Project name |
| `color` | String | ✅ | Project color (hex code) |
| `about` | String? | ❌ | Project description |
| `order` | Int | ✅ | Display order |
| `emoji` | String | ✅ | Project emoji |
| `archived` | Bool | ✅ | Archive status |
| `phases` | [Phase] | ✅ | Project phases |

#### Project Computed Properties

**`totalDurationHours: Double`**

- **Purpose**: Calculate total duration in hours for this project
- **Implementation**: Uses ProjectStatisticsCache for performance optimization
- **Fallback**: Calculates from SessionManager if cache miss

**`lastSessionDate: Date?`**

- **Purpose**: Get the date of the last session for this project
- **Implementation**: Uses ProjectStatisticsCache for performance optimization
- **Fallback**: Calculates from SessionManager if cache miss

**`swiftUIColor: Color`**

- **Purpose**: Convert hex color to SwiftUI Color
- **Implementation**: Uses JujuUtils.Color(hex:) extension

#### Project Initializers

**Full Project:**

```swift
init(id: String, name: String, color: String, about: String?, order: Int, emoji: String = "📁", phases: [Phase] = [])
```

**Basic Project:**

```swift
init(name: String, color: String = "#4E79A7", about: String? = nil, order: Int = 0, emoji: String = "📁", phases: [Phase] = [])
```

---

### 3. Phase Model

**Purpose**: Represents project subdivisions/milestones.

#### Phase Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | ✅ | Unique identifier |
| `name` | String | ✅ | Phase name |
| `order` | Int | ✅ | Display order |
| `archived` | Bool | ✅ | Archive status |

#### Phase Initializer

```swift
init(id: String = UUID().uuidString, name: String, order: Int = 0, archived: Bool = false)
```

---

### 4. ActivityType Model

**Purpose**: Represents the type of work being done (e.g., Coding, Writing).

#### ActivityType Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | String | ✅ | Unique identifier |
| `name` | String | ✅ | Activity type name |
| `emoji` | String | ✅ | Activity type emoji |
| `description` | String | ✅ | Activity type description |
| `archived` | Bool | ✅ | Archive status |

#### ActivityType Initializer

```swift
init(id: String, name: String, emoji: String, description: String = "", archived: Bool = false)
```

---

## 🔄 Supporting Data Types

### Session Data Transfer Object

**Purpose**: Transfer object for session data creation.

#### SessionData Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `startTime` | Date | ✅ | Session start time |
| `endTime` | Date | ✅ | Session end time |
| `durationMinutes` | Int | ✅ | Calculated duration |
| `projectName` | String | ✅ | Project name (backward compatibility) |
| `projectID` | String | ✅ | Project identifier (required for new sessions) |
| `activityTypeID` | String? | ❌ | Activity type identifier |
| `projectPhaseID` | String? | ❌ | Project phase identifier |
| `milestoneText` | String? | ❌ | Milestone text |
| `notes` | String | ✅ | Session notes |

#### SessionData Initializer

```swift
init(startTime: Date, endTime: Date, durationMinutes: Int, projectName: String, projectID: String, activityTypeID: String? = nil, projectPhaseID: String? = nil, milestoneText: String? = nil, notes: String)
```

---

### Year-Based File System Models

#### YearlySessionFile Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `year` | Int | ✅ | Year (e.g., 2024) |
| `fileName` | String | ✅ | File name (e.g., "2024-data.csv") |
| `fileURL` | URL | ✅ | Full file path |

#### YearlySessionFile Initializer

```swift
init(year: Int, jujuPath: URL)
```

---

### Data Migration Models

#### DataMigrationResult Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `success` | Bool | ✅ | Migration success status |
| `migratedSessions` | Int | ✅ | Number of sessions migrated |
| `createdProjects` | [String] | ✅ | List of created project names |
| `errors` | [String] | ✅ | List of migration errors |

#### DataMigrationResult Initializer

```swift
init(success: Bool, migratedSessions: Int, createdProjects: [String] = [], errors: [String] = [])
```

---

### Data Validation Models

#### DataIntegrityReport Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `isValid` | Bool | ✅ | Overall validation status |
| `errors` | [String] | ✅ | List of validation errors |
| `warnings` | [String] | ✅ | List of validation warnings |
| `repairsPerformed` | [String] | ✅ | List of automatic repairs performed |

#### DataIntegrityReport Initializer

```swift
init(isValid: Bool, errors: [String] = [], warnings: [String] = [], repairsPerformed: [String] = [])
```

---

### Dashboard Data Models

#### DashboardData Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `weeklySessions` | [SessionRecord] | ✅ | Sessions for the current week |
| `projectTotals` | [String: Double] | ✅ | Project ID to total hours mapping |
| `activityTypeTotals` | [String: Double] | ✅ | Activity type ID to total hours mapping |
| `narrativeHeadline` | String | ✅ | Generated narrative headline |

#### DashboardData Initializer

```swift
init(weeklySessions: [SessionRecord], projectTotals: [String: Double], activityTypeTotals: [String: Double], narrativeHeadline: String)
```

---

### Filter Bar Data Models

#### DateRange Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | UUID | ✅ | Unique identifier |
| `startDate` | Date | ✅ | Filter start date |
| `endDate` | Date | ✅ | Filter end date |

**Computed Properties:**

- `isValid: Bool` - Returns true if startDate <= endDate
- `durationDescription: String` - Human-readable duration (e.g., "7d")

#### DateRange Initializer

```swift
init(startDate: Date, endDate: Date)
```

#### SessionsDateFilter Enum

**Available Options:**

- `today` - "Today"
- `thisWeek` - "This Week"
- `thisMonth` - "This Month"
- `thisYear` - "This Year"
- `custom` - "Custom Range"
- `clear` - "Clear"

---

### Chart Data Models

#### ChartDataPoint Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `label` | String | ✅ | Data point label |
| `value` | Double | ✅ | Data point value |
| `color` | String | ✅ | Data point color (hex) |

#### BubbleChartDataPoint Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `x` | Double | ✅ | X-axis value |
| `y` | Double | ✅ | Y-axis value |
| `size` | Double | ✅ | Bubble size |
| `label` | String | ✅ | Bubble label |
| `color` | String | ✅ | Bubble color (hex) |

---

### Editorial Engine Data Models

#### PeriodSessionData Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | UUID | ✅ | Unique identifier |
| `period` | ChartTimePeriod | ✅ | Time period (week/month/year) |
| `sessions` | [SessionRecord] | ✅ | Sessions in this period |
| `totalHours` | Double | ✅ | Total hours in this period |
| `topActivity` | (name: String, emoji: String) | ✅ | Top activity info |
| `topProject` | (name: String, emoji: String) | ✅ | Top project info |
| `milestones` | [Milestone] | ✅ | Milestones achieved |
| `averageDailyHours` | Double | ✅ | Average hours per day |
| `activityDistribution` | [String: Double] | ✅ | Activity ID to hours mapping |
| `projectDistribution` | [String: Double] | ✅ | Project name to hours mapping |
| `timeRange` | DateInterval | ✅ | Time range for this period |

#### ComparativeAnalytics Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | UUID | ✅ | Unique identifier |
| `current` | PeriodSessionData | ✅ | Current period data |
| `previous` | PeriodSessionData | ✅ | Previous period data |
| `trends` | AnalyticsTrends | ✅ | Trend analysis results |

#### AnalyticsTrends Struct

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | UUID | ✅ | Unique identifier |
| `totalHoursChange` | Double | ✅ | Percentage change in total hours |
| `topActivityChange` | (from: String, to: String, change: Double) | ✅ | Top activity change |
| `topProjectChange` | (from: String, to: String, change: Double) | ✅ | Top project change |
| `milestoneCountChange` | Int | ✅ | Change in milestone count |
| `averageDailyHoursChange` | Double | ✅ | Change in average daily hours |
| `activityDistributionChanges` | [String: Double] | ✅ | Activity distribution changes |
| `projectDistributionChanges` | [String: Double] | ✅ | Project distribution changes |

#### ChartTimePeriod Enum

**Available Options:**

- `week` - "This Week"
- `month` - "This Month"
- `year` - "This Year"
- `allTime` - "All Time"

**Computed Properties:**

- `previousPeriod: ChartTimePeriod` - Previous period for comparison
- `durationInDays: Int` - Duration in days for normalization

---

### Dashboard View Type for Navigation

#### DashboardViewType Enum

**Available Options:**

- `weekly` - "Weekly"
- `yearly` - "Yearly"

**Computed Properties:**

- `title: String` - Display title
- `next: DashboardViewType` - Next view type in sequence

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