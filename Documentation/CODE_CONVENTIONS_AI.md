# Code Conventions for AI Development

## Naming Conventions

### Classes and Structs
- Use PascalCase: `SessionManager`, `ChartDataPreparer`
- Be descriptive: `ProjectStatisticsCache` not `Cache`
- Follow domain language: `SessionRecord`, `ActivityType`

### Methods
- Use verb-noun: `loadSessions()`, `updateSessionFull()`
- Be specific: `parseSessionsFromCSVWithQuery()` not `parseData()`
- Use clear prefixes: `isSessionActive`, `hasIdColumn`

### Variables
- Use camelCase: `sessionStartTime`, `projectColor`
- Be descriptive: `currentWeekInterval` not `interval`
- Use domain terms: `projectID`, `activityTypeID`

### Constants and Enums
- Use PascalCase for enum cases: `SessionStatus.active`
- Use UPPER_CASE for constants: `MAX_SESSION_DURATION`
- Group related constants in structs: `Theme.Colors.primary`

## File Organization

### Directory Structure
```
Juju/
├── Core/           # Business logic, models, managers
├── Features/       # Feature-specific UI and view models
├── Shared/         # Cross-cutting concerns
└── App/           # App lifecycle
```

### File Naming
- Use descriptive names: `SessionsRowView.swift` not `RowView.swift`
- Group related files: All dashboard files in `Features/Dashboard/`
- Use consistent suffixes: `View`, `Manager`, `ViewModel`

### File Structure
```swift
// 1. Imports
import Foundation
import SwiftUI

// 2. File Purpose Header
/// [File Name]
/// 
/// **Purpose**: Clear description of what this file contains
/// **Dependencies**: List of key dependencies and why they're needed
/// **Usage**: How this file is typically used in the codebase
/// **AI Notes**: Specific guidance for AI assistants working with this file

// 3. Type Definitions (structs, classes, enums)
// 4. Extensions
// 5. Helper Functions
```

## Documentation Standards

### Method Documentation
```swift
/// Brief description of what the method does
///
/// **AI Context**: Explain why this method exists and when to use it
/// **Business Rules**: Document any constraints or requirements
/// **Edge Cases**: Note any special handling needed
///
/// - Parameters: Describe each parameter
/// - Returns: Describe return value
/// - Throws: Document any errors thrown
func methodName() -> ReturnType {
    // Implementation
}
```

### File Headers
```swift
/// SessionManager.swift
/// 
/// **Purpose**: Central coordinator for all session-related operations including
/// start/end tracking, data persistence, and UI state management
/// 
/// **Key Responsibilities**:
/// - Session lifecycle management (start, end, update, delete)
/// - CSV file operations with year-based organization
/// - Data validation and migration
/// - UI state coordination and notification broadcasting
/// 
/// **Dependencies**:
/// - SessionFileManager: Handles low-level file operations
/// - SessionCSVManager: Manages CSV formatting and year-based routing
/// - SessionDataParser: Parses CSV data into SessionRecord objects
/// - ProjectManager: Validates project associations
/// 
/// **AI Notes**:
/// - This is the primary interface for all session operations
/// - Always use projectID, not projectName for new sessions
/// - Handles automatic migration of legacy data formats
/// - Posts notifications for UI updates via NotificationCenter
/// - Uses @MainActor for UI-bound operations
```

### Inline Comments
```swift
// Use inline comments to explain complex logic
// or business rules that aren't immediately obvious

// AI Context: This guard statement ensures we don't process
// sessions that are already marked as completed
guard !session.isCompleted else {
    return false
}

// Business Rule: Sessions must have a minimum duration of 1 minute
// to be considered valid for tracking
let duration = endTime.timeIntervalSince(startTime)
guard duration >= 60 else {
    return false
}
```

## Error Handling Patterns

### Always Handle Errors
```swift
// DO: Handle errors explicitly
do {
    let result = try someOperation()
    // Success handling
} catch {
    errorHandler.handleFileError(error, operation: "read", filePath: url.path)
    return // Fail fast
}

// DON'T: Ignore errors
let result = try? someOperation() // Silent failure
```

### Use Specific Error Types
```swift
enum JujuError: Error {
    case invalidSessionData(String)
    case fileOperationFailed(String)
    case dataMigrationFailed(String)
}

// When throwing errors, provide context
throw JujuError.invalidSessionData("Session \(id) has invalid start time")
```

