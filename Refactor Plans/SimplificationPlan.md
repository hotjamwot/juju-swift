# Simplification & Housekeeping Plan

## Overview
This plan focuses on reducing complexity, removing technical debt, and improving maintainability without adding new reflection features. The goal is to make the codebase cleaner, more performant, and easier to understand.

## Phase 1: SessionManager Architecture Simplification

### 1.1 Remove Intermediate Managers
**Current Problem**: SessionManager delegates to OperationsManager and DataPersistenceManager, creating unnecessary complexity.

**Target**: Direct 2-layer architecture (SessionManager → FileManagers)

**Files to Modify**:
- `Juju/Core/Managers/SessionManager.swift`
- `Juju/Core/Managers/Session/SessionStateManager.swift` (remove or merge)
- `Juju/Core/Managers/Data/SessionPersistenceManager.swift` (remove or merge)

**Implementation Steps**:
1. **Audit Dependencies**: Identify what each component manager does
2. **Consolidate Logic**: Move essential logic directly into SessionManager
3. **Remove Delegation**: Eliminate the three-layer delegation pattern
4. **Update Tests**: Ensure all functionality remains intact

**Expected Outcome**: 50% reduction in SessionManager complexity, clearer code paths

### 1.2 Simplify SessionManager Interface
**Current**: Complex property delegation pattern
**Target**: Direct property access with clear responsibilities

```swift
// Before: Property delegation through multiple layers
var allSessions: [SessionRecord] {
    get { dataManager.allSessions }
    set { dataManager.allSessions = newValue }
}

// After: Direct access with clear ownership
var allSessions: [SessionRecord] = [] {
    didSet {
        // Clear, direct notification
        NotificationCenter.default.post(name: .sessionsDidChange, object: nil)
    }
}
```

## Phase 2: Remove Data Duplication

### 2.1 Eliminate projectName Field
**Current Problem**: SessionRecord contains both `projectID` and `projectName`, violating single source of truth

**Target**: Remove `projectName` entirely, always resolve from ProjectManager

**Files to Modify**:
- `Juju/Core/Models/SessionModels.swift`
- `Juju/Core/Managers/Data/SessionDataParser.swift`
- `Juju/Core/Managers/File/SessionCSVManager.swift`
- All views that reference `projectName`

**Implementation Steps**:
1. **Remove Field**: Delete `projectName` from SessionRecord struct
2. **Update CSV Handling**: Modify CSV parsing to only use projectID
3. **Add Helper Method**: Create `getProjectName(from:)` in ProjectManager
4. **Update All References**: Replace all `session.projectName` with resolved names
5. **Migration Strategy**: Handle existing CSV files with projectName field

**Expected Outcome**: Eliminates data inconsistency risk, reduces storage, enforces normalization

### 2.2 Update CSV Format
**Current**: Legacy CSV format with projectName column
**Target**: Clean CSV with only essential fields

```swift
// Before: Mixed ID and name fields
struct SessionCSVRow {
    let projectName: String  // Legacy field
    let projectID: String    // New field
    // ... other fields
}

// After: ID-only approach
struct SessionCSVRow {
    let projectID: String
    // ... other fields
}
```

## Phase 3: Optimize Data Loading

### 3.1 Implement Query-Based Loading
**Current Problem**: Load all sessions then filter in memory - unsustainable for large datasets

**Target**: Efficient file-based filtering with pagination support

**Files to Modify**:
- `Juju/Core/Managers/SessionManager.swift`
- `Juju/Core/Managers/Data/SessionDataParser.swift`
- `Juju/Core/Managers/ChartDataPreparer.swift`

**Implementation Steps**:
1. **Create Query Model**: Define SessionQuery struct with filtering criteria
2. **Implement Efficient Loading**: Add file-based filtering to SessionDataParser
3. **Update Dashboard**: Use query-based loading for performance
4. **Add Pagination**: Support for large date ranges

**Expected Outcome**: Dramatic performance improvement with large datasets, reduced memory usage

### 3.2 Optimize Dashboard Data Loading
**Current**: Dashboard loads all sessions then filters to current week
**Target**: Load only required data for each dashboard view

```swift
// Before: Load everything
func loadAllSessions() async -> [SessionRecord] {
    // Loads ALL sessions from disk
}

// After: Load only what's needed
func loadSessions(matching query: SessionQuery) async -> [SessionRecord] {
    // Efficiently load only matching sessions
}
```

## Phase 4: Simplify Error Handling

### 4.1 Centralize Error Types
**Current Problem**: Multiple error types scattered across components

**Target**: Single, user-friendly error system

**Files to Modify**:
- Create new: `Juju/Core/Models/JujuError.swift`
- Update all error handling throughout codebase

