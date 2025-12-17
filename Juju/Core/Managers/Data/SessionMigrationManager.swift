import Foundation

// MARK: - Session Migration Manager
class SessionMigrationManager {
    private let sessionFileManager: SessionFileManager
    private let jujuPath: URL
    private let legacyFileURL: URL
    private let parser: SessionDataParser
    
    init(sessionFileManager: SessionFileManager, jujuPath: URL) {
        self.sessionFileManager = sessionFileManager
        self.jujuPath = jujuPath
        self.legacyFileURL = jujuPath.appendingPathComponent("data.csv")
        self.parser = SessionDataParser()
    }
    
    // MARK: - Migration Check
    
    /// Check if migration is necessary and perform it if needed
    /// Returns true if migration was performed, false if not needed or failed
    func migrateIfNecessary() async -> Bool {
        // Check if legacy file exists
        guard await sessionFileManager.fileExists(at: legacyFileURL) else {
            print("ℹ️ No legacy data.csv file found - migration not needed")
            return false
        }
        
        // Check if year files already exist
        let availableYears = await sessionFileManager.getAvailableYears(in: jujuPath)
        guard availableYears.isEmpty else {
            print("ℹ️ Year-based files already exist - migration not needed")
            return false
        }
        
        print("🔄 Starting migration from legacy data.csv to year-based files...")
        
        // Perform migration
        let success = await performMigration()
        
        if success {
            print("✅ Migration completed successfully!")
        } else {
            print("❌ Migration failed - legacy file preserved")
        }
        
        return success
    }
    
    // MARK: - Project ID Migration
    