### Error Recovery Patterns
```swift
func loadSessions() -> [SessionRecord] {
    do {
        return try SessionManager.shared.loadSessions()
    } catch JujuError.fileNotFound {
        // Gracefully handle missing files
        return []
    } catch {
        // Log unexpected errors
        print("Unexpected error loading sessions: \(error)")
        return []
    }
}
```

## Threading and Concurrency

### UI Operations
```swift
// Use @MainActor for UI-bound operations
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var sessions: [SessionRecord] = []
    
    func updateSessions() {
        // This runs on main thread automatically
        sessions = SessionManager.shared.loadSessions()
    }
}

// For background operations, use async/await
func loadDataInBackground() async {
    await Task.detached {
        let data = try await SessionManager.shared.loadLargeDataset()
        await MainActor.run {
            // Update UI on main thread
            self.sessions = data
        }
    }
}
```

### Data Access Patterns
```swift
// Use async for file operations
func saveSession(_ session: SessionRecord) async throws {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .background).async {
            do {
                try self.fileManager.saveSession(session)
                continuation.resume(returning: ())
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

## State Management

### View State
```swift
struct SessionsView: View {
    @StateObject private var viewModel = SessionsViewModel()
    @State private var isEditing = false
    
    var body: some View {
        List(viewModel.sessions) { session in
            SessionsRowView(session: session)
        }
    }
}
```

### View Model State
```swift
@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [SessionRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let sessionManager = SessionManager.shared
    
    func loadSessions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            sessions = try await sessionManager.loadSessions()
        } catch {
            errorMessage = "Failed to load sessions: \(error.localizedDescription)"
        } finally {
            isLoading = false
        }
    }
}
```

## Testing Guidelines

### Unit Tests
```swift
class SessionManagerTests: XCTestCase {
    var sessionManager: SessionManager!
    var mockFileManager: MockSessionFileManager!
    
    override func setUp() {
        super.setUp()
        mockFileManager = MockSessionFileManager()
        sessionManager = SessionManager(fileManager: mockFileManager)
    }
    
    func testStartSession_ValidProject_CreatesSession() async throws {
        // Given
        let projectID = "test-project"
        mockFileManager.mockProjects = [Project(id: projectID, name: "Test Project")]
        
        // When
        let result = try await sessionManager.startSession(projectID: projectID)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.savedSessions.count, 1)
        XCTAssertEqual(mockFileManager.savedSessions.first?.projectID, projectID)
    }
    
    func testStartSession_InvalidProject_ReturnsFalse() async {
        // Given
        let invalidProjectID = "invalid-project"
        
        // When
        let result = try await sessionManager.startSession(projectID: invalidProjectID)
        
        // Then
        XCTAssertFalse(result)
        XCTAssertTrue(mockFileManager.savedSessions.isEmpty)
    }
}
```

### Mock Objects
```swift
class MockSessionFileManager: SessionFileManagerProtocol {
    var mockSessions: [SessionRecord] = []
    var savedSessions: [SessionRecord] = []
    var deletedSessionIDs: [String] = []
    
    func loadSessions() throws -> [SessionRecord] {
        return mockSessions
    }
    
    func saveSession(_ session: SessionRecord) throws {
        savedSessions.append(session)
    }
    
    func deleteSession(_ sessionID: String) throws {
        deletedSessionIDs.append(sessionID)
    }
}
```

## Performance Best Practices

### Data Loading
```swift
// Use query-based loading for large datasets
func loadRecentSessions() async throws -> [SessionRecord] {
    let query = SessionQuery(
        startDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
        endDate: Date(),
        limit: 100
    )
    return try await sessionManager.loadSessions(query: query)
}

// Implement caching for expensive calculations
private var cachedStatistics: [String: ProjectStatistics] = [:]

func getProjectStatistics(for projectID: String) -> ProjectStatistics {
    if let cached = cachedStatistics[projectID] {
        return cached
    }
    
    let statistics = calculateProjectStatistics(for: projectID)
    cachedStatistics[projectID] = statistics
    return statistics
}
```

### UI Performance
```swift
struct LazySessionListView: View {
    @StateObject private var viewModel = SessionsViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.sessions) { session in
                SessionsRowView(session: session)
                    .listRowSeparator(.hidden)
            }
        }
        .refreshable {
            await viewModel.loadSessions()
        }
    }
}
```

## Code Organization

### Single Responsibility Principle
```swift
// GOOD: Each method has a single, clear responsibility
class SessionManager {
    func startSession(projectID: String) async throws -> Bool {
        // Only handles session starting logic
    }
    
