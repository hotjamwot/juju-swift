# Code Conventions

## 📋 Naming

### Types
PascalCase: `SessionManager`, descriptive: `ProjectStatisticsCache`, domain terms: `SessionRecord`

### Methods
Verb-noun: `loadSessions()`, specific: `parseSessionsFromCSVWithQuery()`, clear prefixes: `isSessionActive`

### Variables
camelCase: `sessionStartTime`, descriptive: `currentWeekInterval`, domain terms: `projectID`

### Constants/Enums
PascalCase enum cases: `SessionStatus.active`, UPPER_CASE constants: `MAX_SESSION_DURATION`, group in structs: `Theme.Colors.primary`

---

## 📁 File Organization

### Structure
```
Juju/
├── Core/     # Business logic
├── Features/ # Feature UI
├── Shared/   # Cross-cutting
└── App/      # App lifecycle
```

### Naming
Descriptive: `SessionsRowView.swift`, group related: `Features/Dashboard/`, consistent suffixes: `View`, `Manager`, `ViewModel`

### File Template
```swift
// Imports: Foundation, SwiftUI
// File Purpose Header: Purpose, Dependencies, Usage, AI Notes
// Type Definitions: structs, classes, enums
// Extensions
// Helper Functions
```

---

## 📝 Docs

### Method

```swift
/// Description
/// - Parameters: ...
/// - Returns: ...
/// - Throws: ...
func methodName() -> ReturnType { /* Implementation */ }
```

### File Header

```swift
/// SessionManager.swift
/// Purpose: Session operations
/// Responsibilities: lifecycle, CSV, validation, UI
/// Dependencies: file, CSV, data parser, project manager
/// AI Notes: projectID, migration, notifications, @MainActor
```

---

## 🚨 Error Handling Patterns

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

---

## 🧵 Threading and Concurrency

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

---

## 🎯 State Management

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

---

## 🧪 Testing Guidelines

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

---

## ⚡ Performance Best Practices

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

---

## 🏗️ Code Organization

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

---

## 🔧 Common Patterns

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

This documentation provides essential coding conventions for maintaining consistency and quality in the Juju codebase.