**Implementation Steps**:
1. **Define Central Error Types**: Create JujuError enum with user-friendly messages
2. **Replace Scattered Errors**: Consolidate error handling
3. **Add Error Recovery**: Implement graceful degradation strategies
4. **Update UI**: Show user-friendly error messages

**Expected Outcome**: Consistent error handling, better user experience, easier debugging

### 4.2 Simplify Validation
**Current**: Complex validation scattered across multiple managers
**Target**: Centralized, clear validation with helpful error messages

```swift
// Before: Scattered validation
guard validator.validateProject(project).isValid else {
    return // Generic error
}

// After: Clear, specific validation
do {
    try validateSession(session)
} catch JujuError.validationError(let field, let reason) {
    // Specific, actionable error message
    showUserMessage("Invalid \(field): \(reason)")
}
```

## Phase 5: Code Organization Cleanup

### 5.1 Remove Unused Code
**Target**: Eliminate dead code and unused imports

**Files to Audit**:
- All Swift files for unused imports
- Remove commented-out code
- Eliminate unused methods and properties

### 5.2 Standardize Naming Conventions
**Current**: Inconsistent naming patterns across the codebase
**Target**: Consistent Swift naming conventions

**Standards to Apply**:
- Use `lowerCamelCase` for properties and methods
- Use `UpperCamelCase` for types and protocols
- Use descriptive, clear names
- Avoid abbreviations unless universally understood

### 5.3 Improve Documentation
**Target**: Clear, concise documentation for complex logic

**Focus Areas**:
- SessionManager methods
- Data flow between components
- Error handling strategies
- Performance-critical code paths

## Phase 6: Performance Optimizations

### 6.1 Optimize Session Filtering
**Current**: In-memory filtering of all sessions
**Target**: Efficient file-based filtering

**Implementation**:
```swift
// Before: Filter in memory
let filteredSessions = allSessions.filter { /* criteria */ }

// After: Filter during loading
let filteredSessions = await sessionManager.loadSessions(matching: query)
```

### 6.2 Reduce Memory Usage
**Target**: Minimize memory footprint for long-term usage

**Strategies**:
- Lazy loading of session data
- Efficient caching strategies
- Proper cleanup of unused data

## Implementation Timeline

### Week 1: Foundation (Low Risk)
1. **Day 1-2**: Remove unused code and standardize naming
2. **Day 3-4**: Create centralized error handling system
3. **Day 5**: Update documentation and code comments

### Week 2: SessionManager Simplification (Medium Risk)
1. **Day 1-2**: Audit SessionManager dependencies and plan consolidation
2. **Day 3-4**: Implement simplified SessionManager architecture
3. **Day 5**: Test and validate all SessionManager functionality

### Week 3: Data Model Cleanup (High Risk)
1. **Day 1-2**: Remove projectName field and update CSV handling
2. **Day 3-4**: Update all references throughout codebase
3. **Day 5**: Test migration from existing data

### Week 4: Performance Optimization (Medium Risk)
1. **Day 1-2**: Implement query-based session loading
2. **Day 3-4**: Optimize dashboard data loading
3. **Day 5**: Performance testing and validation

## Risk Mitigation

### High-Risk Changes
- **Data Model Changes**: Maintain backward compatibility during transition
- **SessionManager Refactoring**: Extensive testing to ensure no functionality loss
- **CSV Format Changes**: Robust migration strategy for existing user data

### Testing Strategy
- **Unit Tests**: Ensure all individual components work correctly
- **Integration Tests**: Verify component interactions remain intact
- **Performance Tests**: Validate that optimizations actually improve performance
- **Migration Tests**: Test data migration from old to new formats

### Rollback Plan
- **Git Branches**: Each phase on separate branch for easy rollback
- **Feature Flags**: Gradual rollout of changes
- **Data Backup**: Ensure user data can be restored if needed

## Success Metrics

### Code Quality
- **Lines of Code**: Reduce SessionManager complexity by 50%
- **Cyclomatic Complexity**: Simplify complex methods
- **Test Coverage**: Maintain or improve test coverage

### Performance
- **Startup Time**: Faster app launch with optimized data loading
- **Memory Usage**: Reduced memory footprint for large datasets
- **Filtering Speed**: Significant improvement in session filtering performance

### Maintainability
- **Code Clarity**: Easier to understand and modify code
- **Error Messages**: More helpful and actionable error messages
- **Documentation**: Clear documentation for complex logic

## Notes

- **No New Features**: This phase focuses purely on simplification and cleanup
- **Backward Compatibility**: Maintain compatibility with existing user data
- **Gradual Implementation**: Implement changes incrementally to minimize risk
- **User Impact**: Changes should be transparent to users, only improving performance and reliability