    func endSession(_ sessionID: String) async throws -> Bool {
        // Only handles session ending logic
    }
    
    func updateSession(_ session: SessionRecord) async throws -> Bool {
        // Only handles session updating logic
    }
}

// BAD: Method does too many things
class SessionManager {
    func manageSession(_ sessionID: String, action: SessionAction, projectID: String?) async throws -> Bool {
        // Complex logic for multiple operations
        // Hard to test and maintain
    }
}
```

### Dependency Injection
```swift
// Use dependency injection for testability
class SessionManager {
    private let fileManager: SessionFileManagerProtocol
    private let validator: DataValidatorProtocol
    
    init(fileManager: SessionFileManagerProtocol, validator: DataValidatorProtocol) {
        self.fileManager = fileManager
        self.validator = validator
    }
}

// Default initializer for production use
extension SessionManager {
    convenience init() {
        self.init(
            fileManager: SessionFileManager(),
            validator: DataValidator()
        )
    }
}
```

## Common Patterns

### Result Types
```swift
enum Result<T, Error> {
    case success(T)
    case failure(Error)
}

func loadData() -> Result<[SessionRecord], JujuError> {
    do {
        let sessions = try sessionManager.loadSessions()
        return .success(sessions)
    } catch {
        return .failure(.fileOperationFailed(error.localizedDescription))
    }
}
```

### Optional Handling
```swift
// Use guard let for early returns
func processSession(_ session: SessionRecord?) -> Bool {
    guard let session = session else {
        return false
    }
    
    // Process session...
    return true
}

// Use if let when you need the unwrapped value
func displaySessionInfo(_ session: SessionRecord?) {
    if let session = session {
        print("Session: \(session.projectName)")
    } else {
        print("No session selected")
    }
}
```

### Collection Operations
```swift
// Use functional programming for collections
let activeSessions = sessions.filter { $0.status == .active }
let sortedSessions = sessions.sorted { $0.startTime > $1.startTime }
let totalDuration = sessions.reduce(0) { $0 + $1.duration }

// Avoid force unwrapping
let safeValue = optionalValue ?? defaultValue
```

This documentation provides comprehensive guidance for AI assistants working with the Juju codebase, ensuring consistent code quality and maintainability.

## Common Operation Examples

### Session Management Examples

#### Starting a New Session
```swift
// Correct way to start a session with project ID
SessionManager.shared.startSession(
    for: "Project Name", 
    projectID: "project-uuid-here"
)

// Legacy support (project name only)
SessionManager.shared.startSession(for: "Legacy Project Name")
```

#### Ending an Active Session
```swift
// End session with all optional fields
SessionManager.shared.endSession(
    notes: "Completed initial research phase",
    mood: 8,
    activityTypeID: "research-activity-id",
    projectPhaseID: "phase-uuid-here",
    milestoneText: "Research completed",
    completion: { success in
        if success {
            print("Session saved successfully")
        } else {
            print("Failed to save session")
        }
    }
)

// Minimal session end (only required fields)
SessionManager.shared.endSession()
```

#### Updating Session Data
```swift
// Update session notes
let success = SessionManager.shared.updateSession(
    id: "session-uuid", 
    field: "notes", 
    value: "Updated session notes"
)

// Update mood rating
let success = SessionManager.shared.updateSession(
    id: "session-uuid", 
    field: "mood", 
    value: "7"  // Must be valid integer string
)
```

### Project Management Examples

#### Creating a New Project
```swift
// Create project with all fields
let newProject = Project(
    name: "New Client Website",
    color: "#FF5733",
    about: "Website redesign for Acme Corp",
    order: 5,
    emoji: "🌐",
    phases: [
        Phase(name: "Planning", order: 1, archived: false),
        Phase(name: "Design", order: 2, archived: false),
        Phase(name: "Development", order: 3, archived: false)
    ]
)

ProjectManager.shared.addProject(newProject)
```

#### Managing Project Archiving
```swift
// Archive a completed project
ProjectManager.shared.setProjectArchived(true, for: "project-uuid")

