import Foundation

// MARK: - CSV Operations Manager
class SessionCSVManager {
    private let fileManager: SessionFileManager
    private let jujuPath: URL
    private var dataFileURL: URL? // Optional for backward compatibility
    
    /// Initialize with a specific file URL (legacy mode)
    init(fileManager: SessionFileManager, dataFileURL: URL) {
        self.fileManager = fileManager
        self.dataFileURL = dataFileURL
        self.jujuPath = dataFileURL.deletingLastPathComponent()
    }
    
    /// Initialize with base path for year-based files
    init(fileManager: SessionFileManager, jujuPath: URL) {
        self.fileManager = fileManager
        self.jujuPath = jujuPath
        self.dataFileURL = nil
    }
    
    // MARK: - Year-Based File Operations
    
    /// Get the data file URL for a specific year
    func getDataFileURL(for year: Int) -> URL {
        return fileManager.getDataFileURL(for: year, in: jujuPath)
    }
    
    /// Get the data file URL for the current year
    func getCurrentYearFileURL() -> URL {
        let currentYear = Calendar.current.component(.year, from: Date())
        return getDataFileURL(for: currentYear)
    }
    
    /// Get the data file URL for a specific date (determines year from date)
    func getDataFileURL(for date: Date) -> URL {
        let year = Calendar.current.component(.year, from: date)
        return getDataFileURL(for: year)
    }
    
    /// Write content to a year-based file (creates file with header if needed)
    func writeToYearFile(_ content: String, for year: Int) async throws {
        let fileURL = getDataFileURL(for: year)
        try await fileManager.writeToFile(content, to: fileURL)
    }
    
    /// Append content to a year-based file (checks for header first)
    func appendToYearFile(_ content: String, for year: Int) async throws {
        let fileURL = getDataFileURL(for: year)
        
        // Check if file exists and has header
        let exists = await fileManager.fileExists(at: fileURL)
        let hasHeader = exists ? await fileManager.fileHasHeader(at: fileURL) : false
        
        if !exists || !hasHeader {
            // Need to write header + content
            let header = "id,date,start_time,end_time,duration_minutes,project,project_id,activity_type_id,project_phase_id,milestone_text,notes,mood\n"
            let contentWithHeader = hasHeader ? content : header + content
            try await fileManager.writeToFile(contentWithHeader, to: fileURL)
        } else {
            // Just append the row
            try await fileManager.appendToFile(content, to: fileURL)
        }
    }
    
    /// Read content from a year-based file
    func readFromYearFile(for year: Int) async throws -> String {
        let fileURL = getDataFileURL(for: year)
        return try await fileManager.readFromFile(fileURL)
    }
    
    /// Get all available years with data files
    func getAvailableYears() -> [Int] {
        return fileManager.getAvailableYears(in: jujuPath)
    }
    
    // MARK: - File Operations (Legacy Support)
    
    func writeToFile(_ content: String) async throws {
        if let url = dataFileURL {
            try await fileManager.writeToFile(content, to: url)
        } else {
            throw NSError(domain: "SessionCSVManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data file URL specified"])
        }
    }
    
    func appendToFile(_ content: String) async throws {
        if let url = dataFileURL {
            try await fileManager.appendToFile(content, to: url)
        } else {
            throw NSError(domain: "SessionCSVManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data file URL specified"])
        }
    }
    
    func readFromFile() async throws -> String {
        if let url = dataFileURL {
            return try await fileManager.readFromFile(url)
        } else {
            throw NSError(domain: "SessionCSVManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data file URL specified"])
        }
    }
    
    func ensureDataDirectoryExists() {
        Task {
            do {
                if !jujuPath.path.isEmpty {
                    try await fileManager.ensureDirectoryExists(at: jujuPath)
                }
            } catch {
                print("❌ Error ensuring directory exists: \(error)")
            }
        }
    }
    
    // MARK: - File Status Methods (Async)
    
    func fileExists() async -> Bool {
        if let url = dataFileURL {
            return await fileManager.fileExists(at: url)
        }
        return false
    }
    
    func isFileEmpty() async -> Bool {
        if let url = dataFileURL {
            return await fileManager.isFileEmpty(at: url)
        }
        return true
    }
    
    func fileExists(for year: Int) async -> Bool {
        let fileURL = getDataFileURL(for: year)
        return await fileManager.fileExists(at: fileURL)
    }
    
    // MARK: - CSV Parsing
    
    func parseCSVContent(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let fields = parseCSVLine(line)
            if !fields.isEmpty {
                rows.append(fields)
            }
        }
        
        return rows
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = 0
        
        while i < line.count {
            let char = line[line.index(line.startIndex, offsetBy: i)]
            
            if char == "\"" {
                if inQuotes {
                    // Check for escaped quote
                    if i + 1 < line.count && line[line.index(line.startIndex, offsetBy: i + 1)] == "\"" {
                        currentField += "\""
                        i += 1 // Skip next quote
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if char == "," && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                currentField = ""
            } else {
                currentField += String(char)
            }
            
            i += 1
        }
        
        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return fields
    }
    
    // MARK: - CSV Helpers
    
    func csvEscape(_ string: String) -> String {
        "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    
    func csvEscapeForExport(_ string: String) -> String {
        string.replacingOccurrences(of: "\"", with: "\"\"")
    }
}
