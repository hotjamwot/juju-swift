# 📋 Phase 2: Hero Section Intelligence

**Status:** ⏳ Not Started | **Priority:** 🟠 High | **Estimated Duration:** 1-2 weeks

**Context:** This phase transforms the dashboard from displaying raw stats to telling a compelling story about your creative work. The Hero Section becomes the narrative centerpiece.

---

## 🎯 Phase Objectives

### Core Goals
- Replace static stats with dynamic narrative headlines
- Implement Activity-based bubble chart instead of Project-based
- Enhance calendar chart with activity emojis
- Create the Editorial Engine that generates compelling stories

### Success Criteria
- [ ] Editorial Engine generates meaningful headlines
- [ ] Activity Bubble Chart displays correctly
- [ ] Calendar chart shows activity emojis
- [ ] Hero Section tells a story about creative work
- [ ] Performance remains smooth with new features

---

## 📝 Detailed Tasks

### 2.1 Editorial Engine Development

#### Headline Generation Logic
- [ ] Create Editorial Engine service
- [ ] Implement total duration calculation for selected period
- [ ] Add logic to determine "Top Activity" by time spent
- [ ] Add logic to determine "Top Project" by time spent
- [ ] Implement milestone detection from recent sessions
- [ ] Generate narrative headlines like:
  - "This week you logged 13h. Your focus was **Writing** on **Project X**, where you reached a milestone: **'Finished Act I'**."

#### Dynamic Headline Integration
- [ ] Replace static headline text with Editorial Engine output
- [ ] Ensure headline updates when filters change
- [ ] Add loading states and error handling
- [ ] Test with various data scenarios

### 2.2 Activity Bubble Chart Implementation

#### Chart Data Aggregation
- [ ] Create service to aggregate duration by `activityTypeID`
- [ ] Map activity types to their emoji representations
- [ ] Calculate bubble sizes based on time spent
- [ ] Ensure chart updates with filter changes

#### Chart UI Development
- [ ] Build Activity Bubble Chart component
- [ ] Replace existing Project Bubble Chart in Hero Section
- [ ] Implement tooltips showing exact time and percentages
- [ ] Add smooth animations for chart updates
- [ ] Ensure accessibility compliance

### 2.3 Hero Section Activity State Integration

#### Active Session Activity Display
- [ ] Update Hero Section to read current Active Activity Type
- [ ] Display immediate status update even when Project is unknown
- [ ] Ensure Activity Type emoji is prominently shown during active sessions
- [ ] Handle cases where session has activity but no project assigned yet
- [ ] Test real-time updates when session starts/stops

#### Activity State Management
- [ ] Integrate with Session Manager for active session state
- [ ] Ensure Hero Section reflects current working activity immediately
- [ ] Update status indicators to show active Activity Type
- [ ] Handle transitions between different activity types smoothly

### 2.4 Calendar Chart Enhancement

#### Activity Emoji Integration
- [ ] Modify Session Calendar Chart to display activity emojis
- [ ] Map activity types to their emoji representations
- [ ] Add emojis to daily session bars
- [ ] Ensure emojis are visible and readable at all sizes

#### Visual Polish
- [ ] Test emoji visibility across different themes
- [ ] Add hover effects showing activity type names
- [ ] Ensure performance with emoji rendering

---

## 🔗 Dependencies & Integration Points

### Required From Phase 1
- [ ] ActivityType system must be fully functional
- [ ] Session data must include activityTypeID
- [ ] Data aggregation services must be available
- [ ] UI components must support new data structures

### Integration with Existing Systems
- [ ] Dashboard components must integrate with Editorial Engine
- [ ] Chart libraries must support new data formats
- [ ] Filter system must work with new aggregations
- [ ] Theme system must support emoji rendering

---

## 🧪 Testing Strategy

### Unit Tests
- [ ] Test Editorial Engine headline generation
- [ ] Test activity aggregation calculations
- [ ] Test bubble chart data processing
- [ ] Test emoji rendering utilities