// Get only active projects
let activeProjects = ProjectManager.shared.getActiveProjects()

// Get archived projects for review
let archivedProjects = ProjectManager.shared.getArchivedProjects()
```

#### Working with Project Phases
```swift
// Add a new phase to a project
let newPhase = Phase(name: "Testing", order: 4, archived: false)
ProjectManager.shared.addPhase(to: "project-uuid", phase: newPhase)

// Archive a phase
ProjectManager.shared.setPhaseArchived(true, in: "project-uuid", phaseID: "phase-uuid")

// Get active phases only
let activePhases = ProjectManager.shared.getActivePhases(for: "project-uuid")
```

### Data Validation Examples

#### Validating Individual Records
```swift
// Validate a session before saving
let session = SessionRecord(/* session data */)
switch DataValidator.shared.validateSession(session) {
case .valid:
    print("Session is valid")
case .invalid(let reason):
    print("Session validation failed: \(reason)")
}

// Validate a project
let project = Project(/* project data */)
switch DataValidator.shared.validateProject(project) {
case .valid:
    print("Project is valid")
case .invalid(let reason):
    print("Project validation failed: \(reason)")
}
```

#### Running Data Integrity Checks
```swift
// Check for data issues
let errors = DataValidator.shared.runIntegrityCheck()
if !errors.isEmpty {
    print("Found \(errors.count) data integrity issues:")
    for error in errors {
        print("  - \(error)")
    }
    
    // Attempt automatic repair
    let repairs = DataValidator.shared.autoRepairIssues()
    if !repairs.isEmpty {
        print("Applied \(repairs.count) automatic repairs:")
        for repair in repairs {
            print("  - \(repair)")
        }
    }
}
```

### Dashboard Data Preparation Examples

#### Preparing Weekly Data
```swift
// Load sessions and projects for dashboard
let sessions = SessionManager.shared.allSessions
let projects = ProjectManager.shared.loadProjects()

// Prepare data for weekly dashboard
let chartPreparer = ChartDataPreparer()
chartPreparer.prepareWeeklyData(sessions: sessions, projects: projects)

// Get weekly activity totals
let weeklyTotals = chartPreparer.weeklyActivityTotals()
for total in weeklyTotals {
    print("\(total.emoji) \(total.activityName): \(total.totalHours) hours (\(total.percentage)%)")
}
```

#### Preparing Yearly Data
```swift
// Prepare data for yearly dashboard
chartPreparer.prepareAllTimeData(sessions: sessions, projects: projects)

// Get yearly project totals (excludes archived projects)
let yearlyProjectTotals = chartPreparer.yearlyProjectTotals()
for total in yearlyProjectTotals {
    print("\(total.emoji) \(total.projectName): \(total.totalHours) hours (\(total.percentage)%)")
}
```

### Error Handling Examples

#### Handling File Operations
```swift
// Always handle file operations with error handling
do {
    let sessions = try await SessionManager.shared.loadAllSessions()
    // Process sessions
} catch {
    ErrorHandler.shared.handleFileError(error, operation: "load", filePath: "sessions.csv")
    // Handle error gracefully
}
```

#### Handling Validation Errors
```swift
// Validate before saving
let project = Project(/* data */)
switch DataValidator.shared.validateProject(project) {
case .valid:
    ProjectManager.shared.saveProjects([project])
case .invalid(let reason):
    ErrorHandler.shared.handleValidationError(
        NSError(domain: "Validation", code: 1001, userInfo: [NSLocalizedDescriptionKey: reason]),
        dataType: "Project"
    )
}
```

### Threading Examples

#### UI Operations (Main Thread)
```swift
// Always update UI on main thread
await MainActor.run {
    self.sessions = loadedSessions
    self.isLoading = false
    self.errorMessage = nil
}
```

#### Background Operations
```swift
// Use async/await for file operations
func loadDataInBackground() async {
    await Task.detached {
        let data = try await SessionManager.shared.loadAllSessions()
        await MainActor.run {
            // Update UI with loaded data
        }
    }
}
```

### Testing Examples

#### Unit Test Structure
```swift
class SessionManagerTests: XCTestCase {
    var sessionManager: SessionManager!
    var mockFileManager: MockSessionFileManager!
    
