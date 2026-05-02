# 📖 ProjectStoryView — Design Brief

## Purpose

ProjectStoryView is the narrative heart of Juju.

Its job is not to optimise productivity, surface metrics, or encourage real-time behaviour change. Its job is to **preserve meaning**.

ProjectStoryView exists to answer one question, clearly and honestly:

> *What did it actually feel like to make this project over time?*

It turns raw session data into a legible story — revealing momentum, drift, turning points, and moments that genuinely mattered.

This view is designed primarily for **future-you**.

---

## Core Philosophy

ProjectStoryView is governed by a single rule:

> **Nothing appears here unless it helps future-you remember or reckon.**

This is a read-only space. A place to witness history, not rewrite it.

It should feel closer to opening a book than opening a dashboard.

---

## What ProjectStoryView Is (and Is Not)

### It *is*:

* A narrative representation of a single project
* A chapter-based view of creative effort
* A place where drift and flow are visible without judgement
* A long-form, reflective surface

### It is *not*:

* A productivity report
* A configuration screen
* A real-time coaching interface
* A place for micro-optimisation or editing

---

## Entry Point & Placement

ProjectStoryView replaces the **main content area** when a project is selected. It is accessed via the Projects tab, by selecting a button on a project's row.

* The sidebar remains for navigation
* Selecting a project transitions the app into its story
* No new top-level tabs are introduced

This reinforces the idea that you are *entering* a project, not viewing a report about it.

---

## Visual Structure

### Overall Layout

* Full-width, scrollable vertical timeline
* Chronological from first recorded session to most recent (or archive point)
* Visual at-a-glance feeling of seeing the journey a project, while more details tell the story

### Timeline Elements

#### 1. Project Header

* Project name, emoji, colour
* Project start date

This anchors the story.

---

#### 2. Phases (Chapter Markers)

Phases are the primary narrative unit.

Each phase appears as a clear chapter break with:

* Phase name or identifier
* Date range (from first session logged with PhaseID to last), like a vertical gannt chart almost

Phases structure memory. Sessions do not.

---

#### 3. Sessions (Implied, Not Exhaustive)

Sessions are represented as **density**, not rows.

* Grouped visually within phases
* Density implies momentum
* Gaps imply drift

Individual sessions are not the focus — their *pattern* is.

---

#### 4. Milestones

Milestones are rare, deliberate markers.

* Represented visually with a star or equivalent icon
* Drawn from the `isMilestone` boolean on sessions, using `action` string
* Signal moments that *mattered*, not just moments that happened

Milestones should feel canonised.

---

#### 5. Drift & Flow

Drift and flow are not labelled explicitly.

They are inferred visually through:

* Gaps in time
* Changes in session density
* Shifts in phase structure

This avoids judgement while still enabling reckoning.

---

## Interaction Rules

* Read-only
* No inline editing
* No sorting, filtering, or reordering
* Minimal controls

Editing belongs elsewhere. This view exists to protect history.

---

## Data Sources & Architecture

ProjectStoryView introduces **no new persistent data**.

It is a pure read-layer built from existing sources:

* `YYYY-data.csv` files

  * project
  * startDate / endDate
  * duration
  * phaseID
  * action
  * mood
  * isMilestone

* `projects.json`

  * project metadata (name, colour, emoji, archive state)

All narrative structure is **derived**, not stored.

---

## View Model Responsibility

A dedicated `ProjectStoryViewModel` is responsible for:

* Loading all sessions for a project
* Sorting chronologically
* Grouping by phaseID
* Inferring:

  * phase spans
  * session density
  * temporal gaps
  * milestone positions

No mutations. No writes.

---

## Emotional Design Goals

When viewing ProjectStoryView, the user should:

* Feel the weight of time
* Notice patterns they had forgotten
* Experience mild discomfort at drift
* Feel pride at momentum and completion
* Sense clear chapters instead of blur

If the view feels quiet, serious, or slightly confronting — it is working.

---

## Long-Term Intention

If Juju works perfectly, ProjectStoryView becomes the place you visit *after* a project is done — not while it’s being optimised.

It is the proof that the chapter existed.

And that it mattered.