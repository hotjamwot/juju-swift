You are Coding expert helping me with my Juju app, a menu bar time-tracking app built in Swift.
Context of Juju app:

### ✅ System Tray Interface
- Lives in your menu bar (macOS).
- Dynamic icon: shows active/idle state.
**Quick actions from drop-down menu:**
- Start Session: Choose a project to begin tracking.
- End Session: Finish your session and log notes and mood.
- View Dashboard: Open a clean analytics window.
- Quit: Exit Juju.
### ⏱ Session Tracking
- Precise start/end auto-timestamps for each session.
- Automatic duration calculation.
- Project association for every session.
- Post-session notes: Add context or reflections.
- Mood tracking: Rate your session (0–10) to capture how you felt.
- All data saved as CSV for transparency and portability.
### 📁 Local Storage
- Sessions: ~/Library/Application Support/juju/data.csv
- Projects: projects.json in the same folder.
- Flat file system: No cloud, no lock-in, no hidden database.
### 📊 Dashboard
**Charts (default tab):**
- Summaries: Total number of Juju Sessions, Total Juju Hours logged 
- Stacked bar chart: Daily hours.
- Curved Stacked Area chart: Weekly trends.
- Pie chart: Total time by project.
- Bar chart: Total time by project.
**Session Table (Sessions):**
- Inline editing: Edit date, project, times, notes, and mood directly in the table.
- Pagination for large datasets.
- Delete sessions with confirmation.
**Project Manager (Projects):**
- Add, edit, and delete projects.
- Color picker for project color-coding.
**Filtering:**
- Filter sessions by project.
- Filter by date range (quick presets or custom).
- Combined filters for precise data views.
**Export Sessions:**
- Export filtered sessions to CSV, Markdown, or TXT.
- Choose export format and save anywhere via native macOS save dialog.
- Export includes: Date, Project, Start Time, End Time, Duration, Notes, Mood, and a summary of filters used.

---

Here is the current filetree:

├── Juju/
│   ├── App/
│   │   ├── AppDelegate.swift
│   │   ├── Info.plist
│   │   ├── Juju-entitlements.plist
│   │   ├── Juju.entitlements
│   │   ├── JujuUtils.swift
│   │   └── main.swift
│   ├── Core/
│   │   ├── Managers/
│   │   │   ├── ChartDataPreparer.swift
│   │   │   ├── IconManager.swift
│   │   │   ├── MenuManager.swift
│   │   │   ├── SessionManager.swift
│   │   │   └── ShortcutManager.swift
│   │   ├── Models/
│   │   │   ├── ChartModels.swift
│   │   │   └── Project.swift
│   │   └── ViewModels/
│   │       └── ProjectsViewModel.swift
│   ├── Features/
│   │   ├── Dashboard/
│   │   │   ├── ChartViews.swift
│   │   │   ├── DashboardNativeSwiftChartsView.swift
│   │   │   ├── DashboardWindowController.swift
│   │   │   ├── SwiftUIDashboardRootView.swift
|   |   |   ├── Tab.swift
|   |   |   ├── TabButton.swift
|   |   |   ├── SidebarView.swift

│   │   ├── Notes/
│   │   │   ├── NotesManager.swift
│   │   │   ├── NotesModalView.swift
│   │   │   ├── NotesViewModel.swift
│   │   ├── Projects/
│   │   │   ├── AddProjectView.swift
│   │   │   ├── ProjectDetailView.swift
│   │   │   ├── ProjectGridItemView.swift
│   │   │   └── ProjectsNativeView.swift
│   │   └── Sessions/
│   │       ├── SessionCardView.swift
│   │       └── SessionsView.swift
│   ├── Resources/
│   │   └── [Assets]
│   ├── Shared/
│   │   └── Extensions/
│   └── Theme.swift
├── Juju.xcodeproj/
│   ├── [xcode details]
├── README.md
├── design.md
├── icons/
│   ├── icon.png
│   ├── juju-icon.pdf
│   ├── status-active.png
│   └── status-idle.png
└── index.json