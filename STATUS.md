# 🧭 Folder Overview

App/

Everything that bootstraps Juju — app lifecycle, global config, entry point, and app-wide utilities.
Think of this as the “engine room”: nothing in here should know about your features directly, it just runs the show.

Core/

This is the brains of Juju. Business logic, data models, and app-wide managers live here.
No UI code. These are the pieces that power your features.
	•	Models/ → Your data types and structs (Project, ChartData, etc.)
	•	ViewModels/ → Bind UI to data (state, logic, filtering, etc.)
	•	Managers/ → Services that coordinate or manage subsystems (sessions, menus, shortcuts).

Features/

This is where your actual app sections live — one folder per tab or major feature.
Each has its own SwiftUI views, controllers, and eventually its own logic.
This is where the user-facing magic happens.

Resources/

Your assets, icons, and other bundle resources.
As Juju grows, you might add Localisations, Fonts, or Sounds here too.

Shared/

Generic helpers, extensions, and reusable components — basically, your “common” layer.
Great spot for small cross-cutting code that doesn’t belong to any feature.

⸻

# 🧩 File Breakdown (What They Actually Do)

App/

File	Responsibility
AppDelegate.swift	Handles app lifecycle, menus, windows, launch setup.
main.swift	Entry point for the macOS app, kicks off the SwiftUI/AppKit app delegate.
Info.plist	App metadata and configuration (bundle ID, permissions, etc.).
Juju-entitlements.plist	Sandbox entitlements (file access, automation, etc.).
JujuUtils.swift	General utility functions — could later be split into logical groups.


⸻

Core/

Models/

File	Responsibility
Project.swift	Defines the data model for projects (name, sessions, etc.).
ChartModels.swift	Data types for charts (sessions over time, activity per project, etc.).

ViewModels/

File	Responsibility
ProjectsViewModel.swift	Manages project list state, CRUD operations, filtering, etc.

Managers/

File	Responsibility
SessionManager.swift	Handles logging, saving, and retrieving deep work sessions.
MenuManager.swift	Builds and updates the macOS status bar or app menu.
ShortcutManager.swift	Registers and listens for global keyboard shortcuts.
IconManager.swift	Loads and manages icons (active/idle/etc.) dynamically.
ChartDataPreparer.swift	Transforms raw session/project data into chart-friendly data sets.


⸻

Features/

Dashboard/

File	Responsibility
DashboardNativeSwiftChartsView.swift	Displays your Swift Charts, connected to ChartDataPreparer.
SwiftUIDashboardRootView.swift	The main SwiftUI dashboard container (tabs, layout, etc.).
DashboardWebViewController.swift	Legacy WebView dashboard controller (for old HTML dashboard).
DashboardWindowController.swift	Manages the dashboard window lifecycle (open/close, focus).
WebDashboardView.swift	SwiftUI wrapper for the web-based dashboard content.
dashboard-web/	Old HTML/JS dashboard — soon to be deprecated once fully native.

Projects/

File	Responsibility
ProjectsNativeView.swift	SwiftUI list/grid of projects.
ProjectGridItemView.swift	Individual project tile/card.
ProjectDetailView.swift	Detail page for a selected project.
AddProjectView.swift	Form for creating a new project.

Sessions/

File	Responsibility
SessionsView.swift	Displays all recorded sessions.
SessionCardView.swift	Shows one session’s summary (duration, notes, etc.).
EditSessionView.swift	Form for editing an existing session.

Notes/

File	Responsibility
NotesModalViewController.swift	Currently an NSWindow pop-up; you’ll convert it to a native SwiftUI sheet/modal.


⸻

Resources/

File	Responsibility
Assets.xcassets	Your app icons, accent colours, and image sets.


⸻

Shared/

File	Responsibility
Extensions/	For Swift or SwiftUI extensions (e.g. .asDate(), .cornerRadius(), etc.).


⸻

# 🗺️ Roadmap (Practical, Chunked Plan)

Phase 1 – Data Integrity & Charts (Now)
	•	✅ Verify the Juju tab reads data correctly (hook up real data to charts).
	•	🔧 Fix date pickers not selecting properly.
	•	🎨 Improve chart visuals: consistent colours, fonts, scaling, tooltips.

Goal: Charts show real, accurate data with clean SwiftUI bindings.

⸻

Phase 2 – Functional Testing
	•	Go through every tab: Projects, Sessions, Dashboard, Notes.
	•	Test creating, editing, and deleting projects/sessions.
	•	Ensure session data persists correctly through SessionManager.
	•	Validate menu shortcuts, icon state updates.

Goal: Everything works end-to-end without regressions.

⸻

Phase 3 – Notes Modal Migration
	•	Replace NotesModalViewController (NSWindow) with SwiftUI Sheet or Popover.
	•	Use @Environment(\.dismiss) for closing logic.
	•	Integrate with SessionManager for saving notes.

Goal: Fully native, SwiftUI-friendly modal system.

⸻

Phase 4 – UI Polish
	•	Add consistent design language: typography, spacing, iconography.
	•	Introduce small reusable components (buttons, cards, etc.) under /Shared/Components/.
	•	Simplify the dashboard layout — native charts, no web leftovers.

Goal: Cohesive, fully native SwiftUI look and feel.

⸻

Phase 5 – Technical Cleanup
	•	Remove dashboard-web/ once obsolete.
	•	Split JujuUtils.swift into smaller files (e.g. DateUtils.swift, AppEnvironment.swift).
	•	Create Tests/ and start adding a few simple unit tests for Managers.
