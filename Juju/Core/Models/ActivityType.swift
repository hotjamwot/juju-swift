import Foundation

// MARK: - Activity Type Model
struct ActivityType: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var emoji: String
    var description: String
    var archived: Bool
    
    init(id: String, name: String, emoji: String, description: String = "", archived: Bool = false) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.description = description
        self.archived = archived
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
                
                // Check if migration is needed (old format without description/archived)
                let needsMigration = loadedTypes.contains { type in
                    type.description.isEmpty || type.archived != type.archived
                }
                
                if needsMigration {
                    print("🔄 Migrating activity types to new schema...")
                    let migratedTypes = migrateActivityTypes(loadedTypes)
                    return migratedTypes
                }
                
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
    
    // MARK: - Activity Type Archiving Management
    
    /// Archive or unarchive an activity type
    func setActivityTypeArchived(_ archived: Bool, for activityTypeID: String) {
        var types = loadActivityTypes()
        if let activityTypeIndex = types.firstIndex(where: { $0.id == activityTypeID }) {
            var activityType = types[activityTypeIndex]
            activityType.archived = archived
            types[activityTypeIndex] = activityType
            saveActivityTypes(types)
        }
    }
    
    /// Get active activity types (non-archived)
    func getActiveActivityTypes() -> [ActivityType] {
        let types = loadActivityTypes()
        return types.filter { !$0.archived }
    }
    
    /// Get archived activity types
    func getArchivedActivityTypes() -> [ActivityType] {
        let types = loadActivityTypes()
        return types.filter { $0.archived }
    }
    
    /// Get all activity types (including archived)
    func getAllActivityTypes() -> [ActivityType] {
        return loadActivityTypes()
    }
    
    // MARK: - Migration Logic
    
    /// Migrate existing activity types to include new fields
    private func migrateActivityTypes(_ loadedTypes: [ActivityType]) -> [ActivityType] {
        var needsRewrite = false
        var migratedTypes: [ActivityType] = []
        
        for type in loadedTypes {
            // Check if type needs migration (missing description or archived fields)
            if type.description.isEmpty || type.archived != type.archived {
                // Create migrated version with default values
                let migratedType = ActivityType(
                    id: type.id,
                    name: type.name,
                    emoji: type.emoji,
                    description: type.description.isEmpty ? "" : type.description,
                    archived: type.archived
                )
                migratedTypes.append(migratedType)
                needsRewrite = true
            } else {
                migratedTypes.append(type)
            }
        }
        
        if needsRewrite {
            print("Activity types migrated, rewriting file with new schema")
            saveActivityTypes(migratedTypes)
        }
        
        return migratedTypes
    }
    
    // MARK: - Default Activity Types
    
    private func createDefaultActivityTypes() -> [ActivityType] {
        let defaults = [
            ActivityType(id: "uncategorized", name: "Uncategorized", emoji: "📝", description: "Fallback for legacy sessions without activity type", archived: false), // Fallback for legacy data
            ActivityType(id: "writing", name: "Writing", emoji: "✍️", description: "Drafting and creating new content", archived: false),
            ActivityType(id: "outlining", name: "Outlining / Brainstorming", emoji: "🧠", description: "Planning and organizing ideas", archived: false),
            ActivityType(id: "editing", name: "Editing / Rewriting", emoji: "✂️", description: "Refining and improving existing content", archived: false),
            ActivityType(id: "collaborating", name: "Collaborating", emoji: "🤝", description: "Working with others", archived: false),
            ActivityType(id: "production", name: "Production Prep / Organising", emoji: "🎬", description: "Preparing for production and organization", archived: false),
            ActivityType(id: "coding", name: "Coding", emoji: "💻", description: "Writing and debugging code", archived: false),
            ActivityType(id: "admin", name: "Admin", emoji: "🗂️", description: "Administrative tasks and organization", archived: false),
            ActivityType(id: "maintenance", name: "Maintenance", emoji: "🧽", description: "Maintenance and cleanup tasks", archived: false)
        ]
        print("Created default activity types")
        saveActivityTypes(defaults)
        return defaults
    }
    
    // MARK: - Helper Methods for Legacy Data
    
    /// Get the "Uncategorized" activity type (fallback for legacy sessions)
    func getUncategorizedActivityType() -> ActivityType {
        let types = loadActivityTypes()
        return types.first { $0.id == "uncategorized" } ?? ActivityType(id: "uncategorized", name: "Uncategorized", emoji: "📝", description: "Fallback for legacy sessions without activity type", archived: false)
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
