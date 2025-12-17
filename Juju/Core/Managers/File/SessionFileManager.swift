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
                    let data = try Data(contentsOf: url)
                    
                    // Try UTF-8 first
                    if let content = String(data: data, encoding: .utf8) {
                        continuation.resume(returning: content)
                        return
                    }
                    
                    // Try lossy UTF-8 conversion as fallback
                    let lossyContent = String(decoding: data, as: UTF8.self)
                    continuation.resume(returning: lossyContent)
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
