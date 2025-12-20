# 🌟 Annual Focus & Project Story System

*(formerly “Annual Project Story View”)*

**Status:** ⏳ Upcoming Phases
**Priority:** 🟠 High
**Guiding Principle:** Build clarity first, narrative second — one small surface at a time.

---

## 🧠 The Core Insight

Juju needs **two different annual lenses**, not one overloaded one.

1. **The Focus Lens**
   *Where did my attention actually go this year?*

2. **The Story Lens**
   *What happened inside a project over time?*

Trying to answer both questions in a single view creates noise and emotional confusion. This plan deliberately separates them.

---

## PART I — YEARLY DASHBOARD: **Activity Focus Map**

### Purpose

Give users a calm, immediate sense of how their **attention was distributed across the year**, without narrative detail.

This is *context*, not storytelling.

---

### 🧭 What This View Answers

* Which activity types dominated the year?
* Where was I consistent vs intermittent?
* When did my focus shift?

---

### 🎨 The Visual Concept — *Focus Map*

A **vertical comparison band chart** showing **activity types** over time.

**Structure:**

* **X-axis:** Activity Types (emoji + colour)
* **Y-axis:** Calendar time (Jan 1 → Today, ascending)
* **Bands:**

  * A vertical band is “on” for a day if *any* session of that activity exists
  * Consecutive days form continuous bands
  * Gaps are clearly visible

**Design Rules:**

* No durations
* No phases
* Minimal labels
* Calm colour palette
* This chart must read instantly, even from across the room

---

### 🧪 Build This in Tiny Steps

**Step 1:**
Render a single vertical band for *one* activity type across days.

**Step 2:**
Add multiple activity columns.

**Step 3:**
Add responsive Y-axis scaling (Jan → today).

**Step 4:**
Polish axes, spacing, and colour softness.

> 🚫 No milestones here.
> 🚫 No hover dependence.
> 🚫 No narrative ambition yet.

---

### Why This Lives on the Yearly Dashboard

* It complements your existing bundle charts
* It keeps the yearly dashboard reflective, not dense
* It avoids turning the dashboard into a wall of story detail

---

## PART II — PROJECT STORY VIEW: **The Narrative Surface**

### Purpose

Turn a single project into a **readable, human story**.

This is where:

* phases matter
* milestones belong
* memory and meaning live

---

### 🧩 This Is a Separate View (Swipe / Tab)

This is **not** a dashboard panel.
It’s a destination.

Think:

> “I want to *remember* what happened here.”

---

### 📖 The Visual Concept — *Project Story Timeline*

A **horizontal timeline**, read left → right, like a book.

**Structure:**

* **X-axis:** Time (weeks or days, depending on zoom)
* **Y-axis:** Project phases (Draft 1, Draft 2, Edit, Polish, etc.)
* **Bands:**

  * Show active periods within each phase
  * Gaps are meaningful and visible

**Milestones:**

* ⭐ Star markers placed on the timeline
* Optional short labels
* Simple native tooltip on hover for milestone text

**Sessions:**

* Implicit via band presence or subtle density
* No dot spam
* No micromanagement of duration

---

### 🧪 Build This in Tiny Steps

**Step 1:**
Render a horizontal timeline for one project with time only.

**Step 2:**
Add phase rows (static, no data yet).

**Step 3:**
Fill bands where sessions exist.

**Step 4:**
Overlay milestone stars (no labels at first).

**Step 5:**
Add tooltips / short labels once spacing is proven.

Each step should compile, render, and *feel useful* on its own.

---

## 🎭 Emotional Contract (Important)

### Focus Map Should Feel:

* Neutral
* Observational
* Slightly sobering, but kind

### Project Story Should Feel:

* Personal
* Celebratory
* Memory-like, not analytical

If either view starts to feel stressful, it’s doing the wrong job.

---

## 🎯 Success Indicators (Reframed)

### Behavioural

* Users glance at the Focus Map without needing explanation
* Users linger in the Project Story view
* Users say “oh yeah… that’s when that happened”

### Emotional

* Pride without pressure
* Insight without judgement
* Motivation without gamification

---

## 🧱 What We Are *Not* Doing (Yet)

* No “ultimate yearly everything view”
* No combining activities, phases, milestones, and stats in one surface
* No cleverness that can’t be read in under 5 seconds

This plan explicitly resists ambition creep.

---

## 🧠 Final Framing (Keep This)

**Yearly Dashboard:**

> *“How did my year feel?”*

**Project Story View:**

> *“What did I actually build?”*

That separation is the spine of the product now.