    override func setUp() {
        super.setUp()
        mockFileManager = MockSessionFileManager()
        sessionManager = SessionManager(fileManager: mockFileManager)
    }
    
    func testStartSession_ValidProject_CreatesSession() async throws {
        // Given
        let projectID = "test-project"
        mockFileManager.mockProjects = [Project(id: projectID, name: "Test Project")]
        
        // When
        let result = try await sessionManager.startSession(projectID: projectID)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockFileManager.savedSessions.count, 1)
        XCTAssertEqual(mockFileManager.savedSessions.first?.projectID, projectID)
    }
}
```

#### Mock Object Example
```swift
class MockSessionFileManager: SessionFileManagerProtocol {
    var mockSessions: [SessionRecord] = []
    var savedSessions: [SessionRecord] = []
    var deletedSessionIDs: [String] = []
    
    func loadSessions() throws -> [SessionRecord] {
        return mockSessions
    }
    
    func saveSession(_ session: SessionRecord) throws {
        savedSessions.append(session)
    }
    
    func deleteSession(_ sessionID: String) throws {
        deletedSessionIDs.append(sessionID)
    }
}
```

These examples demonstrate the proper patterns for working with the Juju codebase, following the established conventions and best practices.

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Session Management Issues

**Problem**: Session won't start
```swift
// Check if project exists
guard ProjectManager.shared.isValidProjectID(projectID) else {
    print("Project not found: \(projectID)")
    return false
}

// Check for existing active session
guard SessionManager.shared.currentSession == nil else {
    print("Session already active: \(SessionManager.shared.currentSession?.id ?? "unknown")")
    return false
}
```

**Problem**: Session data not saving
```swift
// Check file permissions
do {
    try SessionManager.shared.saveSession(session)
} catch {
    ErrorHandler.shared.handleFileError(error, operation: "save", filePath: "sessions.csv")
    // Check if directory exists and has write permissions
}
```

#### 2. Project Management Issues

**Problem**: Project validation fails
```swift
// Check for duplicate names
let existingProjects = ProjectManager.shared.loadProjects()
let duplicate = existingProjects.first { $0.name.lowercased() == projectName.lowercased() }
if let duplicate {
    print("Project name already exists: \(duplicate.name)")
}

// Check color format
guard project.color.hasPrefix("#") && project.color.count == 7 else {
    print("Invalid color format: \(project.color). Use #RRGGBB format.")
}
```

**Problem**: Phase operations failing
```swift
// Check if phase belongs to project
guard let project = ProjectManager.shared.getProject(for: projectID),
      project.phases.contains(where: { $0.id == phaseID }) else {
    print("Phase \(phaseID) not found in project \(projectID)")
    return false
}
```

#### 3. Dashboard Data Issues

**Problem**: Dashboard shows no data
```swift
// Check if sessions exist
let sessions = SessionManager.shared.allSessions
if sessions.isEmpty {
    print("No sessions found. Check session data files.")
}

// Check if projects exist
let projects = ProjectManager.shared.loadProjects()
if projects.isEmpty {
    print("No projects found. Check project data files.")
}

// Verify data relationships
let orphanedSessions = sessions.filter { session in
    !projects.contains { $0.id == session.projectID }
}
if !orphanedSessions.isEmpty {
    print("Found \(orphanedSessions.count) sessions with invalid project references")
}
```

#### 4. File Operation Issues

**Problem**: File not found errors
```swift
// Check file paths
let fileManager = FileManager.default
let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
let sessionsPath = documentsPath.appendingPathComponent("Juju/Sessions")

