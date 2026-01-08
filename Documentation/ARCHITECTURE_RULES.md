You are a coding expert helping me with my Juju app, a menu bar time-tracking app built in Swift.
This document describes the architecture, structure, and coding conventions used in Juju. 
Use it as the source of truth when generating or modifying code.

---

## 🤖 How to Use This Documentation

**For AI Assistants and Developers:**
- **Architecture Overview**: Start here to understand the overall structure and patterns
- **Project Structure**: Navigate the codebase using the defined directory organization
- **Coding Conventions**: Follow these rules when writing or modifying code
- **Data Flow Reference**: See `DATA_FLOW.yaml` for detailed component interactions
- **Data Models**: Refer to `ARCHITECTURE_SCHEMA.md` for exact type definitions

**Key Relationships:**
- This file defines the **architectural patterns** that guide the system design
- `DATA_FLOW.yaml` shows **how data moves** through these architectural components
- `ARCHITECTURE_SCHEMA.md` provides the **exact data structures** used in this architecture

---

## 📋 Quick Reference

## 📋 Quick Reference

**Architecture**: MVVM + Managers (logic) + SwiftUI views  
**Data Storage**: CSV/JSON files only (no Core Data or cloud)  
**Session Management**: SessionPersistenceManager is source of truth
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

## 🍏 Menubar Architecture

The macOS menu bar interface is controlled by MenuManager and IconManager. The menu dropdown uses NSMenu and triggers actions into SessionManager.

---

## 🗂 Data Storage Locations

All data is user-owned and lives at: ~/Library/Application Support/juju/

- **Sessions**: ~/Library/Application Support/juju/YYYY-data.csv
  - **Format**: Modern Date-based CSV with `start_date` and `end_date` columns
  - **Status**: ✅ Migration complete - computed properties removed, using full Date objects
  - **Parser**: SessionDataParser handles both legacy and new formats with automatic format detection
  - **Error Handling**: ✅ Fixed - All 6 optional string unwrapping errors resolved in SessionDataParser
- **Projects**: projects.json in the same folder
- **Activity Types**: activityTypes.json in the same folder

No data is stored elsewhere.

## 🔄 Session Data Architecture (Updated)

### Core Session Model
- **SessionRecord**: Uses `startDate` and `endDate` (Date objects) as single source of truth
- **Duration Calculation**: Automatic via DurationCalculator from Date objects
- **Backward Compatibility**: Legacy sessions automatically converted during parsing
- **Error Handling**: ✅ Fixed - All 6 optional string unwrapping errors resolved in SessionDataParser

### CSV Format Evolution
- **Legacy Format**: `date`, `start_time`, `end_time`, `duration_minutes` columns
- **Modern Format**: `start_date`, `end_date` columns (full timestamps)
- **Migration**: Automatic format detection and conversion in SessionDataParser
- **Performance**: Optimized parsing with proper bounds checking and optional handling

---

## 🎯 Context of Juju app:

### ✅ System Tray Interface
- Dynamic menu bar icon showing active/idle state
- **Quick actions**: Start Session, End Session, View Dashboard, Quit

### ⏱ Session Tracking
- Precise start/end timestamps with automatic duration calculation
- Project association, post-session notes, and mood tracking (0–10)
- All data saved as CSV for transparency and portability

### 📁 Local Storage
- Flat file system: No cloud, no lock-in, no hidden database
- Sessions: YYYY-data.csv, Projects: projects.json, Activity Types: activityTypes.json

### 📊 Dashboard

**Navigation**: Permanent sidebar with icons for Charts (default), Sessions, Projects, and Activity Types

**Layout**: Fixed 1400x1000 window with responsive 2x2 grid layout using GeometryReader

**Charts Tab**: 
- Weekly/Yearly toggle with floating navigation buttons
- Hero section with dynamic narrative headline and active session status
- Weekly: Activity Bubble Chart + Session Calendar Chart
- Yearly: Project/Activity Distribution charts + Monthly Breakdown chart

**Sessions Tab**: Current week focus with filter/export controls and inline edit/delete actions

**Projects Tab**: Project list with CRUD operations, color management, archiving, and session counting

**Activity Types Tab**: Activity type management with emoji picker, archiving, and CRUD operations

---

## 📄 Data Flow Maintenance Rules

The `DATA_FLOW.yaml` file serves as the **System Blueprint for Critical Data**. Its primary goal is to formally define the path, transformation, and dependencies of major data objects within the Juju application.

### 🎯 Document Purpose
The `data_flow.yaml` file provides immediate, unambiguous context regarding data inputs (`data_packet` from `source`) and required outputs (`data_packet` to `target`) for any code changes. It enforces separation of concerns by clearly mapping business processes to specific components and defines a clear sequence of processing steps to prevent circular dependencies.

