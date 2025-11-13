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
}

// MARK: - CSV Operations Manager
class SessionCSVManager {
    private let fileManager: SessionFileManager
    private let dataFileURL: URL
    
    init(fileManager: SessionFileManager, dataFileURL: URL) {
        self.fileManager = fileManager
        self.dataFileURL = dataFileURL
    }
    
    // MARK: - File Operations
    
    func writeToFile(_ content: String) async throws {
        try await fileManager.writeToFile(content, to: dataFileURL)
    }
    
    func appendToFile(_ content: String) async throws {
        try await fileManager.appendToFile(content, to: dataFileURL)
    }
    
    func readFromFile() async throws -> String {
        try await fileManager.readFromFile(dataFileURL)
    }
    
    func ensureDataDirectoryExists() {
        Task {
            do {
                let directoryURL = dataFileURL.deletingLastPathComponent()
                if !directoryURL.path.isEmpty {
                    try await fileManager.ensureDirectoryExists(at: directoryURL)
                }
            } catch {
                print("❌ Error ensuring directory exists: \(error)")
            }
        }
    }
    
    // MARK: - File Status Methods (Async)
    
    func fileExists() async -> Bool {
        return await fileManager.fileExists(at: dataFileURL)
    }
    
    func isFileEmpty() async -> Bool {
        return await fileManager.isFileEmpty(at: dataFileURL)
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
