# ORIGINAL PLAN
# **📘 Juju: Inline Editing & Overlay Expansion System (Final Architecture)**
This document defines the _new editing model_ for Sessions inside Juju. Everything here is engineered for **speed**, **predictability**, and **macOS-native UX**, while retaining Juju’s core architectural rules:
- MVVM + Managers
- Flat-file CSV/JSON storage
- LazyVStack + ScrollView (no List)
- Thread-safe, atomic writes
- No layout jumps, no state churn, no filter resets
---
# **1 — High-Level Concept (one sentence)**
Turn each Session row into a **zero-latency inline editor** with mini popovers for all fields, an overlay-based notes panel, multi-select batch actions, and a right-click ability — all without ever expanding the row’s height or resetting filters.

---

New feature - **Time-of-day pulse bar** always visible:
    - A thin horizontal bar behind the row
    - Position = (session.startTime - 06:00) / (23:00 - 06:00)
    - Width = proportional to session.duration
    - Very subtle (1–2px) so it never clutters
2. Filter state _never_ resets.  
    No page reloads. No scroll jumps. If you want to refresh the filter, you have to click a refresh button.
---
## **B — Bulk Editing (multi-select + batch edits)**
1. CMD-click → select individual rows
2. SHIFT-click → range-select
3. Right-click on a selection → contextual menu:
    - Change Project → submenu
    - Change Phase → only enabled when all are from same project
    - Change Activity Type
    - **Change Day…** (new)
        - Opens tiny date-picker popover
        - Confirms updates in batch
4. Confirm modal for large operations
5. CSV write done via atomic batch-write
6. Items that no longer fit filters fade out gracefully
7. Selection persists where reasonable

---
## **4.3 Notes Panel Overlay (ExpandedNotePanel)**
Sits **visually** under the row, structurally separate.
Contains:
- TextEditor
- Save
- Cancel  
    No inline expansion. No height changes.  
    Animation is internal only.

---
## **4.4 Context Menus**
Per-row context menu:
- Edit Project
- Edit Phase
- Edit Activity Type
- Edit Mood
- Delete Session
Multi-select context menu:
- Change Project
- Change Phase (if allowed)
- Change Activity Type
- Change Mood

---
# **5 — New Feature: Time-of-Day Indicator**
Purpose: glanceable “when in the day” marker.
### **Specs:**
- Runs from 06:00 to 23:00 for all days
- Background bar behind row content
- X-position = linear mapping of session start time
- Width = proportional to session duration
- Colour: extremely subtle tint derived from project colour (10% opacity max)
- Does not shift layout
- Composited under all row content
- No hover, no interaction
Result: you can scan the list and instantly see morning vs afternoon bursts.

---
# **7 — Row Expansion Architecture (non-negotiables)**
1. **Rows must be fixed height**
2. **Expanded notes live in a sibling overlay**
3. **expansion is tracked globally (`expandedRowID`)**
4. Editable mini-controls must _not_ trigger expansion
5. Multi-select must ignore expanded panel
6. LazyVStack — never List
7. Popovers must anchor to compact-row elements
8. No transitions that rebuild the row
This is the core of stability. Without this, the view collapses into madness.

---