### 🔑 DFD Structure and Terminology
The document is organized into two primary lists: `nodes` and `edges`.

| Key | Definition | Rule for Creation/Update |
| --- | --- | --- |
| **`nodes`** | A discrete step in the data transformation process, tied to a specific component. | **Rule:** Only create a node for a step that performs **meaningful business logic or data transformation** (e.g., aggregation, saving, formatting). |
| **`component`** | The specific **Swift class or struct** that contains the logic for the node. | **Rule:** Must map directly to a file/class name in the Swift project (e.g., `SessionManager`). |
| **`function`** | A human-readable, high-level action (verb-noun) performed by the node. | **Rule:** Keep it concise (e.g., "Capture Session Duration," "Persist Session Data"). |
| **`edges`** | The directed connection that shows data moving from one node to the next. | **Rule:** Must connect a **`source`** (the sending node's `id`) to a **`target`** (the receiving node's `id`). |
| **`data_packet`** | The specific **Swift struct or class** being transferred between nodes. | **Rule:** Must be a **business-critical, typed data object** (e.g., `SessionRecord`, `DashboardData`). Internal primitives (like `Bool` or `Int`) are generally abstracted out. |

### 🛠️ Firm Rules for Maintenance (The AI's Mandate)
When making any change to the data flow or adding new features, the AI assistant **MUST** adhere to the following rules:

1. **Prioritize Abstraction:** Do not document minor internal functions (e.g., button taps, simple UI updates). Only document the movement and transformation of **business-critical data objects**.
2. **One-to-One Component Mapping:** Ensure the `component` field always refers to a specific, existing Swift class/struct responsible for that node's function.
3. **Strict Data Packet Definition:** For every `edge`, the `data_packet` must be defined as a specific `struct` or `class` name. This forces the use of strongly-typed inputs/outputs for the connected components.
4. **Enforce Unidirectional Flow:** The flow must be a directed graph. There should be no cyclical dependencies (i.e., Node A \rightarrow Node B \rightarrow Node A) that represent an endless loop in the data pipeline.
5. **Maintain YAML Syntax:** Ensure all updates are properly indented and follow correct YAML key-value pair syntax for machine-readability.

---

## 📊 Dashboard Architecture

### Dashboard Layout System

The dashboard uses a simplified, responsive layout system built around the `DashboardLayout` component:

**Core Components:**
- **DashboardLayout**: Main layout container that arranges charts in a 2x2 grid (top row: 2 charts, bottom row: 1 full-width chart)
- **Individual Chart Views**: Each chart is self-contained with no frame constraints, allowing the layout system to control sizing
- **DashboardRootView**: Root container that manages navigation between Weekly and Yearly dashboard views

**Layout Structure:**
- **Top Row**: Two charts side by side (48% width each, 45% height)
- **Bottom Row**: One full-width chart (100% width, 55% height)
- **Spacing**: 24px between charts, 24px padding around edges
- **Responsive**: Uses GeometryReader to adapt to window size changes
- **Consistent Padding**: Both Weekly and Yearly dashboards use identical padding structure (24px horizontal and bottom padding)

**Chart Views (No Frame Constraints):**
- **WeeklyEditorialView**: Narrative summary with total hours and focus activity
- **WeeklyActivityBubbleChartView**: Bubble chart showing activity distribution
- **SessionCalendarChartView**: Calendar view of weekly sessions with activity emojis
- **ProjectDistributionBarChartView**: Horizontal bars showing project time distribution
- **ActivityDistributionBarChartView**: Horizontal bars showing activity type distribution
- **MonthlyActivityBreakdownChartView**: Grouped bar chart showing monthly trends

**Chart Styling:**
- All charts use consistent styling: surface background, corner radius, border, and shadow
- Charts have padding for "breathing room" inside their allocated space
- No individual chart titles (charts speak for themselves)

**Navigation:**
- Small circle navigation circles for switching between Weekly and Yearly views, plus keyboard shortcut (cmd + arrows)
- Active session status bar positioned at top of dashboard
- Sidebar remains visible with permanent navigation icons

**Performance:**
- Charts use flexible sizing to adapt to available space
- No fixed frame constraints that could cause layout conflicts
- Efficient data preparation with ChartDataPreparer
- Event-driven updates when sessions or projects change

**Data Flow:**
1. DashboardRootView passes state objects to Weekly/Yearly views
2. Chart views receive data through @ObservedObject bindings
3. Charts display data without business logic (pure presentation)
4. Layout system controls all sizing and positioning
5. Floating elements (navigation, active session) position independently

**Key Files:**
- `DashboardLayout.swift`: Main layout component
- `WeeklyDashboardView.swift`: Weekly dashboard implementation
- `YearlyDashboardView.swift`: Yearly dashboard implementation
- `DashboardRootView.swift`: Root container with navigation

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
