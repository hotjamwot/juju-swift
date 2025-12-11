# THE GOAL
We're going to start a fun refactor of how our session editing works. The goal is to get rid of the edit sidebar for all of session editableness, and instead, we will be making an inline version of editing.


# ⭐️ **PHASE 1 — The Immutable Row Shell**
**Goal:** A stable fixed-height row with perfect layout, no behaviour.
### Build:
- Fixed row height
- All UI elements in place (capsules, note preview, star, etc.)
- No buttons
- No hover effects
- No popovers
- No overlays
- No gestures
**Why this matters:**  
If the layout is wrong later, everything breaks.  
Lock the aesthetics before touching state.

---
# ⭐️ **PHASE 2 — Add Hover Delete Button (Low-Risk Interaction)**
Keep it stupidly simple.
### Build:
- On hover → a delete icon fades in at the far right
- On click → `SessionStore.delete(session)`
- Must NOT refresh the whole list
- Must NOT reset filters
- Must NOT collapse any overlays
**Why this is early:**  
It’s isolated.  
It tests your “row refreshes but list stays stable” model in a safe way.

---

### 👉 PHASE 2.5 — Fix the Filter Refresh Model 
**Actions in PHASE 2.5:**
- Replace your “refresh all filters” call with a smarter one:
    - update the edited session in-place
    - do **not** re-run the global filtering pipeline
    - do **not** rebuild `filteredSessions` unless the edit _logically_ changes whether the session should appear
- Add a sanity check:  
    If a session’s data change moves it _outside_ the filter criteria (e.g., date edit moves it out of current week), don't even refresh the filter then. We will add a 'refresh' button to the filter popup later.

---
# ⭐️ **PHASE 3 — Add the Notes Overlay (Your Big Win)**
This is the most important interaction model, so treat it like an independent milestone.
### Build:
- Clicking note preview → opens overlay _under the row_
- Overlay has:
	- Normal text view
    - On click, the text turns into a multiline text editor
    - save button
    - cancel button
- Row height stays fixed
- Overlay animates in/out
- Rows above/below do NOT move
- Save action updates that one session only
**Why this early:**  
This is the heaviest behaviour in the whole app.  
Once it’s solid, the rest is trivial.

---
# ⭐️ **PHASE 4 — Add First Editable Capsule (Project)**
Do just one to validate the pattern you’ll clone for all others.
### Build:
- Click → popover anchored to capsule
- Shows all projects
- Selection updates session.projectID
- Immediately resets `phaseID = nil or unassigned` (because phases are project-bound)
- Row refreshes
- No row height change
- No filter reset
- No list jump
**Why project first:**  
It forces a secondary field update → perfect stress test.
Once this behaviour is perfect, the rest are copy-paste variants.
How the popover works:
- popover opens
- user picks an option
- picking the option immediately:
    - writes the new value into the session
    - triggers an update on that single row
    - closes the popover

---
# ⭐️ **PHASE 5 — Add Second Capsule (Phase)**
Validate the hierarchy:
### Build:
- Popover shows only phases belonging to the current project
- If project changes, phase resets correctly
- All behaviour mirrors project popover
- Test list stability, popover anchor, filter integrity
**Why second:**  
You prove the “dependent field” logic works without blowing up SwiftUI.

---
# ⭐️ **PHASE 6 — Add Remaining Capsules (Activity Type, Mood, Star)**
Do them one at a time, in this order:
1. Activity Type
2. Mood
3. Milestone Star
Each capsule uses the same “open popover → choose → row refresh only” pattern you’ve already validated.

**WE NEED TO ADD THE ABILITY TO CHANGE START AND END TIMES, and find a way to change the date of the start and end time, too.**

---
# ⭐️ **PHASE 7 — Add the Pulse Bar (Time-of-Day Indicator)**
By this point:
- the layout is stable
- overlays are stable
- refreshes are stable
- popovers are stable
Pulse is just decorative now — safe to add anytime.
---
# ⭐️ **PHASE 8 — Add Right-Click (Context Menu)**
I actually don't think right click is needed right now. Let's remove from roadmap.

---
# ⭐️ **PHASE 9 — Add Row Selection (Later, Not Now)**
This is the only part that will touch your managers.
But now:
- the row is perfect
- editing is perfect
- deletion is perfect
- overlays are perfect
- scrolling is stable
- the UX is predictable
You introduce selection into a world that can handle it.