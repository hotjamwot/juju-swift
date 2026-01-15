Juju is a lightweight, always-on macOS menu bar app for tracking focused deep work sessions by project.

It runs quietly in the background, giving you instant access to start and end sessions, log notes (and mood), and visualise your time in a clean, beautiful, privacy-first dashboard.
But Juju is not just about productivity.

At its core, Juju exists to make sure your work (and the life wrapped around it) doesn’t blur into nothing.

It’s a tool for remembering. For marking chapters. For proving to yourself that the effort happened, that the struggle counted, and that the time you gave to your projects actually existed.
Juju is for people who want clarity over their time without bloat, cloud lock-in, or constant notifications. It’s elegant, fast, and 100% local.

---

## ⚙️ Features
### ✅ System Tray Interface
* Lives in your menu bar (macOS).
* Dynamic icon: shows active/idle state at a glance.

**Quick actions from the drop-down menu:**
* Start Session: Choose a project to begin tracking.
* End Session: Finish your session and log notes and mood.
* View Dashboard: Open a clean analytics window.
* Quit: Exit Juju.

Designed to be always there when you need it and invisible when you don’t.

---

### ⏱ Session Tracking
Every session is a small act of authorship.
* Precise start/end auto-timestamps for each session.
* Automatic duration calculation.
* Project association for every session.
* Post-session notes to capture context, friction, or small wins.
* Mood tracking (0–10) to record how the work *felt*, not just how long it took.
* PhaseID and Activity Type dropdowns on session end to demarcate chapters within projects.
* All data saved as CSV for transparency, portability, and longevity.

---

### 📁 Local Storage
Your work stays with you.
* Sessions: `~/Library/Application Support/juju/YYYY-data.csv`
* Projects: `projects.json` in the same folder.
* Activity Types: `activityTypes.json` in the same folder.

Flat file system. No cloud. No accounts. No hidden databases.
If Juju vanished tomorrow, your life’s work would still be there.

---

### 📊 Dashboard
The dashboard exists to help you *reckon* with your time but never to gamify it.
**Charts (default tab):**
#### 1. Weekly Dashboard
* Hero section – *This Week in Juju*
* Summary metrics:
  * You’ve spent {time} in Juju this week
  * Dominant Activity Types
  * Milestones reached
* Bubble chart grouped by Activity Type
* Vertical Monday → Sunday chart with coloured session bars

This view answers one simple question:
*What actually happened this week?*

---

#### 2. Yearly Dashboard
* Activity Type horizontal grouped bar chart per month
* Project total time horizontal bar chart
* Activity Type total horizontal bar chart

This is where patterns emerge — momentum, drift, obsession, avoidance.

---

**Session Table (Sessions):**
* Inline editing: Edit date, project, times, notes, and mood directly in the table.
* Pagination for large datasets.
* Delete sessions with confirmation.
**Project Manager (Projects):**
* Add, edit, archive, and delete projects.
* Colour picker and emoji picker for quick visual identity.
**Activity Type Manager:**
* Add, edit, archive Activity Types.
* Emoji picker and editable descriptions.
**Filtering:**
* Filter sessions by project.
* Filter by Activity Type.
* Filter by date range (quick presets or custom).
* Combine filters for precise views of specific chapters in your life.
> **Export Sessions (deprecated):**
>
> * Export filtered sessions to CSV, Markdown, or TXT.
> * Choose export format and save anywhere via native macOS save dialog.
> * Export includes Date, Project, Start Time, End Time, Duration, Notes, Mood, and filter summary.

---

### 🔑 Global Shortcut
* Press ⇧⌥⌘J from anywhere to quickly launch Juju.
Because friction kills memory.

---

## 🛡️ Philosophy
Juju is built on a small set of non-negotiable principles:
* **Privacy-first**: All data stays on your device.
* **Transparency**: Plain text files you can inspect, analyse, or repurpose.
* **No bloat**: No cloud, no accounts, no ads, no tracking.
* **Fast and elegant**: Minimal friction, maximum clarity.

And one guiding rule above all else:
> **Nothing in Juju exists unless it helps future-you remember or reckon.**

---

## 📝 Data Format
* Sessions: CSV with columns:
  * `id, startDate, endDate, project, activityType, notes, mood, milestone, phaseID`
* Projects: JSON array with project names and colour IDs.

Open by design. Durable by intent.

---

## 💡 Why Juju?
Juju is for makers, freelancers, and creative professionals who don’t just want to be productive, they want their time to *mean something* when they look back.
It’s for people who care about the journey as much as the outcome.
For anyone who wants to look back and say:
> *I was here. I tried. I made things. And this chapter mattered.*
