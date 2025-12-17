import Foundation
import SwiftUI

// MARK: - Phase Structure
struct Phase: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var order: Int
    var archived: Bool
    
    init(id: String = UUID().uuidString, name: String, order: Int = 0, archived: Bool = false) {
        self.id = id
        self.name = name
        self.order = order
        self.archived = archived
    }
}

// Project structure to match the original app
struct Project: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var color: String
    var about: String?
    var order: Int
    var emoji: String
    var archived: Bool 
    var phases: [Phase]
    
    // Computed properties for session statistics (using cache)
    var totalDurationHours: Double {
        // Try to get from cache first
        let cachedDuration = ProjectStatisticsCache.shared.getTotalDuration(for: id)
        if cachedDuration > 0 {
            return cachedDuration
        }
        
        // If not in cache or cache expired, compute and cache it
        // Use a safe access pattern to avoid crashes
        let sessionManager = SessionManager.shared
        let totalDuration = sessionManager.allSessions
            .filter { $0.projectID == id }
            .reduce(0) { total, session in
                total + Double(session.endDate.timeIntervalSince(session.startDate) / 60.0) / 60.0
            }
        ProjectStatisticsCache.shared.setTotalDuration(totalDuration, for: id)
        return totalDuration
    }
    
    var lastSessionDate: Date? {
        // Try to get from cache first
        if let cachedDate = ProjectStatisticsCache.shared.getLastSessionDate(for: id) {
            return cachedDate
        }
        
        // If not in cache or cache expired, compute and cache it
        // Use a safe access pattern to avoid crashes
        let sessionManager = SessionManager.shared
        let sessions = sessionManager.allSessions
            .filter { $0.projectID == id }
            .compactMap { $0.startDate }
        let date = sessions.max()
        ProjectStatisticsCache.shared.setLastSessionDate(date, for: id)
        return date
    }
    
    // MARK: - Background Session Counting
    
    /// Update session statistics asynchronously in the background
    /// This is a static method to avoid mutating self on a let constant
    static func updateSessionStatistics(for project: Project) -> Project {
        Task {
            // Compute total duration and last session date in background
            let sessions = SessionManager.shared.allSessions
            let filteredSessions = sessions.filter { $0.projectID == project.id }
            let totalDuration = filteredSessions.reduce(0) { total, session in
                total + Double(session.endDate.timeIntervalSince(session.startDate) / 60.0) / 60.0
            }
            let lastDate = filteredSessions.compactMap { $0.startDate }.max()
            
            // Update cached values on main thread
            await MainActor.run {
                // Since we can't mutate the struct directly, we'll rely on the computed properties
                // The caching will happen naturally when the properties are accessed
                NotificationCenter.default.post(name: .projectsDidChange, object: nil)
            }
        }
        
        // Return the project as-is since we can't mutate it directly
        return project
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, about, order, emoji, archived, phases
    }
    
    // Computed SwiftUI Color from hex string (avoids storing Color)
    var swiftUIColor: Color {
        Color(hex: color)
    }
    
    init(name: String, color: String = "#4E79A7", about: String? = nil, order: Int = 0, emoji: String = "📁", phases: [Phase] = []) {
        self.id = UUID().uuidString
        self.name = name
        self.color = color
        self.about = about
        self.order = order
        self.emoji = emoji
        self.archived = false
        self.phases = phases
    }
    
    init(id: String, name: String, color: String, about: String?, order: Int, emoji: String = "📁", phases: [Phase] = []) {
        self.id = id
        self.name = name
        self.color = color
        self.about = about
        self.order = order
        self.emoji = emoji
        self.archived = false
        self.phases = phases
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#4E79A7"
        about = try container.decodeIfPresent(String.self, forKey: .about)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "📁"
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived) ?? false  // Default to false for legacy projects
        phases = try container.decodeIfPresent([Phase].self, forKey: .phases) ?? []  // Default to empty array for legacy projects
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color, forKey: .color)
        try container.encodeIfPresent(about, forKey: .about)
        try container.encode(order, forKey: .order)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(archived, forKey: .archived)
        try container.encode(phases, forKey: .phases)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}
