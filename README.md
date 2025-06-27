Juju is a lightweight, always-on macOS menu bar app for tracking focused deep work sessions by project. It runs quietly in the background, giving you instant access to start/end sessions, log notes (and mood!), and visualise your progress in a beautiful, privacy-first dashboard.

Juju is for people who want clarity over their time—without bloat, cloud lock-in, or constant notifications. It’s elegant, fast, and 100% local.

---
## ⚙️ Features
### ✅ System Tray Interface
- Lives in your menu bar (macOS).
- Dynamic icon: shows active/idle state.
**Quick actions:**
- Start Session: Choose a project to begin tracking.
- End Session: Finish your session and log notes and mood.
- View Dashboard: Open a clean analytics window.
- Quit: Exit Juju.
### ⏱ Session Tracking
- Precise start/end timestamps for each session.
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
**Visual analytics:**
- Bar chart: Daily hours.
- Line chart: Weekly trends.
- Pie chart: Total time by project.
- Bar chart: Total time by project.
**Session Table:**
- Inline editing: Edit date, project, times, notes, and mood directly in the table.
- Mood editing: Update your mood for any session with a simple dropdown.
- Pagination for large datasets.
- Delete sessions with confirmation.
**Project Manager:**
- Add, edit, and delete projects.
- Color picker for project color-coding.
**Powerful Filtering:**
- Filter sessions by project.
- Filter by date range (quick presets or custom).
- Combined filters for precise data views.
**Export Sessions:**
- Export filtered sessions to CSV, Markdown, or TXT.
- Choose export format and save anywhere via native macOS save dialog.
- Export includes: Date, Project, Start Time, End Time, Duration, Notes, Mood, and a summary of filters used.
### 🔑 Global Shortcut
- Press ⇧⌥⌘J from anywhere to quickly launch the app.

---
## 🛡️ Philosophy
- Privacy-first: All data stays on your device.
- Transparency: Data is stored in plain text files you can inspect or analyze.
- No bloat: No cloud, no accounts, no ads, no tracking.
- Fast and elegant: Designed for minimal friction and maximum clarity.

---
## 🚀 Getting Started
1. Download and run Juju (macOS only for now).
2. Start tracking: Use the menu bar icon to start/end sessions.
3. Open the dashboard to view, filter, edit, and export your data.

---
## 📝 Data Format
- Sessions: CSV with columns: id, date, start_time, end_time, duration_minutes, project, notes, mood
- Projects: JSON array with project names and colors.

---
## 💡 Why Juju?
Juju is for makers, freelancers, and anyone who wants to understand and improve their deep work habits—without giving up privacy or control.