if !fileManager.fileExists(atPath: sessionsPath.path) {
    try fileManager.createDirectory(at: sessionsPath, withIntermediateDirectories: true)
    print("Created missing directory: \(sessionsPath.path)")
}
```

**Problem**: Permission denied errors
```swift
// Check file permissions
if let attributes = try? fileManager.attributesOfItem(atPath: filePath),
   let permissions = attributes[.posixPermissions] as? NSNumber {
    let permissionString = String(format: "%o", permissions)
    print("File permissions: \(permissionString)")
    
    // Fix permissions if needed
    try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: filePath)
}
```

#### 5. Data Validation Issues

**Problem**: Validation errors on valid data
```swift
// Run integrity check
let errors = DataValidator.shared.runIntegrityCheck()
if !errors.isEmpty {
    print("Data integrity issues found:")
    errors.forEach { print("  - \($0)") }
    
    // Attempt repair
    let repairs = DataValidator.shared.autoRepairIssues()
    if !repairs.isEmpty {
        print("Applied repairs:")
        repairs.forEach { print("  - \($0)") }
    }
}
```

**Problem**: Migration failures
```swift
// Check migration version compatibility
let migrationManager = SessionMigrationManager()
if !migrationManager.isMigrationNeeded() {
    print("No migration needed")
} else {
    do {
        try await migrationManager.performMigration()
        print("Migration completed successfully")
    } catch {
        ErrorHandler.shared.handleMigrationError(error, migrationType: "auto")
        print("Migration failed: \(error.localizedDescription)")
    }
}
```

#### 6. Performance Issues

**Problem**: Slow dashboard loading
```swift
// Use query-based loading
let query = SessionQuery(
    startDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
    endDate: Date(),
    limit: 1000
)
let sessions = try await SessionManager.shared.loadSessions(query: query)

// Implement caching
let chartPreparer = ChartDataPreparer()
chartPreparer.prepareWeeklyData(sessions: sessions, projects: projects)
```

**Problem**: Memory usage high
```swift
// Clear cached data periodically
ChartDataPreparer.shared.clearCache()

// Use lazy loading for large datasets
let lazySessions = SessionManager.shared.loadSessionsLazy()
```

#### 7. UI Issues

**Problem**: Views not updating
```swift
// Check @Published properties
class DashboardViewModel: ObservableObject {
    @Published var sessions: [SessionRecord] = []  // Ensure this is @Published
    
    func updateSessions() {
        DispatchQueue.main.async {
            self.sessions = SessionManager.shared.allSessions
        }
    }
}
```

**Problem**: State not persisting
```swift
// Check @StateObject vs @ObservedObject
struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()  // Use @StateObject for view models
    // @ObservedObject for shared state
}
```

### Debugging Strategies

#### 1. Enable Debug Logging
```swift
// Add debug logging to track execution
ErrorHandler.shared.logDebug("Starting session", context: "SessionManager.startSession")
ErrorHandler.shared.logPerformance("session creation", duration: 150.0, context: "SessionManager.startSession")
```

#### 2. Check Error Logs
```swift
// View recent errors
let recentErrors = ErrorHandler.shared.getRecentErrors()
recentErrors.forEach { errorInfo in
    print("Error: \(errorInfo.error.localizedDescription)")
    print("Context: \(errorInfo.context)")
    print("Timestamp: \(errorInfo.timestamp)")
}
```

#### 3. Validate Data Flow
```swift
// Trace data through the system
print("1. Sessions loaded: \(sessions.count)")
print("2. Projects loaded: \(projects.count)")
print("3. Data prepared: \(chartPreparer.weeklyActivityTotals().count)")
print("4. UI updated: \(viewModel.sessions.count)")
```

#### 4. Test with Mock Data
```swift
// Create test data to isolate issues
let testSession = SessionRecord(
    id: UUID().uuidString,
    projectID: "test-project",
    startDate: Date(),
    endDate: Date().addingTimeInterval(3600),
    notes: "Test session",
    mood: 8,
    activityTypeID: nil,
    projectPhaseID: nil,
    milestoneText: nil
)
```

### When to Contact Support

Contact support if you encounter:
- Persistent file corruption that can't be repaired
- Data migration failures that block app usage
- Performance issues that don't improve with optimization
- Complex UI state management problems
- Integration issues with external systems

### Prevention Strategies

1. **Regular Backups**: Always backup data before major operations
2. **Validation**: Use DataValidator before saving data
3. **Error Handling**: Always handle errors explicitly
4. **Testing**: Test with both new and legacy data formats
5. **Monitoring**: Use ErrorHandler logging to track issues
6. **Documentation**: Keep architecture documentation updated

This troubleshooting guide helps identify and resolve common issues in the Juju codebase, with specific guidance for AI assistants working on debugging and problem-solving tasks.
</final_file_content>

IMPORTANT: For any future changes to this file, use the final_file_content shown above as your reference. This content reflects the current state of the file, including any auto-formatting (e.g., if you used single quotes but the formatter converted them to double quotes). Always base your SEARCH/REPLACE operations on this final version to ensure accuracy.

