# 💾 New Fields in Session Data Model

## 1. What we’re adding

### New session fields
- `action: String?`
- `isMilestone: Bool` (default `false`)

### Deprecated field
- `milestoneText: String?`  
    → logically replaced by `action + isMilestone`
Nothing else changes.  

---

## 2. Why this change is safe
- Sessions are append-only → historical edits are controlled
- Action is optional → no forced re-logging
- isMilestone defaults false → no logic explosions
- milestoneText migrates cleanly → zero data loss
- Charts don’t break → they just gain signal

---

## 3. Step-by-step implementation plan

### Step 1 — Extend the Session model (no UI yet)
Add fields everywhere the session struct/class exists:
- CSV schema
- Swift model
- Export / import logic
- Parsers
- LOOK AT DOCUMENTATION FOLDER AND MAKE A LIST OF ALL STRUCTS AND CLASSES
Defaults:
- `action = nil`
- `isMilestone = false`
**Do not remove milestoneText yet.**
This step should compile and run with no visible behaviour change.

---

### Step 2 — Migration logic (one-off, scriptable)
Write a small migration script (Python) that:
For each historical session:
- If `milestoneText` is non-empty:
    - `action = milestoneText`
    - `isMilestone = true`
- Else:
    - leave action empty
    - isMilestone = false
Do **not** delete milestoneText yet.

Run it once on our historical CSVs (2024-data.csv, 2025 and 2026, too, available in AppSupport/juju).  

---

### Step 3 — UI: introduce Action (quietly)
In the session save modal:
- Add a new **Action** text field
- Make it:
    - compulsary
    - single-line
    - labelled clearly in the same way the other fields are
Important:
- Do **not** remove Notes
- Do **not** add milestone UI yet
At this stage, Action is just… there.

---

### Step 4 — UI: Milestone toggle (only after Action exists)
Add:
- a small checkbox / toggle: **“Milestone”**
- Only enabled if Action is non-empty
This prevents:
- empty milestones
- meaningless flags
Internally:
- Toggle sets `isMilestone = true`
- No text duplication
- No extra ceremony

---

### Step 5 — Deprecate milestoneText (UI only)
Once Action is in use:
- Hide milestoneText from the UI
- Stop writing to it
- Keep it in the data model for legacy safety
At this point:
- milestoneText is historical only
- Action is canonical
- isMilestone is the truth

---