import Foundation

// MARK: - Async File Manager for thread-safe file operations
actor SessionFileManager {
    private let fileQueue = DispatchQueue(label: "com.juju.sessionfile", qos: .userInitiated, attributes: .concurrent)
    private let fileManager = FileManager.default
    
    func writeToFile(_ content: String, to url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            fileQueue.async(flags: .barrier) {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func appendToFile(_ content: String, to url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            fileQueue.async(flags: .barrier) {
                do {
                    let fileHandle = try FileHandle(forWritingTo: url)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(content.data(using: .utf8)!)
                    fileHandle.closeFile()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func readFromFile(_ url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            fileQueue.sync {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    continuation.resume(returning: content)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func ensureDirectoryExists(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
    
    func isFileEmpty(at url: URL) -> Bool {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            return fileSize == 0
        } catch {
            return true
        }
    }
    
    // MARK: - Year-Based File Operations
    
    /// Get the data file URL for a specific year
    /// - Parameter year: The year (e.g., 2024)
    /// - Returns: URL for the year-based data file (e.g., "2024-data.csv")
    nonisolated func getDataFileURL(for year: Int, in jujuPath: URL) -> URL {
        let fileName = "\(year)-data.csv"
        return jujuPath.appendingPathComponent(fileName)
    }
    
    /// Check if a file has a header (first line contains column names)
    func fileHasHeader(at url: URL) async -> Bool {
        do {
            let content = try await readFromFile(url)
            let lines = content.components(separatedBy: .newlines)
            guard let firstLine = lines.first, !firstLine.isEmpty else {
                return false
            }
            // Check if first line looks like a CSV header (contains common column names)
            let headerKeywords = ["id", "date", "start_time", "end_time", "duration", "project"]
            let lowercased = firstLine.lowercased()
            return headerKeywords.contains { lowercased.contains($0) }
        } catch {
            return false
        }
    }
    
    /// List all available year files in the Juju directory
    /// - Parameter jujuPath: The base Juju application support directory
    /// - Returns: Sorted array of years that have data files
    nonisolated func getAvailableYears(in jujuPath: URL) -> [Int] {
        guard let contents = try? fileManager.contentsOfDirectory(at: jujuPath, includingPropertiesForKeys: [.nameKey], options: []) else {
            return []
        }
        
        let yearFiles = contents.filter { url in
            let fileName = url.lastPathComponent
            return fileName.hasSuffix("-data.csv") && fileName.count == 13 // "YYYY-data.csv" = 13 chars
        }
        
        let years = yearFiles.compactMap { url -> Int? in
            let fileName = url.lastPathComponent
            let yearString = String(fileName.prefix(4)) // Extract "YYYY" from "YYYY-data.csv"
            return Int(yearString)
        }
        
        return years.sorted()
    }
    
    /// Check if legacy data.csv file exists
    func legacyFileExists(in jujuPath: URL) -> Bool {
        let legacyURL = jujuPath.appendingPathComponent("data.csv")
        return fileExists(at: legacyURL)
    }
    
    /// Check if any year-based files exist
    func yearFilesExist(in jujuPath: URL) -> Bool {
        return !getAvailableYears(in: jujuPath).isEmpty
    }
}

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
