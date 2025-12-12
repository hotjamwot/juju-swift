You are a coding expert helping me with my Juju app, a menu bar time-tracking app built in Swift.
This document describes the architecture, structure, and coding conventions used in Juju. 
Use it as the source of truth when generating or modifying code.

---

## 📋 Quick Reference

**Architecture**: MVVM + Managers (logic) + SwiftUI views  
**Data Storage**: CSV/JSON files only (no Core Data or cloud)  
**Session Management**: SessionDataManager is source of truth  
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

## 🔑 Key Models

- **Session**: date, start, end, duration, projectId, activityTypeId, phaseID, notes, mood
- **Project**: id, name, emoji, color, about, archived?
- **Phase**: id, name, order, archived? (project phases/subdivisions)
- **ActivityType**: id, name, emoji, description, archived?

---

## 🗂 Data Storage Locations

All data is user-owned and lives at: ~/Library/Application Support/juju/

- **Sessions**: ~/Library/Application Support/juju/YYYY-data.csv
- **Projects**: projects.json in the same folder
- **Activity Types**: activityTypes.json in the same folder

No data is stored elsewhere.

---

## 🎯 Context of Juju app:

### ✅ System Tray Interface
- Lives in your menu bar (macOS).
- Dynamic icon: shows active/idle state.
**Quick actions from drop-down menu:**
- Start Session: Choose a project to begin tracking.
- End Session: Finish your session and log notes and mood.
- View Dashboard: Open a clean analytics window.
- Quit: Exit Juju.

### ⏱ Session Tracking
- Precise start/end auto-timestamps for each session.
- Automatic duration calculation.
- Project association for every session.
- Post-session notes: Add context or reflections.
- Mood tracking: Rate your session (0–10) to capture how you felt.
- All data saved as CSV for transparency and portability.

### 📁 Local Storage
- Sessions: ~/Library/Application Support/juju/YYYY-data.csv
- Projects: projects.json in the same folder.
- Activity Types: activityTypes.json in the same folder
- Flat file system: No cloud, no lock-in, no hidden database.

### 📊 Dashboard
**Navigation:**
- **Sidebar**: Permanent sidebar with icons for Charts, Sessions, Projects, and Activity Types
- **Charts Tab** (default): Main analytics dashboard
- **Sessions Tab**: Session management with filtering and export
- **Projects Tab**: Project management interface
- **Activity Types Tab**: Activity type management with emoji picker and archiving
- **Live 'Active Session' Timer**: Shows pill of active project during session with timer

**Charts Tab (Default):**
1. **Hero Section** – "This Week in Juju"
   - **Juju logo** with **dynamic narrative headline**: "This week you logged 13h. Your focus was **Writing** on **Project X**, where you reached a milestone: **'Finished Act I'**."
   - **Left side**: Active Session Status showing current activity type and progress
   - **Right side**: **Weekly Activity Bubble Chart** showing time distribution by activity type (Writing, Editing, Admin, etc.)
   - **Full-width Session Calendar Chart** below showing daily activity with **activity emojis** on session bars

2. **This Year Section**
   - Header: "This Year" with yearly overview
   - Left: Yearly Total Bar Chart showing project time distribution
   - Right: Summary Metrics (Total Hours, Total Sessions, Average Duration)

3. **Weekly Stacked Bar Chart**
   - Vertical Monday -> Sunday chart with colored bars for sessions
   - Shows daily breakdown with project color coding

4. **Stacked Area Chart**
   - Monthly trends visualization showing project time distribution over time
   - Full-width chart for historical analysis

**Sessions Tab:**
- **Current Week Focus**: Default view shows only current week sessions
- **Filter & Export Controls**: Floating panel with:
  - Date Filter: Today, This Week, This Month, This Year, Custom Range, Clear
  - Project Filter: Dropdown to filter by specific projects
  - Export: Dropdown to select format (CSV, TXT, Markdown, PDF)
  - Session Count: Shows number of sessions matching current filters
- **Session Rows**: Display project, duration, start/end times, activity type, phase, notes, mood
- **Inline Actions**: Edit and delete session functionality
  - **Delete Button**: bin icon positioned on right side, triggers confirmation dialog
- **No Pagination**: Simplified view focused on current week with optional filtering
- **Auto-Refresh**: UI automatically updates after session edits, deletes, or data changes

**Projects Tab:**
- **Project List**: Vertical list of all projects
- **Project Cards**: Each showing color swatch, name with emoji, optional description, session count, and last session date, and phase list
- **Add Project**: Button to create new projects
- **Edit/Delete**: Full CRUD operations with modal interface
- **Color Management**: Color picker for project color-coding
- **About Field**: Optional project description
- **Archived Projects Toggle**: Button to show/hide archived projects
- **Session Counting**: Each project displays total number of associated sessions
- **Last Session Date**: Projects show when they were last worked on
- **Project Phases**: Support for project subdivisions with archiving
- **Project Name Changes**: Automatic CSV updates when project names change
- **Data Migration**: Tool to assign project IDs to legacy sessions

**Activity Types Tab:**
- **Activity Types List**: Vertical list of all activity types
- **Activity Type Cards**: Each showing emoji, name, and optional description
- **Add Activity Type**: Button to create new activity types with emoji picker
- **Edit/Delete**: Full CRUD operations with modal interface
- **Archive/Unarchive**: Toggle functionality to hide/show activity types
- **Emoji Picker Integration**: Shared emoji picker with search functionality
- **Protected Fallback**: Uncensored "Uncategorized" type cannot be deleted

---