    /// Migrate old sessions to assign project IDs based on project names
    /// This ensures that all sessions are properly associated with projects for accurate session counting
    func migrateSessionProjectIDs() async {
        let sessionManager = SessionManager.shared
        let projects = ProjectManager.shared.loadProjects()
        
        // Create a mapping of project names to project IDs for quick lookup
        var projectNameToID: [String: String] = [:]
        for project in projects {
            projectNameToID[project.name] = project.id
        }
        
        // Get all sessions that don't have a projectID
        let sessionsToUpdate = sessionManager.allSessions.filter { $0.projectID == nil }
        
        if sessionsToUpdate.isEmpty {
            print("✅ No sessions need project ID migration")
            return
        }
        
        print("🔄 Starting migration of \(sessionsToUpdate.count) sessions to assign project IDs...")
        
        // Find unique project names in sessions that don't have projectID
        let uniqueProjectNames = Set(sessionsToUpdate.map { $0.projectName })
        print("📊 Found \(uniqueProjectNames.count) unique project names in sessions without projectID")
        
        var migratedCount = 0
        var skippedCount = 0
        var createdProjects: [String] = []
        
        // Process each session
        for session in sessionsToUpdate {
            if let projectID = projectNameToID[session.projectName] {
                // Project exists, update session with projectID
                // First update the projectID field directly
                let projectIDSuccess = sessionManager.updateSession(id: session.id, field: "project_id", value: projectID)
                
                // Then update other fields if needed (this will preserve the projectID)
                // Convert Date objects to strings for the legacy updateSessionFull method
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm:ss"
                
                let dateStr = dateFormatter.string(from: session.startDate)
                let startTimeStr = timeFormatter.string(from: session.startDate)
                let endTimeStr = timeFormatter.string(from: session.endDate)
                
                let otherFieldsSuccess = sessionManager.updateSessionFull(
                    id: session.id,
                    date: dateStr,
                    startTime: startTimeStr,
                    endTime: endTimeStr,
                    projectName: session.projectName,
                    notes: session.notes,
                    mood: session.mood,
                    activityTypeID: session.activityTypeID,
                    projectPhaseID: session.projectPhaseID,
                    milestoneText: session.milestoneText
                )
                
                if projectIDSuccess || otherFieldsSuccess {
                    migratedCount += 1
                }
            } else {
                // Project doesn't exist in projects.json - create it
                print("⚠️ Creating new project for session: \(session.projectName)")
                
                let newProject = Project(
                    name: session.projectName,
                    color: "#808080", // Grey color
                    about: "Auto-created from session data",
                    order: 0,
                    emoji: "📁",
                    phases: []
                )
                
                ProjectManager.shared.addProject(newProject)
                createdProjects.append(session.projectName)
                
                // Update the mapping
                projectNameToID[session.projectName] = newProject.id
                
                // Update session with the new project
                // First update the projectID field directly
                let projectIDSuccess = sessionManager.updateSession(id: session.id, field: "project_id", value: newProject.id)
                
                // Then update other fields if needed (this will preserve the projectID)
                // Convert Date objects to strings for the legacy updateSessionFull method
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm:ss"
                
                let dateStr = dateFormatter.string(from: session.startDate)
                let startTimeStr = timeFormatter.string(from: session.startDate)
                let endTimeStr = timeFormatter.string(from: session.endDate)
                
                let otherFieldsSuccess = sessionManager.updateSessionFull(
                    id: session.id,
                    date: dateStr,
                    startTime: startTimeStr,
                    endTime: endTimeStr,
                    projectName: session.projectName,
                    notes: session.notes,
                    mood: session.mood,
                    activityTypeID: session.activityTypeID,
                    projectPhaseID: session.projectPhaseID,
                    milestoneText: session.milestoneText
                )
                
                if projectIDSuccess || otherFieldsSuccess {
                    migratedCount += 1
                }
            }
        }
        
        // Force save all sessions to ensure CSV files are updated
        print("💾 Saving all sessions to CSV files...")
        sessionManager.saveAllSessions(sessionManager.allSessions)
        
        print("✅ Migration complete: \(migratedCount) sessions updated, \(skippedCount) sessions skipped")
        if !createdProjects.isEmpty {
            print("🆕 Created \(createdProjects.count) new projects: \(createdProjects.joined(separator: ", "))")
        }
        
        // Notify that projects have changed to refresh any cached data (on main thread)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .projectsDidChange, object: nil)
        }
    }
    
    // MARK: - Migration Logic
    
    private func performMigration() async -> Bool {
        do {
            // Step 1: Parse entire legacy file into memory
            print("📖 Step 1: Reading legacy data.csv file...")
            let content = try await sessionFileManager.readFromFile(legacyFileURL)
            
            guard !content.isEmpty else {
                print("⚠️ Legacy file is empty - nothing to migrate")
                return true // Not an error, just nothing to do
            }
            
            let lines = content.components(separatedBy: .newlines)
            guard let headerLine = lines.first, !headerLine.isEmpty else {
                print("❌ Legacy file has no header - cannot migrate")
                return false
            }
            
            let hasIdColumn = headerLine.lowercased().contains("id")
            print("📊 Found \(lines.count - 1) data rows (header: \(hasIdColumn ? "with" : "without") ID column)")
            
            // Step 2: Parse all sessions
            print("📖 Step 2: Parsing sessions from legacy file...")
            let (allSessions, needsRewrite) = parser.parseSessionsFromCSV(content, hasIdColumn: hasIdColumn)
            
            guard !allSessions.isEmpty else {
                print("⚠️ No sessions found in legacy file - nothing to migrate")
                return true // Not an error
            }
            
            print("✅ Parsed \(allSessions.count) sessions")
            
            // Step 3: Group by session start_date.year (not end_date)
            print("📖 Step 3: Grouping sessions by year (based on start date)...")
            var sessionsByYear: [Int: [SessionRecord]] = [:]
            
            for session in allSessions {
                let startDate = session.startDate
                
                let year = Calendar.current.component(.year, from: startDate)
                if sessionsByYear[year] == nil {
                    sessionsByYear[year] = []
                }
                sessionsByYear[year]?.append(session)
            }
            
            print("✅ Grouped sessions into \(sessionsByYear.count) year(s): \(sessionsByYear.keys.sorted().map { String($0) }.joined(separator: ", "))")
            
            // Step 4: For each year: write year file with header + sessions
            print("📖 Step 4: Writing year-based files...")
            var writtenFiles: [Int] = []
            
            for (year, yearSessions) in sessionsByYear.sorted(by: { $0.key < $1.key }) {
                let csvContent = parser.convertSessionsToCSV(yearSessions)
                let yearFileURL = sessionFileManager.getDataFileURL(for: year, in: jujuPath)
                
                do {
                    try await sessionFileManager.writeToFile(csvContent, to: yearFileURL)
                    writtenFiles.append(year)
                    print("✅ Wrote \(yearSessions.count) sessions to \(year)-data.csv")
                } catch {
                    print("❌ Failed to write \(year)-data.csv: \(error)")
                    // Clean up any files we've written so far
                    await cleanupWrittenFiles(years: writtenFiles)
                    return false
                }
            }
            
            // Step 5: Sanity check - re-parse one year file to verify integrity
            print("📖 Step 5: Verifying migration integrity...")
            guard let firstYear = writtenFiles.first else {
                print("❌ No files were written - cannot verify")
                await cleanupWrittenFiles(years: writtenFiles)
                return false
            }
            
            let verificationSuccess = await verifyYearFile(year: firstYear, expectedCount: sessionsByYear[firstYear]?.count ?? 0)
            
            if !verificationSuccess {
                print("❌ Verification failed - migration may be incomplete")
                await cleanupWrittenFiles(years: writtenFiles)
                return false
            }
            
            // Step 6: If OK → delete legacy file, if NOT → keep legacy and abort
            print("📖 Step 6: Removing legacy data.csv file...")
            do {
                try FileManager.default.removeItem(at: legacyFileURL)
                print("✅ Legacy file removed successfully")
            } catch {
                print("⚠️ Warning: Could not remove legacy file: \(error)")
                print("⚠️ Migration completed but legacy file remains - you may want to remove it manually")
                // Don't fail migration if we can't delete the old file
            }
            
            print("✅ Migration completed successfully!")
            print("📊 Migrated \(allSessions.count) sessions across \(writtenFiles.count) year file(s)")
            
            return true
            
        } catch {
            print("❌ Migration error: \(error)")
            return false
        }
    }
    
    // MARK: - Verification & Cleanup
    
    private func verifyYearFile(year: Int, expectedCount: Int) async -> Bool {
        do {
            let yearFileURL = sessionFileManager.getDataFileURL(for: year, in: jujuPath)
            let content = try await sessionFileManager.readFromFile(yearFileURL)
            
            let lines = content.components(separatedBy: .newlines)
            guard let headerLine = lines.first, !headerLine.isEmpty else {
                print("❌ Verification failed: No header in \(year)-data.csv")
                return false
            }
            
            let hasIdColumn = headerLine.lowercased().contains("id")
            let (sessions, _) = parser.parseSessionsFromCSV(content, hasIdColumn: hasIdColumn)
            
            if sessions.count != expectedCount {
                print("❌ Verification failed: Expected \(expectedCount) sessions, found \(sessions.count) in \(year)-data.csv")
                return false
            }
            
            print("✅ Verification passed: \(sessions.count) sessions in \(year)-data.csv")
            return true
            
        } catch {
            print("❌ Verification failed: Could not read \(year)-data.csv: \(error)")
            return false
        }
    }
    
    private func cleanupWrittenFiles(years: [Int]) async {
        print("🧹 Cleaning up partially written files...")
        for year in years {
            let yearFileURL = sessionFileManager.getDataFileURL(for: year, in: jujuPath)
            try? FileManager.default.removeItem(at: yearFileURL)
            print("🗑️ Removed \(year)-data.csv")
        }
    }
}
