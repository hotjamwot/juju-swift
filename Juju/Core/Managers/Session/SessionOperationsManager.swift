import Foundation

// MARK: - Session Operations Manager
class SessionOperationsManager: ObservableObject {
    // Session state
    @Published var isSessionActive = false
    @Published var currentProjectName: String?
    @Published var sessionStartTime: Date?
    @Published var lastUpdated = Date()
    
    private let sessionFileManager: SessionFileManager
    private let csvManager: SessionCSVManager
    private let parser: SessionDataParser
    private let dataFileURL: URL
    
    init(sessionFileManager: SessionFileManager, dataFileURL: URL) {
        self.sessionFileManager = sessionFileManager
        self.dataFileURL = dataFileURL
        self.csvManager = SessionCSVManager(fileManager: sessionFileManager, dataFileURL: dataFileURL)
        self.parser = SessionDataParser()
        
        // Ensure data directory exists
        try? csvManager.ensureDataDirectoryExists()
    }
    
    // MARK: - Session State Management
    
    func startSession(for projectName: String) {
        guard !isSessionActive else {
            print("⚠️ Session already active")
            return
        }
        
        print("✅ Starting session for project: \(projectName)")
        isSessionActive = true
        currentProjectName = projectName
        sessionStartTime = Date()
    }
    
    func endSession(notes: String = "", mood: Int? = nil, completion: @escaping (Bool) -> Void) {
        guard isSessionActive, let projectName = currentProjectName, let startTime = sessionStartTime else {
            print("⚠️ No active session to end")
            completion(false)
            return
        }
        
        let endTime = Date()
        let durationMs = endTime.timeIntervalSince(startTime)
        let durationMinutes = Int(round(durationMs / 60))
        
        print("✅ Ending session for \(projectName) - Duration: \(durationMinutes) minutes")
        
        // Create session data
        let sessionData = SessionData(
            startTime: startTime,
            endTime: endTime,
            durationMinutes: durationMinutes,
            projectName: projectName,
            notes: notes
        )
        
        // Save to CSV with file locking
        saveSessionToCSV(sessionData, mood: mood) { [weak self] success in
            guard let self = self else { 
                completion(false)
                return 
            }
            
            if success {
                // Notify that session ended
                NotificationCenter.default.post(name: .sessionDidEnd, object: nil)
                
                // Update timestamp to trigger UI refresh
                self.lastUpdated = Date()
                
                // Reset state
                self.isSessionActive = false
                self.currentProjectName = nil
                self.sessionStartTime = nil
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
        
        let csvRow = "\(id),\(date),\(startTime),\(endTime),\(sessionData.durationMinutes),\(csvManager.csvEscape(sessionData.projectName)),\(csvManager.csvEscape(sessionData.notes)),\(moodStr)\n"
        
        // Check if file exists and needs header
        let needsHeader = !FileManager.default.fileExists(atPath: dataFileURL.path) || 
                         (FileManager.default.fileExists(atPath: dataFileURL.path) && 
                          (try? FileManager.default.attributesOfItem(atPath: dataFileURL.path)[.size] as? Int64) ?? 0 == 0)
        
        let contentToWrite = needsHeader ? 
            "id,date,start_time,end_time,duration_minutes,project,notes,mood\n" + csvRow : csvRow
        
        Task {
            do {
                if needsHeader {
                    try await csvManager.writeToFile(contentToWrite)
                    print("✅ Created new CSV file with header and session data (with IDs and mood)")
                } else {
                    try await csvManager.appendToFile(csvRow)
                    print("✅ Appended session data to existing CSV file (with ID and mood)")
                }
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
