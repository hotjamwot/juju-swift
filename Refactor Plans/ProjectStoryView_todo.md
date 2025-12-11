## Annual Project Story View (The "Killer Feature")

### 🎯 Phase Purpose
Create a visual annual timeline for each project that summarizes each week's creative "phase" using dominant activity type, tags, and milestones.

---

### 3.1 Aggregation Layer (Simple, Deterministic)

#### 3.1.1 Core Aggregation Logic
- [ ] **Create ProjectStoryAggregator** service
- [ ] **Divide year into 4 blocks per month** (≈ weekly)
- [ ] **For each block + each project**:
  - [ ] Collect all sessions in that block
  - [ ] Determine dominant activity type
  - [ ] Determine dominant tag
  - [ ] Detect highlight(s)
  - [ ] If highlight present → override text with highlightText
  - [ ] Form a `ProjectStoryCellSummary` model

#### 3.1.2 Model Implementation
- [ ] **Create ProjectStoryCellSummary** struct:
  ```swift
  struct ProjectStoryCellSummary {
      let projectID: String
      let periodIndex: Int  // 0-47
      let dominantActivity: ActivityType?
      let dominantTag: String?
      let highlight: Bool
      let highlightText: String?
      let totalDuration: TimeInterval
  }
  ```
- [ ] **Implement aggregation methods**:
  - [ ] `weeklyActivityTotals()`
  - [ ] `aggregateActivityTotals(from:)`
  - [ ] `determineDominantActivity(from:)`
  - [ ] `determineDominantTag(from:)`
  - [ ] `detectHighlights(from:)`

#### 3.1.3 Optional Polish
- [ ] **Cache results per year** for performance
- [ ] **Provide "Mixed" fallback** if ties occur
- [ ] **Handle edge cases** (empty blocks, missing data)

---

### 3.2 Grid Layout (Readable, Scrollable, Minimal)

#### 3.2.1 Structure
- [ ] **New tab: "Story"** in sidebar
- [ ] **Vertical scroll** (months → bottom)
- [ ] **Horizontal scroll** (projects → right)
- [ ] **Sticky header row** for project names
- [ ] **Sticky first column** for month labels ("Jan", "Feb", etc)

#### 3.2.2 Cell Rendering
- [ ] **Rounded rectangle** with subtle project-colour tint
- [ ] **Emoji for dominant activity**
- [ ] **Small text for dominant tag**
- [ ] **⭐ if highlight exists**
- [ ] **Tooltip on hover** with:
  - [ ] all tags in that block
  - [ ] total duration
  - [ ] highlight text

#### 3.2.3 Click Behavior
- [ ] **On click** → open SessionsView filtered to:
  - [ ] selected project
  - [ ] selected block date range

---

### 3.3 UX + Storytelling (Light, Elegant, Non-intrusive)

#### 3.3.1 Must-Have Features
- [ ] **Clean visual grid**
- [ ] **Emoji + tag text** represent the "phase"
- [ ] **Stars represent milestones**
- [ ] **Tooltips give context**
- [ ] **Clicking drills into real sessions**

#### 3.3.2 Optional Nice-to-Haves (De-prioritized)
- [ ] Subtle fade animations for highlights
- [ ] "Mixed" badge when tie
- [ ] Timeline export
- [ ] Filtering sidebar
- [ ] Year selector