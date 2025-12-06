# Sidebar Edit Plan

## Overview
Replace the current modal-based editing system with a right-hand sidebar that slides in from the right when editing any entity (Sessions, Projects, Activity Types). This provides significantly more space for editing controls and creates a consistent, modern editing experience across the application.

## Current Problems
1. **Cramped editing controls** - Current inline editing in SessionsRowView is too cramped
2. **Inconsistent editing patterns** - Different modals for different entities
3. **Limited space** - Modal windows restrict the amount of editing controls that can be shown
4. **Poor user experience** - Modal dialogs interrupt workflow more than sidebars

## Proposed Solution
Implement a unified right-hand sidebar that:
- Slides in from the right when editing any entity
- Takes up approximately 1/3 of the screen width
- Provides ample space for all editing controls
- Maintains context by keeping the main content visible
- Uses consistent animations and styling across all edit operations

## Implementation Plan

### Phase 1: Create Sidebar Infrastructure (Improved)

#### 1.1 SidebarStateManager (Cleaned)
```swift
final class SidebarStateManager: ObservableObject {
    @Published var isVisible = false
    @Published var content: SidebarContent? = nil

    func show(_ content: SidebarContent) {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.content = content
            self.isVisible = true
        }
    }

    func hide() {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.isVisible = false
        }
        // Optional slight delay before clearing content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.content = nil
        }
    }
}
```

#### 1.2 SidebarContent Enum (Cleaned)
```swift
enum SidebarContent {
    case session(SessionRecord)
    case project(Project)
    case activityType(ActivityType)
    case newProject
    case newActivityType
}
```


#### 1.3 Sidebar Container View (Polished)
- `SidebarEditView` - Main container that handles sliding animation
- **Fixed width: 380–420 pt** on macOS (better than responsive)
- **Subtle blurred background** with 12px divider line
- **Does NOT block background scrolling** (keeps context visible)
- **Close button in header** + ESC key support
- **Swipe gesture to dismiss** (nice-to-have)
- **Content area** that dynamically loads appropriate edit view
- **Placement**: Lives at root level in `SwiftUIDashboardRootView` as overlay

### Phase 2: Create Individual Edit Views (Sharpened)

**All edit views use `.formStyle(.grouped)` to maintain consistent macOS layout and spacing.**

#### 2.1 SessionSidebarEditView (Polished)

**Layout guidance:**
* Time controls grouped (start, end, duration)
* Project picker → Phase picker → Activity Type picker
  (Reflects your relational model visually)
* Notes as a large text editor (approx. 8–12 lines)
* Mood using a slider or emoji row
* All controls use `.formStyle(.grouped)` for native macOS feel

**Important:** `SessionEditModalView.swift` will be removed from the codebase once the sidebar is fully integrated.


---

#### 2.2 ProjectSidebarEditView (Premium)

**Enhanced layout:**
* **Live preview** of the project card on top
  - Shows colour, emoji, project name as you edit
  - Feels premium and immediate
* Project color picker prominently displayed
* Larger emoji selection with search
* Better organized about/description field
* Phase management section with add/edit/delete inline

**Visual identity:**
* Project card preview updates in real-time
* Color picker shows current selection clearly
* Emoji picker includes favorites

---

#### 2.3 ActivityTypeSidebarEditView (Polished)

**Straightforward but elevated:**
* Larger emoji picker with search
* Better organized fields
* Clear visual separation of sections
* **Visual identity** - emoji + colour-dot candidate
* Activity type preview similar to project preview

**Key features:**
* Emoji picker with categories
* Color selection for visual identity
* Clear section headers

### Phase 3: Integration with Main Views (Improved)

#### 3.1 SessionsView Integration

**Rows no longer carry edit logic.**
Keep them clean and display-only.

Add a trailing "Edit" button:

```swift
Button {
    sidebarState.show(.session(session))
} label {
    Image(systemName: "pencil")
}
```

**Simplify SessionsRowView:**
* Remove all inline editing state (`tempNotes`, `tempMood`, etc.)
* Remove complex editing UI from expanded notes section
* Keep only display logic and simple edit button trigger
* Remove save/cancel/delete logic from row view

---

#### 3.2 ProjectsView Integration

Replace modals with:

```swift
sidebarState.show(.project(project))
```

**Key changes:**
* Remove existing modal presentation code
* Replace "Add Project" button to trigger `sidebarState.show(.newProject)`
* Replace "Edit Project" button to trigger `sidebarState.show(.project(project))`
* Remove ProjectAddEditView modal logic

---

#### 3.3 ActivityTypesView Integration

Same pattern.

Replace modals with:

```swift
sidebarState.show(.activityType(activityType))
```

**Key changes:**
* Remove existing modal presentation code
* Replace "Add Activity Type" button to trigger `sidebarState.show(.newActivityType)`
* Replace "Edit Activity Type" button to trigger `sidebarState.show(.activityType(activityType))`
* Remove ActivityTypeAddEditView modal logic

---

#### 3.4 Root-Level Sidebar Placement

**Critical: Sidebar lives at root level**

Placement: `SwiftUIDashboardRootView`
→ Contains navigation
→ Contains content
→ Contains top-level `SidebarEditView` overlay

**The sidebar overlay should use `.zIndex(1000)` to guarantee it always renders above all dashboard content regardless of animations or conditional view loads.**

This ensures:
* Sidebar isn't "stuck inside" a child view
* Proper layering and animations
* Universal access from any child view
* No weird layering artefacts in SwiftUI, especially with transitions

