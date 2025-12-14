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
- Floating navigation buttons for switching between Weekly and Yearly views
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
