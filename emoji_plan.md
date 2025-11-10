# Project Emoji/Icon Implementation Plan

## Analysis Summary
I've analyzed the codebase and adding emoji/icon support to projects is **not a hugely difficult ordeal**. The codebase is well-structured and the changes required are straightforward.

## Current Project Structure
- **Project Model**: Contains `id`, `name`, `color`, `about`, `order`
- **Data Persistence**: Uses `ProjectManager` with JSON storage in `projects.json`
- **UI Components**: Multiple views display projects (charts, session cards, project lists)
- **Chart System**: `ChartDataPreparer` processes project data for various visualizations

## Implementation Plan

### Phase 1: Core Data Model (Foundation)
- [ ] **1.1** Add `emoji` field to `Project` struct in `Project.swift`
- [ ] **1.2** Update `CodingKeys` enum to include emoji
- [ ] **1.3** Update initializers to handle emoji (with default fallback)
- [ ] **1.4** Add migration logic in `ProjectManager` to handle existing projects without emoji

### Phase 2: User Interface (Project Management)
- [ ] **2.1** Add emoji picker interface to `ProjectAddEditView.swift`
- [ ] **2.2** Include emoji field in both "Add" and "Edit" modes
- [ ] **2.3** Add emoji selection UI (emoji picker)
- [ ] **2.4** Handle emoji validation and formatting

### Phase 3: Data Flow Integration
- [ ] **3.1** Update `ChartDataPreparer` to pass emoji data to chart models
- [ ] **3.2** Modify `ProjectChartData` and related models if needed
- [ ] **3.3** Update any views that display project information

### Phase 4: UI Display Updates
- [ ] **4.1** Add emoji display to session cards (`SessionCardView.swift`)
- [ ] **4.2** Add emoji to project list views in ProjectsNativeView
- [ ] **4.3** Consider emoji display in charts (optional, depends on chart type; ask User first)
- [ ] **4.4** Ensure emoji rendering works across all contexts

### Phase 5: Testing & Polish
- [ ] **5.1** Test migration of existing projects
- [ ] **5.2** Test emoji display in all UI contexts
- [ ] **5.3** Verify chart data integrity
- [ ] **5.4** Test edge cases (empty emojis, special characters)

## Technical Considerations

### Backward Compatibility
- Existing projects without emoji will use a default fallback (could be empty string or default emoji like "📁")
- JSON migration will add emoji field to existing projects automatically

### UI/UX Design
- Emoji picker should be:
  - System emoji picker (native macOS)
- Emoji display should be consistent across the app

### Chart Integration
- Bubble charts can show emojis inside circles above their project label
- Session cards will prominently display the project emoji
- Project lists will show emoji alongside names
- YearlyTotalBarChartView will show emoji instead of project color circle next to label

## Estimated Complexity: **MEDIUM**
- **Time**: 2-4 hours of development
- **Risk**: Low - well-isolated changes
- **Impact**: High visual improvement to user experience

## Next Steps
1. Start with Phase 1 (Core Data Model)
2. Proceed to Phase 2 (UI Components)  
3. Test each phase before moving to the next
4. Consider user feedback on emoji display preferences