### Phase 4: Animation and Polish (Enhanced)

#### 4.1 Animation (Optimized)

Use:

```swift
.animation(.easeInOut(duration: 0.25), value: sidebarState.isVisible)
```

Slide offset:

```swift
.offset(x: sidebarState.isVisible ? 0 : 420)
```

**Key improvements:**
* **0.25s animation** (faster than 0.3s) for snappier feel
* **No backdrop dimming** - keeps main content accessible
* **Proper z-index** - sidebar appears above content without blocking scroll

**Accessibility compliance:**
Use `.transaction { t in t.disablesAnimations = UIAccessibility.isReduceMotionEnabled }` to ensure accessibility compliance.

---

#### 4.2 Gesture Support

Add:
* **Swipe right to close** (nice-to-have)
* **ESC to close** (essential)
* **Cmd+S to save** (essential)

---

#### 4.3 Performance (Optimized)

Sidebar content should be lazy-loaded:

```swift
if let content = sidebarState.content {
    SidebarEditView(content: content)
}
```

**Performance notes:**
* Don't create all edit views in advance
* Use `@ViewBuilder` for conditional content loading
* Keep sidebar views lightweight

---

#### 4.4 Responsive Behavior (Refined)

**Fixed width approach:**
* 380–420 pt on macOS (better than responsive)
* On smaller screens, sidebar could take up more width
* Proper handling of window resizing

## Benefits

### User Experience
1. **More editing space** - 3x more room for controls compared to modals
2. **Context preservation** - Main content remains visible while editing
3. **Consistent interaction pattern** - Same sidebar behavior across all entities
4. **Less disruptive** - Sidebars are less interruptive than modal dialogs

### Code Quality
1. **Unified architecture** - Single sidebar system instead of multiple modal types
2. **Easier maintenance** - Centralized sidebar logic
3. **Better separation of concerns** - Display views separate from edit views
4. **Reusable components** - Sidebar infrastructure can be extended for future features

### Design Consistency
1. **Modern interface pattern** - Aligns with current macOS design trends
2. **Consistent animations** - Same slide behavior across all edit operations
3. **Unified styling** - All edit views share the same visual language

## Technical Considerations (Improved)

### State Management (EnvironmentObject)

**Sidebar state needs to be accessible from multiple views.**

Implementation:

```swift
@StateObject private var sidebarState = SidebarStateManager()
```

Then:

```swift
.environmentObject(sidebarState)
```

**Why EnvironmentObject:**
* Avoids global singleton issues
* Makes every view capable of triggering the sidebar without spaghetti
* Proper SwiftUI integration
* Automatic view refreshes when state changes

**Ensure proper cleanup:**
* Content cleared after animation completes
* No memory leaks from retained references

---

### Data Flow (Clean)

**Sidebar never mutates global models directly. It edits local draft copies, and only on Save does the parent view or data manager apply changes.**

This avoids every "Why did my half-typed notes save?!" bug.

**Sidebar needs access to current entity data.**
**Save operations need to propagate changes back to parent views.**

**Approach:**
* Use completion handlers or delegation pattern
* Sidebar calls back to parent view on save/cancel
* Parent view handles data persistence and UI updates

**Example pattern:**
```swift
sidebarState.show(.session(session)) { updatedSession in
    // Handle save
    // Update parent view state
}
```

---

### Performance (Optimized)

**Sidebar views should be lazy-loaded to avoid performance impact when not in use.**

**Key points:**
* Use `@ViewBuilder` for conditional content loading
* Keep sidebar views lightweight
* Animation performance optimized for smooth transitions
* No pre-creation of all edit views

## Implementation Timeline

### Week 1: Foundation
- [ ] Create SidebarStateManager
- [ ] Create SidebarContentType enum
- [ ] Build base SidebarEditView with animations

### Week 2: Edit Views
- [ ] Create SessionSidebarEditView
- [ ] Create ProjectSidebarEditView
- [ ] Create ActivityTypeSidebarEditView

### Week 3: Integration
- [ ] Update SessionsView to use sidebar
- [ ] Update ProjectsView to use sidebar
- [ ] Update ActivityTypesView to use sidebar

### Week 4: Polish
- [ ] Add animations and transitions
- [ ] Implement keyboard shortcuts
- [ ] Add responsive behavior
- [ ] Testing and bug fixes

## Files to Create/Modify

### New Files
- `Juju/Core/Managers/SidebarStateManager.swift`
- `Juju/Features/Sidebar/SidebarEditView.swift`
- `Juju/Features/Sessions/SessionSidebarEditView.swift`
- `Juju/Features/Projects/ProjectSidebarEditView.swift`
- `Juju/Features/ActivityTypes/ActivityTypeSidebarEditView.swift`

### Modified Files
- `Juju/Features/Sessions/SessionsView.swift`
- `Juju/Features/Sessions/SessionsRowView.swift`
- `Juju/Features/Projects/ProjectsNativeView.swift`
- `Juju/Features/ActivityTypes/ActivityTypesView.swift`
- `Juju/Features/Dashboard/SwiftUIDashboardRootView.swift` (if needed for sidebar integration)

## Success Criteria
1. All edit operations use the sidebar consistently
2. Editing experience feels spacious and uncluttered
3. Transitions are smooth and professional
4. Code is cleaner and more maintainable
5. User feedback indicates improved editing experience