### Integration Tests
- [ ] Test Hero Section with live data
- [ ] Test chart interactions and updates
- [ ] Test filter integration with new charts
- [ ] Test performance with large datasets

### User Experience Tests
- [ ] Test narrative headline readability
- [ ] Test chart interactivity
- [ ] Test emoji visibility and clarity
- [ ] Test overall Hero Section flow

---

## 🎨 Design Considerations

### Narrative Headlines
- **Tone:** Professional yet personal
- **Length:** Concise but informative
- **Content:** Focus on activity balance and milestones
- **Updates:** Real-time with filter changes

### Activity Bubble Chart
- **Visual Hierarchy:** Writing > Editing > Admin (by importance)
- **Color Scheme:** Consistent with ActivityType definitions
- **Interactivity:** Tooltips, hover effects, click actions
- **Accessibility:** Screen reader support, color contrast

### Calendar Enhancement
- **Emoji Integration:** Subtle but visible
- **Activity Representation:** Clear mapping to types
- **Theme Support:** Works with light/dark modes
- **Performance:** Smooth rendering with many sessions

---

## ⚠️ Risk Mitigation

### Performance Risks
- [ ] Monitor chart rendering performance
- [ ] Test with large time ranges
- [ ] Optimize aggregation queries
- [ ] Implement lazy loading where needed

### User Experience Risks
- [ ] Ensure headlines are meaningful
- [ ] Test emoji compatibility across systems
- [ ] Validate chart readability
- [ ] Monitor user feedback on changes

### Technical Risks
- [ ] Chart library compatibility
- [ ] Data structure changes impact
- [ ] Theme and styling conflicts
- [ ] Accessibility compliance

---

## 📊 Progress Tracking

### Week 1 Focus
- [ ] Editorial Engine development
- [ ] Headline generation logic
- [ ] Activity aggregation service
- [ ] Basic chart integration

### Week 2 Focus
- [ ] Chart UI development and polish
- [ ] Calendar emoji integration
- [ ] Performance optimization
- [ ] User experience testing

---

## 🎯 Phase Completion Checklist

### Must Have (Critical)
- [ ] Editorial Engine generates compelling headlines
- [ ] Activity Bubble Chart replaces Project Bubble Chart
- [ ] Calendar chart displays activity emojis
- [ ] All new features integrate smoothly
- [ ] Performance remains acceptable

### Nice to Have (Enhancements)
- [ ] Advanced headline variations
- [ ] Enhanced chart animations
- [ ] Additional emoji customization
- [ ] Performance optimizations

### Documentation
- [ ] Editorial Engine documentation
- [ ] Chart component documentation
- [ ] API changes documented
- [ ] User guide updates

---

## 🔄 Next Steps

**Upon Completion of Phase 2:**
1. Validate narrative features with users
2. Test performance with real data
3. Gather feedback on storytelling effectiveness
4. Proceed to [Phase 3: Annual Project Story View](./Phase3.md)

**Key Success Factors:**
- Headlines must be meaningful and actionable
- Charts must be visually appealing and informative
- Performance must remain smooth
- Users must feel the narrative is valuable

---

## 💡 Implementation Notes

### Editorial Engine Logic
The Editorial Engine should prioritize:
1. **Time-based insights** (most hours, growth trends)
2. **Activity balance** (writing vs admin vs editing)
3. **Milestone achievements** (significant accomplishments)
4. **Project progress** (which projects are active)

### Chart Design Principles
- **Activity-first approach:** Emphasize how you work over what you work on
- **Visual storytelling:** Use size, color, and position to tell stories
- **Interactive exploration:** Allow users to dive deeper into data
- **Emotional resonance:** Make charts feel personal and meaningful

---

**Previous:** [Phase 1: Data Foundations](./Phase1.md) | **Next:** [Phase 3: Annual Project Story View](./Phase3.md)