### Current filetree (Updated):

```
├── Juju/
│   ├── App/
│   │   ├── AppDelegate.swift # Main app lifecycle and setup
│   │   ├── Info.plist
│   │   ├── Juju-entitlements.plist
│   │   ├── Juju.entitlements
│   │   ├── JujuUtils.swift # Utility functions and helpers
│   │   └── main.swift # App entry point
│   ├── Core/
│   │   ├── Managers/
│   │   │   ├── ChartDataPreparer.swift # Processes data for dashboard charts
│   │   │   ├── EditorialEngine.swift # Narrative headline generation engine
│   │   │   ├── IconManager.swift # Manages dynamic menu bar icons
│   │   │   ├── MenuManager.swift # Handles menu bar dropdown functionality
│   │   │   ├── SessionManager.swift # Main session coordinator
│   │   │   ├── ShortcutManager.swift # Keyboard shortcuts for quick actions
│   │   │   ├── SidebarStateManager.swift # Manages sidebar state and navigation
│   │   │   ├── Data/ # Data processing and management
│   │   │   │   ├── SessionDataManager.swift # Session CRUD operations
│   │   │   │   ├── SessionDataParser.swift # CSV parsing and data conversion
│   │   │   │   └── SessionMigrationManager.swift # Handles data migrations
│   │   │   ├── File/ # File system operations
│   │   │   │   └── SessionFileManager.swift # Thread-safe file operations
│   │   │   └── Session/ # Session lifecycle management
│   │   │       └── SessionOperationsManager.swift # Session state management
│   │   ├── Models/
│   │   │   ├── ActivityType.swift # Activity type entity model
│   │   │   ├── ChartModels.swift # Data models for chart components
│   │   │   ├── Project.swift # Project entity model
│   │   │   └── SessionModels.swift # Session data structures
│   │   └── ViewModels/
│   │       └── ProjectsViewModel.swift # Projects data binding and business logic
│   ├── Features/
│   │   ├── ActivityTypes/
│   │   │   ├── ActivityTypeSidebarEditView.swift # Activity type editing interface
│   │   │   ├── ActivityTypesView.swift # Activity type management interface
│   │   │   └── ActivityTypesViewModel.swift # Activity types data binding and business logic
│   │   ├── Dashboard/
│   │   │   ├── DashboardWindowController.swift # Dashboard window management (moved to App/)
│   │   │   ├── SummaryMetricView.swift # Total hours/sessions display
│   │   │   ├── DashboardRootView.swift # Main dashboard SwiftUI view
│   │   │   ├── Shared/ # Shared components used by both weekly and yearly views
│   │   │   │   └── ActiveSessionStatusView.swift # Real-time active session display (always visible)
│   │   │   ├── Weekly/ # Weekly-focused dashboard components
│   │   │   │   ├── WeeklyDashboardView.swift # Main weekly dashboard
│   │   │   │   ├── WeeklyHeroSectionView.swift # "This Week in Juju" summary section
│   │   │   │   ├── WeeklyActivityBubbleChartView.swift # Activity-focused bubble chart
│   │   │   │   └── SessionCalendarChartView.swift # Weekly calendar-style view with activity emojis
│   │   │   └── Yearly/ # Yearly-focused dashboard components
│   │   │       ├── YearlyTotalBarChartView.swift # Yearly total overview chart
│   │   │       ├── WeeklyStackedBarChartView.swift # Monday-Sunday colored bars (52-week distribution)
│   │   │       └── StackedAreaChartCardView.swift # Yearly overview area chart
│   │   ├── Notes/
│   │   │   ├── NotesManager.swift # Session notes persistence
│   │   │   ├── NotesModalView.swift # Notes input/editing interface
│   │   │   └── NotesViewModel.swift # Notes data binding and validation
│   │   ├── Projects/
│   │   │   ├── ProjectSidebarEditView.swift # Project editing interface
│   │   │   └── ProjectsNativeView.swift # Project management interface
│   │   ├── Sessions/
│   │   │   ├── Components/
│   │   │   │   ├── FilterExportControls.swift # Modular filter and export controls
│   │   │   │   ├── InlineSelectionPopover.swift # Inline Session Editability
│   │   │   ├── SessionsRowView.swift # Individual session row display with expanded notes and actions
│   │   │   └── SessionsView.swift # Sessions list with integrated day headers and total duration display
│   │   └── Sidebar/
│   │       ├── SidebarEditView.swift # Sidebar editing interface
│   │       └── SidebarView.swift # Dashboard navigation sidebar
│   ├── Resources/
│   │   └── Assets etc
│   └── Shared/
│       ├── Extensions/
│       │   ├── ButtonTheme.swift # Button styling and theme configuration
│       │   ├── EmojiColorPickerView.swift # Emoji and Color Picker views
│       │   └── NSColor+SwiftUI.swift # Color extensions for SwiftUI
│       ├── Preview/
│       │   └── SimplePreviewHelpers.swift # Preview helpers for SwiftUI
│       ├── Theme.swift # Global app theme and styling
│       └── TooltipView.swift # Custom tooltip component
├── Juju.xcodeproj/
│   ├── project.pbxproj # Xcode project configuration
│   ├── project.xcworkspace/ # Workspace configuration
│   ├── xcshareddata/
│   │   └── xcschemes/ # Build schemes
│   └── xcuserdata/ # User-specific settings
├── README.md
├── prompt.md
└── icons/ # App icon assets
    ├── AppIcon1024.png
    ├── juju_logo.png
    ├── status_active.pdf
    └── status_idle.pdf
```
