# AI Working Guide for Juju Codebase

## For AI Assistants and Developers

### Codebase Context
- **Architecture**: MVVM + Managers pattern
- **Data Flow**: UI → ViewModels → Managers → File I/O
- **Storage**: Local CSV/JSON files (no cloud dependencies)
- **Threading**: @MainActor for UI, async/await for background operations

### Key Patterns to Follow

#### When Adding New Features:
1. **Follow MVVM Pattern**: Never put business logic in views
2. **Use Existing Managers**: Extend rather than create new managers
3. **Maintain Data Consistency**: Always use projectID as primary key
4. **Handle Notifications**: Post appropriate NSNotificationCenter events

#### When Modifying Data Models:
1. **Update Documentation**: Always update ARCHITECTURE_SCHEMA.md
2. **Update Data Flow**: Update DATA_FLOW.yaml for new data packets
3. **Maintain Backward Compatibility**: Support legacy CSV formats
4. **Add Validation**: Update DataValidator for new constraints

#### When Working with Sessions:
1. **Use SessionManager**: Never directly access CSV files
2. **Handle Project IDs**: Always use projectID, not projectName
3. **Validate Duration**: Ensure sessions have valid start/end times
4. **Post Notifications**: Trigger UI updates via NotificationCenter

### Common AI Tasks

#### Adding a New Feature:
1. Check if existing manager can handle the feature
2. Create new view model if needed
3. Add UI components following Theme.swift guidelines
4. Update documentation files
5. Add appropriate notifications

#### Fixing Bugs:
1. Identify the layer (UI, ViewModel, Manager, Data)
2. Check existing error handling patterns
3. Follow existing notification patterns
4. Test with both new and legacy data formats

#### Performance Optimization:
1. Use query-based loading (SessionQuery) instead of loading all data
2. Implement caching for expensive calculations
3. Use @MainActor for UI updates only
4. Batch file operations when possible

### Error Handling Patterns:
1. **Use JujuError enum**: Always use specific JujuError types with context
   ```swift
   // BEFORE: Generic error
   throw JujuError.dataError("Invalid session data")
   
   // AFTER: Context-rich error
   throw JujuError.dataError(
       operation: "parse", 
       entity: "session", 
       reason: "missing required field 'id'",
       context: "SessionDataParser.parseSessionsFromCSV"
   )
   ```

2. **Handle errors with ErrorHandler**: Use ErrorHandler.shared for consistent error handling
   ```swift
   ErrorHandler.shared.handleError(error, context: "SessionManager.startSession", severity: .error)
   ```

3. **Log debug information**: Use ErrorHandler logging methods for debugging
   ```swift
   ErrorHandler.shared.logDebug("Starting operation", context: "ClassName.methodName")
   ErrorHandler.shared.logPerformance("operation completed", duration: 150.0, context: "ClassName.methodName")
   ```

4. **Provide recovery suggestions**: Always include actionable error messages
   ```swift
   case .fileError(let operation, let filePath, let reason, _):
       return "Check file permissions for '\(filePath)' and try again."
   ```

### Code Style Guidelines
- Use descriptive variable names
- Add comprehensive method documentation
- Follow existing error handling patterns
- Maintain consistent formatting with Theme.swift
- Use emojis in UI components for personality

### Architecture Deep Dive

#### Core Components
- **SessionManager**: Central coordinator for session operations (start/end tracking, data persistence, UI state management)
- **ProjectManager**: Handles project lifecycle, validation, and statistics
- **ChartDataPreparer**: Aggregates session data for dashboard visualizations
- **DataValidator**: Ensures data integrity and validates business rules
- **NarrativeEngine**: Generates AI-powered session narratives and insights

#### Data Flow Patterns
1. **Session Creation**: Menu → SessionManager → File Persistence → Notifications → UI Updates
2. **Dashboard Updates**: SessionManager → ChartDataPreparer → Dashboard Views → UI
3. **Project Management**: ProjectsView → ProjectsViewModel → ProjectManager → JSON Files

#### Error Handling Strategy
- Always handle errors explicitly with do-catch blocks
- Use specific error types from JujuError enum
- Fail fast and provide actionable error messages
- Log errors for debugging with context information

### AI-Specific Considerations

#### When Working with File Operations:
- Always use SessionManager for session data, never access CSV files directly
- Use ProjectManager for project data, never access JSON files directly
- Handle file permissions and missing directories gracefully
- Support both new projectID-based and legacy projectName-based sessions

