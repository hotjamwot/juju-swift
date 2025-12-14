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
