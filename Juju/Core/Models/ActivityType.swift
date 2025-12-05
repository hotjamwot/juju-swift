import Foundation

// MARK: - Activity Type Model
struct ActivityType: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    
    init(id: String, name: String, emoji: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
    }
}

// MARK: - Activity Type Manager
class ActivityTypeManager {
    static let shared = ActivityTypeManager()
    
    private let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    private let jujuPath: URL?
    private let activityTypesFile: URL?
    
    private init() {
        self.jujuPath = appSupportPath?.appendingPathComponent("Juju")
        self.activityTypesFile = jujuPath?.appendingPathComponent("activityTypes.json")
    }
    
    // MARK: - Load Activity Types
    
    func loadActivityTypes() -> [ActivityType] {
        // Create directory if it doesn't exist
        if let jujuPath = jujuPath {
            try? FileManager.default.createDirectory(at: jujuPath, withIntermediateDirectories: true)
        }
        
        // Load activity types from file or create defaults
        if let activityTypesFile = activityTypesFile, FileManager.default.fileExists(atPath: activityTypesFile.path) {
            do {
                let data = try Data(contentsOf: activityTypesFile)
                let loadedTypes = try JSONDecoder().decode([ActivityType].self, from: data)
                print("Loaded \(loadedTypes.count) activity types from \(activityTypesFile.path)")
                return loadedTypes
            } catch {
                print("Error loading activity types: \(error)")
                print("Creating default activity types")
                return createDefaultActivityTypes()
            }
        } else {
            return createDefaultActivityTypes()
        }
    }
    
    // MARK: - Save Activity Types
    
    func saveActivityTypes(_ activityTypes: [ActivityType]) {
        if let activityTypesFile = activityTypesFile {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(activityTypes)
                try data.write(to: activityTypesFile)
                print("✅ Saved \(activityTypes.count) activity types to \(activityTypesFile.path)")
            } catch {
                print("❌ Error saving activity types to \(activityTypesFile.path): \(error)")
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    func addActivityType(_ activityType: ActivityType) {
        var types = loadActivityTypes()
        types.append(activityType)
        saveActivityTypes(types)
    }
    
    func updateActivityType(_ activityType: ActivityType) {
        var types = loadActivityTypes()
        if let index = types.firstIndex(where: { $0.id == activityType.id }) {
            types[index] = activityType
            saveActivityTypes(types)
        }
    }
    
    func deleteActivityType(id: String) {
        var types = loadActivityTypes()
        types.removeAll { $0.id == id }
        saveActivityTypes(types)
    }
    
    func getActivityType(id: String) -> ActivityType? {
        return loadActivityTypes().first { $0.id == id }
    }
    
    // MARK: - Default Activity Types
    
    private func createDefaultActivityTypes() -> [ActivityType] {
        let defaults = [
            ActivityType(id: "uncategorized", name: "Uncategorized", emoji: "📝"), // Fallback for legacy data
            ActivityType(id: "writing", name: "Writing", emoji: "✍️"),
            ActivityType(id: "outlining", name: "Outlining / Brainstorming", emoji: "🧠"),
            ActivityType(id: "editing", name: "Editing / Rewriting", emoji: "✂️"),
            ActivityType(id: "collaborating", name: "Collaborating", emoji: "🤝"),
            ActivityType(id: "production", name: "Production Prep / Organising", emoji: "🎬"),
            ActivityType(id: "coding", name: "Coding", emoji: "💻"),
            ActivityType(id: "admin", name: "Admin", emoji: "🗂️"),
            ActivityType(id: "maintenance", name: "Maintenance", emoji: "🧽")
        ]
        print("Created default activity types")
        saveActivityTypes(defaults)
        return defaults
    }
    
    // MARK: - Helper Methods for Legacy Data
    
    /// Get the "Uncategorized" activity type (fallback for legacy sessions)
    func getUncategorizedActivityType() -> ActivityType {
        let types = loadActivityTypes()
        return types.first { $0.id == "uncategorized" } ?? ActivityType(id: "uncategorized", name: "Uncategorized", emoji: "📝")
    }
    
    /// Get activity type display info, with fallback to "Uncategorized" for nil or missing IDs
    func getActivityTypeDisplay(id: String?) -> (name: String, emoji: String) {
        guard let id = id, let activityType = getActivityType(id: id) else {
            let uncategorized = getUncategorizedActivityType()
            return (uncategorized.name, uncategorized.emoji)
        }
        return (activityType.name, activityType.emoji)
    }
}

