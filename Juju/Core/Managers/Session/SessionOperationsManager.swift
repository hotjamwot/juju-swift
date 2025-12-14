import Foundation

// MARK: - Session Operations Manager
class SessionOperationsManager: ObservableObject {
    // Session state
    @Published var isSessionActive = false
    @Published var currentProjectName: String?  // Kept for backward compatibility
    @Published var currentProjectID: String?  // New: Project identifier stored from session start
    @Published var currentActivityTypeID: String?  // New: Activity Type (nil during active session, set at end)
    @Published var currentProjectPhaseID: String?  // New: Project Phase (nil during active session, set at end)
    @Published var sessionStartTime: Date?
    @Published var lastUpdated = Date()
    
    private let sessionFileManager: SessionFileManager
    private let csvManager: SessionCSVManager
    private let parser: SessionDataParser
    private let jujuPath: URL
    private let dataFileURL: URL? // Kept for backward compatibility during migration
    
    init(sessionFileManager: SessionFileManager, dataFileURL: URL) {
        self.sessionFileManager = sessionFileManager
        self.jujuPath = dataFileURL.deletingLastPathComponent()
        self.dataFileURL = dataFileURL // Keep for backward compatibility
        
        // Initialize CSV manager with jujuPath for year-based file support
        self.csvManager = SessionCSVManager(fileManager: sessionFileManager, jujuPath: jujuPath)
        self.parser = SessionDataParser()
        
        // Ensure data directory exists
        csvManager.ensureDataDirectoryExists()
    }
    
    // MARK: - Session State Management
    
    func startSession(for projectName: String, projectID: String? = nil) {
        guard !isSessionActive else {
            print("⚠️ Session already active")
            return
        }
        
        print("✅ Starting session for project: \(projectName) (ID: \(projectID ?? "nil"))")
        isSessionActive = true
        currentProjectName = projectName
        currentProjectID = projectID  // Store projectID from the beginning
        currentActivityTypeID = nil  // Will be set at session end
        currentProjectPhaseID = nil  // Will be set at session end
        sessionStartTime = Date()
        
        // Notify that session started
        NotificationCenter.default.post(name: .sessionDidStart, object: nil)
    }
    
    func endSession(
        notes: String = "",
        mood: Int? = nil,
        activityTypeID: String? = nil,
        projectPhaseID: String? = nil,
        milestoneText: String? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        guard isSessionActive, let projectName = currentProjectName, let startTime = sessionStartTime else {
            print("⚠️ No active session to end")
            completion(false)
            return
        }
        
        let endTime = Date()
        let durationMs = endTime.timeIntervalSince(startTime)
        let durationMinutes = Int(round(durationMs / 60))
        
        print("✅ Ending session for \(projectName) - Duration: \(durationMinutes) minutes")
        print("   Activity: \(activityTypeID ?? "none"), Phase: \(projectPhaseID ?? "none"), Milestone: \(milestoneText ?? "none")")
        
        // Create session data with new fields
        guard let projectID = currentProjectID else {
            print("❌ Cannot end session: projectID is nil")
            completion(false)
            return
        }
        
        let sessionData = SessionData(
            startTime: startTime,
            endTime: endTime,
            durationMinutes: durationMinutes,
            projectName: projectName,
            projectID: projectID,
            activityTypeID: activityTypeID,
            projectPhaseID: projectPhaseID,
            milestoneText: milestoneText,
            notes: notes
        )
        
        // Save to CSV with file locking
        saveSessionToCSV(sessionData, mood: mood) { [weak self] success in
            guard let self = self else { 
                completion(false)
                return 
            }
            
            if success {
                // Reset state first
                self.isSessionActive = false
                self.currentProjectName = nil
                self.currentProjectID = nil
                self.currentActivityTypeID = nil
                self.currentProjectPhaseID = nil
                self.sessionStartTime = nil
                
                // Update timestamp to trigger UI refresh
                self.lastUpdated = Date()
                
                // Notify that session ended (after state is reset)
                NotificationCenter.default.post(name: .sessionDidEnd, object: nil)
            }
            
            completion(success)
        }
    }
    
    func getCurrentSessionDuration() -> String {
        guard isSessionActive, let startTime = sessionStartTime else {
            return "0h 0m"
        }
        
        let durationMs = Date().timeIntervalSince(startTime)
        let totalSeconds = Int(durationMs)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        return "\(hours)h \(minutes)m"
    }
    
    // MARK: - Session Data Operations
    
    func updateSession(id: String, field: String, value: String) -> Bool {
        // This will be called from the main SessionManager after loading sessions
        // For now, we'll return true to indicate the operation should proceed
        return true
    }
    
    func deleteSession(id: String) -> Bool {
        // This will be called from the main SessionManager after loading sessions
        // For now, we'll return true to indicate the operation should proceed
        return true
    }
    
    // MARK: - CSV Operations
    
    private func saveSessionToCSV(_ sessionData: SessionData, mood: Int? = nil, completion: @escaping (Bool) -> Void) {
        // Format the CSV row
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let date = dateFormatter.string(from: sessionData.startTime)
        let startTime = timeFormatter.string(from: sessionData.startTime)
        let endTime = timeFormatter.string(from: sessionData.endTime)
        let id = UUID().uuidString
        let moodStr = mood.map { String($0) } ?? ""
        
        // Build CSV row with new fields
        let projectID = csvManager.csvEscape(sessionData.projectID)
        let activityTypeID = sessionData.activityTypeID.map { csvManager.csvEscape($0) } ?? ""
        let projectPhaseID = sessionData.projectPhaseID.map { csvManager.csvEscape($0) } ?? ""
        let milestoneText = sessionData.milestoneText.map { csvManager.csvEscape($0) } ?? ""
        
        let csvRow = "\(id),\(date),\(startTime),\(endTime),\(sessionData.durationMinutes),\(csvManager.csvEscape(sessionData.projectName)),\(projectID),\(activityTypeID),\(projectPhaseID),\(milestoneText),\(csvManager.csvEscape(sessionData.notes)),\(moodStr)\n"
        
        // Determine year from session start date (use start_date.year, not end_date)
        let year = Calendar.current.component(.year, from: sessionData.startTime)
        
        Task {
            do {
                // Use year-based file system: append to the appropriate year file
                // The appendToYearFile method handles header checking automatically
                try await csvManager.appendToYearFile(csvRow, for: year)
                print("✅ Appended session data to \(year)-data.csv file")
                
                await MainActor.run {
                    completion(true)
                }
            } catch {
                print("❌ Error writing to CSV file: \(error)")
                await MainActor.run {
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Utility Functions
    
    func minutesBetween(start: String, end: String) -> Int {
        // Accept "HH:mm" or "HH:mm:ss"; if seconds are missing we'll pad them.
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        // Pad missing seconds so the formatter can parse it
        let paddedStart = start.count == 5 ? start + ":00" : start
        let paddedEnd   = end.count   == 5 ? end   + ":00" : end

        guard
            let startDate = formatter.date(from: paddedStart),
            let endDate   = formatter.date(from: paddedEnd)
        else { return 0 }

        let diff = endDate.timeIntervalSince(startDate)
        return Int(round(diff / 60))   // minutes
    }
}
