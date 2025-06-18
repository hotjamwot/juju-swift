Juju is a lightweight, always-on system tray application designed to help you track focused deep work sessions by project. It runs quietly in the background and gives you quick access to start/end a work session, log notes, and later visualise your progress in a slick dashboard.

It’s for people who want clarity over their time, without bloat or constant notifications — something elegant, fast, and local.

## ⚙️ What It Does

### ✅ System Tray Interface
- Lives in the system tray (macOS for now).
- Dynamic icon state: idle vs. active session.
- Tray menu options:
    - Start Session → choose project
    - End Session → enter optional note
    - View Dashboard → opens a clean analytics window
    - Quit

### ⏱ Session Tracking
- Start/end timestamps recorded with project info.
- Duration calculated automatically.
- Notes added post-session.
- Data saved as simple CSV (for transparency and portability).

### 📁 Local Storage
- Sessions: stored in `~/Library/Application Support/juju/data.csv`
- Projects: `projects.json` in the same folder
- Flat file system: no cloud, no lock-in.

### 📊 Dashboard
- Visual breakdowns of your time:
    - Bar (daily hours)
    - Line (weekly)
    - Pie (total time by project)
    - Comparisons (e.g. today vs last week)
- Inline-editable session list with pagination.
- Project manager with colour picker and delete functionality.
- Filters by project or date range.

### 🔑 Global Shortcut
- Press ⇧⌥⌘J from anywhere to quickly launch the app.