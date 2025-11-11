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
- Sessions: ~/Library/Application Support/juju/data.csv
- Projects: projects.json in the same folder.
- Flat file system: No cloud, no lock-in, no hidden database.
### 📊 Dashboard
**Charts (default tab):**
1. 🪩 Hero Section – "This Week in Juju"
- **Headline Text:** "You've spent {time} in the Juju this week!"
- This Week Bubble Chart:
- Summary Stats (right side): Total Hours (all-time), **Total Sessions (all-time)
2. A vertical Monday -> Sunday chart with coloured bars for sessions
3. Full-width Bubble Chart for Yearly Overview
4. Grouped Bar Chart for Monthly Trends
**Session Table (Sessions):**
- Inline editing: Edit date, project, times, notes, and mood directly in the table.
- Pagination for large datasets.
- Delete sessions with confirmation.
**Project Manager (Projects):**
- Add, edit, and delete projects.
- Color picker for project color-coding.
**Filtering:**
- Filter sessions by project.
- Filter by date range (quick presets or custom).
- Combined filters for precise data views.
**Export Sessions:**
- Export filtered sessions to CSV, Markdown, or TXT.
- Choose export format and save anywhere via native macOS save dialog.
- Export includes: Date, Project, Start Time, End Time, Duration, Notes, Mood, and a summary of filters used.

---

### Current filetree:

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
│   │   │   ├── SessionManager.swift # Core session tracking and data management
│   │   │   └── ShortcutManager.swift # Keyboard shortcuts for quick actions
│   │   ├── Models/
│   │   │   ├── ChartModels.swift # Data models for chart components
│   │   │   └── Project.swift # Project entity model
│   │   └── ViewModels/
│   │       └── ProjectsViewModel.swift # Projects data binding and business logic
│   ├── Features/
│   │   ├── Dashboard/
│   │   │   ├── BubbleChartCardView.swift # Circular bubble chart for time visualization
│   │   │   ├── DashboardNativeSwiftChartsView.swift # Main dashboard container
│   │   │   ├── DashboardWindowController.swift # Dashboard window management
│   │   │   ├── GroupedBarChartCardView.swift # Monthly trends bar chart
│   │   │   ├── HeroSectionView.swift # "This Week in Juju" summary section
│   │   │   ├── SessionCalendarChartView.swift # Weekly calendar-style view
│   │   │   ├── SidebarView.swift # Dashboard navigation sidebar
│   │   │   ├── SummaryMetricView.swift # Total hours/sessions display
│   │   │   ├── SwiftUIDashboardRootView.swift # Main dashboard SwiftUI view
│   │   │   ├── StackedAreaChartCardView.swift # Yearly overview area chart
│   │   │   ├── WeeklyProjectBubbleChartView.swift # Weekly project breakdown
│   │   │   ├── WeeklyStackedBarChartView.swift # Monday-Sunday colored bars
│   │   │   └── YearlyTotalBarChartView.swift # Yearly total overview chart
│   │   ├── Notes/
│   │   │   ├── NotesManager.swift # Session notes persistence
│   │   │   ├── NotesModalView.swift # Notes input/editing interface
│   │   │   └── NotesViewModel.swift # Notes data binding and validation
│   │   ├── Projects/
│   │   │   ├── ProjectAddEditView.swift # Create/edit project modal
│   │   │   └── ProjectsNativeView.swift # Project management interface
│   │   └── Sessions/
│   │       ├── Components/
│   │       │   ├── SessionEditOptions.swift # Inline session editing controls
│   │       │   └── SessionViewOptions.swift # Session display options
│   │       ├── SessionCardView.swift # Individual session display component
│   │       └── SessionsView.swift # Sessions list and management interface
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

**Example structure:**```
- [ ] Analyze requirements
- [ ] Set up necessary files
- [ ] Implement main functionality
- [ ] Handle edge cases
- [ ] Test the implementation
- [ ] Verify results```

Keeping the todo list updated helps track progress and ensures nothing is missed.