#### When Modifying UI Components:
- Follow Theme.swift color and spacing guidelines
- Use @State and @Binding for state management
- Implement proper accessibility labels
- Test with both light and dark mode themes

#### When Adding Business Logic:
- Place logic in appropriate Manager classes, not in Views or ViewModels
- Use @MainActor for UI-bound operations
- Implement proper validation and error handling
- Consider backward compatibility with existing data formats

### Testing Guidelines

#### Unit Tests
- Test all public methods in managers
- Mock dependencies to isolate functionality
- Test edge cases and error conditions
- Verify data validation rules

#### Integration Tests
- Test complete workflows from UI to persistence
- Verify notification patterns work correctly
- Test with both new and legacy data formats
- Validate dashboard data aggregation accuracy

### Performance Best Practices

#### Data Loading
- Use SessionQuery for filtered data loading
- Implement lazy loading for large datasets
- Cache expensive calculations in managers
- Use async/await for background operations

#### UI Performance
- Use @StateObject for expensive view model initialization
- Implement proper view lifecycle management
- Use efficient data structures for large collections
- Minimize UI updates with proper state management

### Common Pitfalls to Avoid

1. **Direct File Access**: Never access CSV/JSON files directly - always use managers
2. **Business Logic in Views**: Keep views focused on presentation only
3. **Missing Notifications**: Always post notifications for data changes
4. **Inconsistent Error Handling**: Use consistent error patterns throughout
5. **Hardcoded Values**: Use Theme.swift for colors, spacing, and constants
6. **Blocking UI Operations**: Use async/await for file operations
7. **Ignoring Legacy Data**: Always support backward compatibility

### Development Workflow

#### For New Features:
1. Analyze existing architecture and identify appropriate manager
2. Design data models following existing patterns
3. Implement manager methods with proper validation
4. Create view models for UI state management
5. Build UI components following Theme.swift
6. Add comprehensive documentation
7. Update architecture documentation files
8. Test with both new and existing data

#### For Bug Fixes:
1. Reproduce the issue with specific steps
2. Identify the root cause in the appropriate layer
3. Check existing error handling patterns
4. Implement fix following existing patterns
5. Add or update tests to prevent regression
6. Verify fix works with both new and legacy data

### Communication with Human Developers

When making significant changes or encountering complex issues:
1. Document your reasoning and approach
2. Reference relevant architecture documentation
3. Explain any trade-offs or design decisions
4. Suggest areas for further improvement
5. Ask clarifying questions when requirements are unclear

### Resources

- **Architecture Rules**: See ARCHITECTURE_RULES.md
- **Data Models**: See ARCHITECTURE_SCHEMA.md  
- **Data Flow**: See DATA_FLOW.yaml
- **Code Examples**: Review existing implementations in Core/Managers/
- **UI Patterns**: Follow examples in Features/ directories

### Component Relationships

#### Session Management Flow
```
MenuManager → SessionManager → SessionFileManager → CSV Files
     ↓              ↓                    ↓
  UI Actions → Business Logic → File Operations → Persistence
```

#### Dashboard Data Flow
```
SessionManager → ChartDataPreparer → Dashboard Views → UI
     ↓              ↓                    ↓
  Raw Sessions → Aggregated Data → Visualizations → User Interface
```

#### Project Management Flow
```
ProjectsView → ProjectsViewModel → ProjectManager → JSON Files
     ↓              ↓                    ↓
  User Input → State Management → Business Logic → Persistence
```

#### Data Validation Flow
```
Data Input → DataValidator → Error Handling → User Feedback
     ↓              ↓                    ↓
  Validation → Repair Logic → Data Integrity → Clean State
```

