You are Coding expert helping me with my Juju app, a menu bar time-tracking app built in Swift.
Context of Juju app:

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
- **Grouped Grid View**: Sessions organized by date (Monday, 23rd October, etc.)
- **4-Column Layout**: Each session displayed as a card
- **Current Week Focus**: Default view shows only current week sessions
- **Filter & Export Controls**: Floating panel with:
  - Date Filter: Today, This Week, This Month, This Year, Custom Range, Clear
  - Project Filter: Dropdown to filter by specific projects
  - Export: Dropdown to select format (CSV, TXT, Markdown, PDF)
  - Session Count: Shows number of sessions matching current filters
- **Session Cards**: Display project, duration, start/end times, mood
- **Inline Actions**: Edit and delete session functionality
- **No Pagination**: Simplified view focused on current week with optional filtering

**Projects Tab:**
- **Project List**: Vertical list of all projects
- **Project Cards**: Each showing color swatch, name with emoji, and optional description
- **Add Project**: Button to create new projects
- **Edit/Delete**: Full CRUD operations with modal interface
- **Color Management**: Color picker for project color-coding
- **About Field**: Optional project description

**Activity Types Tab:**
- **Activity Types List**: Vertical list of all activity types
- **Activity Type Cards**: Each showing emoji, name, and optional description
- **Add Activity Type**: Button to create new activity types with emoji picker
- **Edit/Delete**: Full CRUD operations with modal interface
- **Archive/Unarchive**: Toggle functionality to hide/show activity types
- **Emoji Picker Integration**: Shared emoji picker with search functionality
- **Protected Fallback**: Uncensored "Uncategorized" type cannot be deleted

**Filtering & Export System:**
- **Date Filtering**: Real-time filtering with options for Today, This Week, This Month, This Year, Custom Range, and Clear
- **Project Filtering**: Dropdown to filter sessions by specific projects
- **Export Functionality**: Export filtered sessions to CSV, Markdown, TXT, or PDF
- **Session Count Display**: Shows number of sessions matching current filters
- **Floating Controls**: Filter panel can be expanded/collapsed as needed

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
│   │   │   ├── IconManager.swift # Manages dynamic menu bar icons
│   │   │   ├── MenuManager.swift # Handles menu bar dropdown functionality
│   │   │   ├── SessionManager.swift # Main session coordinator (refactored)
│   │   │   ├── ShortcutManager.swift # Keyboard shortcuts for quick actions
│   │   │   ├── File/ # File system operations
│   │   │   │   └── SessionFileManager.swift # Thread-safe file operations
│   │   │   ├── Data/ # Data processing and management
│   │   │   │   ├── SessionDataParser.swift # CSV parsing and data conversion
│   │   │   │   └── SessionDataManager.swift # Session CRUD operations
│   │   │   └── Session/ # Session lifecycle management
│   │   │       └── SessionOperationsManager.swift # Session state management
│   │   ├── Models/
│   │   │   ├── ChartModels.swift # Data models for chart components
│   │   │   ├── Project.swift # Project entity model
│   │   │   └── SessionModels.swift # Session data structures
│   │   └── ViewModels/
│   │       └── ProjectsViewModel.swift # Projects data binding and business logic
│   ├── Features/
│   │   ├── Dashboard/
│   │   │   ├── ActiveSessionStatusView.swift # Real-time active session display
│   │   │   ├── BubbleChartCardView.swift # Circular bubble chart for time visualization
│   │   │   ├── DashboardNativeSwiftChartsView.swift # Main dashboard container
│   │   │   ├── DashboardWindowController.swift # Dashboard window management
│   │   │   ├── EditorialEngine.swift # Narrative headline generation engine
│   │   │   ├── GroupedBarChartCardView.swift # Monthly trends bar chart
│   │   │   ├── HeroSectionView.swift # "This Week in Juju" summary section (TRANSFORMED)
│   │   │   ├── SessionCalendarChartView.swift # Weekly calendar-style view (ENHANCED with activity emojis)
│   │   │   ├── SidebarView.swift # Dashboard navigation sidebar
│   │   │   ├── SummaryMetricView.swift # Total hours/sessions display
│   │   │   ├── StackedAreaChartCardView.swift # Yearly overview area chart
│   │   │   ├── SwiftUIDashboardRootView.swift # Main dashboard SwiftUI view
│   │   │   ├── WeeklyActivityBubbleChartView.swift # Activity-focused bubble chart
│   │   │   ├── WeeklyStackedBarChartView.swift # Monday-Sunday colored bars
│   │   │   └── YearlyTotalBarChartView.swift # Yearly total overview chart
│   │   ├── Notes/
│   │   │   ├── NotesManager.swift # Session notes persistence
│   │   │   ├── NotesModalView.swift # Notes input/editing interface
│   │   │   └── NotesViewModel.swift # Notes data binding and validation
│   │   ├── Projects/
│   │   │   ├── ProjectAddEditView.swift # Create/edit project modal
│   │   │   └── ProjectsNativeView.swift # Project management interface
│   │   ├── ActivityTypes/
│   │   │   ├── ActivityTypeAddEditView.swift # Create/edit activity type modal
│   │   │   ├── ActivityTypesView.swift # Activity type management interface
│   │   │   └── ActivityTypesViewModel.swift # Activity types data binding and business logic
│   │   └── Sessions/
│   │       ├── Components/
│   │       │   ├── FilterExportControls.swift # NEW: Modular filter and export controls
│   │       │   └── SessionViewOptions.swift # Session display options
│   │       ├── SessionCardView.swift # Individual session display component
│   │       ├── SessionEditModalView.swift # Modal session editing interface
│   │       └── SessionsView.swift # Sessions list with enhanced filter integration
│   ├── Resources/
│   │   └── Assets.xcassets/ etc
│   └── Shared/
│       ├── Extensions/
│       │   ├── ButtonTheme.swift # Button styling and theme configuration
│       │   └── NSColor+SwiftUI.swift # Color extensions for SwiftUI
│       ├── Theme.swift # Global app theme and styling
│       └── TooltipView.swift # Custom tooltip component
├── Juju.xcodeproj/
│   ├── project.pbxproj etc
├── README.md
├── design.md
├── icons/
│   ├── icon.png
│   ├── juju-icon.pdf
│   ├── status-active.png
│   └── status-idle.png
├── index.json
└── prompt.md
```


# TODO LIST RECOMMENDED

When starting a new task, it is recommended to create a todo list.

1. Include the task_progress parameter in your next tool call
2. Create a comprehensive checklist of all steps needed
3. Use markdown format: - [ ] for incomplete, - [x] for complete

**Benefits of creating a todo list now:**
	- Clear roadmap for implementation
	- Progress tracking throughout the task
	- Nothing gets forgotten or missed
	- Users can see, monitor, and edit the plan

**Example structure:**
```
- [ ] Analyze requirements
- [ ] Set up necessary files
- [ ] Implement main functionality
- [ ] Handle edge cases
- [ ] Test the implementation
- [ ] Verify results
```

Keeping the todo list updated helps track progress and ensures nothing is missed.
