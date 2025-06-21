Juju is a lightweight, always-on system tray application designed to help you track focused deep work sessions by project. It runs quietly in the background and gives you quick access to start/end a work session, log notes, and later visualise your progress in a slick dashboard.

It's for people who want clarity over their time, without bloat or constant notifications — something elegant, fast, and local.

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

## 🗺️ Development Roadmap

### ✅ Phase 1: Swift Backend Core - COMPLETE
- ✅ Project Setup (Xcode project, Application Support directory)
- ✅ Session Tracking (Session struct, start/end, CSV save/load)
- ✅ Project Management (Project struct, JSON load/save)
- ✅ File/Directory Setup (auto-create directories)
- ✅ Global App State (SessionManager singleton)

### ✅ Phase 2: Native Menu Bar - COMPLETE
- ✅ Menu Bar Setup (NSStatusItem, custom icons, dynamic updates)
- ✅ Menu Bar Integration (hidden dock, primary interface)
- ✅ Window management (dashboard show/hide)

### 🔄 Phase 3: WebView Dashboard - IN PROGRESS
- ✅ WebView Setup (using WKWebView)
- ✅ UI Shell (Using HTML/CSS/JavaScript)
- ✅ Charts (implemented, with comparison logic and Chart.js)
- ✅ Session Table (data loads and displays, editable)
- ✅ Filters (basic filter UI present)
- ✅ Project Editor (UI and data load, editing works)
- ❌ Project Deletion (UI present, but not functional yet)
- ⚠️ Session Editing/Deletion (editing works, deletion UI present but not functional due to WKWebView bridge issue; manual CSV edit is a workaround)

### ✅ Phase 4: JavaScript Bridge - COMPLETE
- ✅ JavaScript Interface (NEW: Robust bridge with fallback mechanisms)
- ✅ Event System (NEW: Comprehensive event system for live updates and error handling)

### 🔄 Phase 5: Dev & Testing - IN PROGRESS
- ✅ Basic Testing (NEW: Event system test page created)
- ❌ Build Config
- ❌ Comprehensive Test Suite
- ❌ Integration Testing

### ⏳ Phase 6: Polish & Packaging - NOT STARTED
- ✅ UI/UX Polish (NEW: Modern modals, notifications, enhanced buttons)
- ✅ Accessibility (NEW: Keyboard navigation, ARIA labels)
- ✅ Animations (NEW: Smooth transitions and loading states)
- ❌ Build Targets (release packaging, notarization, etc.)
- ❌ Performance Optimization
- ❌ Final UI Polish

## ⚠️ Known Issues

### WKWebView Clipboard Limitations
The notes modal uses WKWebView for the interface, which has known limitations with clipboard operations in macOS apps:

- **Right-click paste works** ✅
- **Cmd+V paste does not work** ❌
- **Voice input tools (VoiceInk) do not work** ❌
- **Cmd+C copy does not work** ❌
- **Cmd+A select all works** ✅

This is a platform limitation of WKWebView's security model, not a bug in our implementation. Users can still:
- Use right-click context menu for copy/paste
- Type notes manually
- Use the fallback NSTextView if needed

**Potential solutions for future versions:**
- Replace WKWebView with native NSTextView for full clipboard support
- Implement hybrid approach with native text input overlay
- Add user-friendly UI hints about clipboard limitations