#### File Organization Hierarchy
```
Juju/
├── App/                    # App lifecycle and main entry points
│   ├── AppDelegate.swift   # App initialization and setup
│   ├── DashboardWindowController.swift  # Dashboard window management
│   └── main.swift         # Application entry point
├── Core/                   # Core business logic and data models
│   ├── Managers/          # Business logic coordinators
│   │   ├── SessionManager.swift      # Session lifecycle management
│   │   ├── ProjectManager.swift      # Project CRUD operations
│   │   ├── ChartDataPreparer.swift   # Dashboard data aggregation
│   │   ├── DataValidator.swift       # Data integrity validation
│   │   ├── ErrorHandler.swift        # Error handling and logging
│   │   ├── NarrativeEngine.swift     # AI narrative generation
│   │   ├── MenuManager.swift         # Menu system management
│   │   ├── IconManager.swift         # Icon management
│   │   ├── ShortcutManager.swift     # Keyboard shortcuts
│   │   └── SidebarStateManager.swift # Sidebar state management
│   ├── Models/            # Data models and value types
│   │   ├── SessionModels.swift       # Session data structures
│   │   ├── Project.swift             # Project data model
│   │   ├── ChartDataModels.swift     # Chart data structures
│   │   ├── JujuError.swift           # Error types
│   │   ├── SessionQuery.swift        # Query parameters
│   │   └── DashboardViewType.swift   # Dashboard view types
│   └── ViewModels/        # UI state management
│       └── ProjectsViewModel.swift   # Projects UI state
├── Features/              # Feature-specific implementations
│   ├── Dashboard/         # Dashboard functionality
│   │   ├── DashboardRootView.swift   # Main dashboard container
│   │   ├── Weekly/          # Weekly dashboard views
│   │   │   ├── WeeklyDashboardView.swift
│   │   │   ├── WeeklyEditorialView.swift
│   │   │   ├── SessionCalendarChartView.swift
│   │   │   └── WeeklyActivityBubbleChartView.swift
│   │   └── Yearly/          # Yearly dashboard views
│   │       ├── YearlyDashboardView.swift
│   │       ├── YearlyProjectBarChartView.swift
│   │       ├── YearlyActivityTypeBarChartView.swift
│   │       └── MonthlyActivityTypeGroupedBarChartView.swift
│   ├── Sessions/          # Session management UI
│   │   ├── SessionsView.swift        # Main sessions list
│   │   ├── SessionsRowView.swift     # Individual session row
│   │   └── Components/      # Session UI components
│   │       ├── BottomFilterBar.swift
│   │       ├── FilterToggleButton.swift
│   │       └── InlineSelectionPopover.swift
│   ├── Projects/          # Project management UI
│   │   ├── ProjectsView.swift        # Main projects list
│   │   └── ProjectSidebarEditView.swift  # Project editing
│   ├── ActivityTypes/     # Activity type management
│   │   ├── ActivityTypeView.swift    # Activity type list
│   │   └── ActivityTypeSidebarEditView.swift  # Activity type editing
│   ├── Notes/             # Notes functionality
│   │   ├── NotesModalView.swift      # Notes modal dialog
│   │   └── NotesViewModel.swift      # Notes state management
│   └── Sidebar/           # Sidebar UI
│       ├── SidebarView.swift         # Main sidebar container
│       └── SidebarEditView.swift     # Sidebar editing
├── Shared/                # Cross-cutting concerns
│   ├── Theme.swift        # App theming and styling
│   ├── TooltipView.swift  # Tooltip component
│   ├── Extensions/        # Swift extensions
│   │   ├── ButtonTheme.swift         # Button theming
│   │   └── NSColor+SwiftUI.swift     # Color extensions
│   └── Preview/           # Preview helpers
│       └── SimplePreviewHelpers.swift  # Preview utilities
└── Resources/             # App resources
    └── Assets.xcassets/   # Asset catalog
        ├── AppIcon.appiconset/       # App icons
        ├── Icons.imageset/          # UI icons
        ├── status-active.imageset/  # Active status icon
        ├── status-idle.imageset/    # Idle status icon
        └── *.colorset/              # Color definitions
```

#### Key Integration Points

**Session → Project Integration:**
- SessionManager validates project references via ProjectManager
- ProjectManager provides project statistics to SessionManager
- DataValidator ensures referential integrity between sessions and projects

**Dashboard → Data Integration:**
- ChartDataPreparer aggregates data from SessionManager
- Dashboard views subscribe to data changes via @Published properties
- Real-time updates flow through ObservableObject pattern

**UI → Business Logic Integration:**
- Views use ViewModels for state management
- ViewModels coordinate with Managers for business logic
- Managers handle data persistence and validation

**Error Handling Integration:**
- ErrorHandler provides centralized error logging
- DataValidator performs data integrity checks
- Managers handle specific error scenarios with user feedback

This guide is designed to help AI assistants work effectively with the Juju codebase while maintaining code quality and architectural consistency.
