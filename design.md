# Juju Design Guide

## 🎨 Core Aesthetic
- Sleek, minimal, dark Mac-native elegance.
- Feels like: Notion × Raycast × Apple Music.
- Calm, focused, human — no clutter or chrome.

---

## 🧱 Layout
- Use **flat hierarchies**, no deep nesting.
- **Spacing:** multiples of 8pt (8, 16, 24).
- **Align:** content left, navigation centred.
- **Min window:** 1200×800.

---

## 🌈 Colours
| Element | Colour | Notes |
|----------|---------|-------|
| Background | #18181B | Dark grey base |
| Surface | #1E1E1F | Panels, cards |
| Accent | #7C5CFF | Purple-blue brand |
| Text Primary | #E5E5E7 | Off-white |
| Text Secondary | #9A9AA0 | Muted grey |
| Divider | rgba(255,255,255,0.1) | Subtle contrast |

---

## Layout Guidelines
- 10–16px border radius for cards and inputs
- 20–24px internal padding
- Light surface layering for hierarchy
- Sidebar width: ~260px fixed
- Subtle 1px translucent dividers or shadows

---

## Typography
- Font: Inter / SF Pro Display
- Base size: 16px
- Heading weight: 600
- Body weight: 400
- Line height: 1.5

---

## 🪄 Motion
- Use for **guidance, not decoration**.
- Prefer `.opacity`, `.move`, `.scale`, `.blur`.
- Duration: 0.2–0.3s easeInOut.
- “If you notice it as an effect, it’s too much.”

---

## Interaction & Components
- Rounded cards, panels, and text areas
- Hover: +5% brightness or shadow
- Transition: 200ms ease-in-out
- Icons: Lucide / SF Symbols, line weight 1.5–2px
- Command palette style: translucent, rounded, with blur

---

### Iconography
- Style: Outline / linear (Lucide / SF Symbols)
- Stroke weight: 1.5–2px
- Size: 20–24px
- Colour: #EDEDED (inactive), accent colour (active)

---

## Design Philosophy
- Calm and intelligent tone
- UI defers to content
- Minimal chrome, no borders
- Smooth, friendly micro-animations