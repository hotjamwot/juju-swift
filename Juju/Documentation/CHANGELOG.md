---
title: Juju Changelog
audience: [developer, AI assistant]
status: current
last_verified: 2026-09-18
---

# Juju Changelog

Concise history of significant user-facing and architectural changes. Newest entries are first.

## Sep 2026

- Extended the thought meshes past their containers into a fade, so they read as fragments of a larger plane; cascades now lengthen and dim hop by hop, decelerate on arrival, linger longer before fading, and end in seeded aftershock glimmers. Consolidated the ambience tests into a handful of broad checks that assert structure and bounds rather than tunable envelope constants.
- Consolidated the documentation set around `AGENTS.md`, `ARCHITECTURE.md`, `SWIFT_PATTERNS.md`, and this changelog. The separate roadmap was retired because completed work belongs here and current behavior belongs in code and tests.

## Aug 2026

- Refined dashboard hover behavior: plain mark brightness, short ease animations, edge-aware tooltips, and a fixed-height `DaySessionInfoPanel` swap.
- Merged the yearly project and activity charts into one Trends card with a shared legend.
- Replaced yearly totals with comparable rolling 90-day and 360-day trend bars.
- Reworked ProjectStory into the Braid: a chronological session spine plus non-contiguous phase lanes, phase detail, milestones, and cross-highlighting.
- Added phase filtering to Sessions and expanded bulk selection/editing.
- Centralized te reo Maori phrases and added signal-based encouragement copy.
- Standardized card surfaces, radii, shadows, and shared card styling.

## Jun 2026

- Redesigned the dashboard around a vertical scroll layout with natural chart heights and editorial section headers.
- Added dynamic Cmd+Tab visibility for open and closed app windows.
- Migrated activity-type icons from emoji to SF Symbols.

## May 2026

- Added bulk session editing, including selection, phase/project/mood updates, and stable refresh behavior.
- Added ProjectStory as a read-only narrative timeline.
- Removed redundant `DATA_FLOW.yaml` and consolidated architecture guidance.

## Earlier milestones

- **Mar 2026**: Phase ID integrity for archive, removal, and display.
- **Feb 2026**: Session action and milestone fields.
- **Jan 2026**: Date-based session migration to `startDate`/`endDate`.
- **Nov 2025**: Overview and yearly dashboard implementation.

For current architecture and implementation boundaries, read [ARCHITECTURE.md](ARCHITECTURE.md). For contributor rules, read [AGENTS.md](AGENTS.md).
