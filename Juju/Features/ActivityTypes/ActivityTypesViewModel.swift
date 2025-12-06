import Foundation
import SwiftUI

class ActivityTypesViewModel: ObservableObject {
    static let shared = ActivityTypesViewModel()
    
    @Published var activityTypes: [ActivityType] = []
    @Published var searchText: String = ""
    
    init() {
        loadActivityTypes()
    }
    
    var filteredActivityTypes: [ActivityType] {
        if searchText.isEmpty {
            return activityTypes.sorted { $0.name < $1.name }
        } else {
            let lowercasedSearch = searchText.lowercased()
            return activityTypes.filter { activityType in
                activityType.name.lowercased().contains(lowercasedSearch) ||
                activityType.description.lowercased().contains(lowercasedSearch)
            }.sorted { $0.name < $1.name }
        }
    }
    
    func loadActivityTypes() {
        activityTypes = ActivityTypeManager.shared.loadActivityTypes()
    }
    
    func addActivityType(name: String, emoji: String, description: String = "") {
        let newActivityType = ActivityType(
            id: UUID().uuidString,
            name: name,
            emoji: emoji,
            description: description,
            archived: false
        )
        ActivityTypeManager.shared.addActivityType(newActivityType)
        loadActivityTypes()
    }
    
    func updateActivityType(_ activityType: ActivityType) {
        ActivityTypeManager.shared.updateActivityType(activityType)
        loadActivityTypes()
    }
    
    func deleteActivityType(_ activityType: ActivityType) {
        // Prevent deletion of uncategorized fallback
        guard activityType.id != "uncategorized" else { return }
        ActivityTypeManager.shared.deleteActivityType(id: activityType.id)
        loadActivityTypes()
    }
    
    func toggleArchive(_ activityType: ActivityType) {
        let updated = ActivityType(
            id: activityType.id,
            name: activityType.name,
            emoji: activityType.emoji,
            description: activityType.description,
            archived: !activityType.archived
        )
        updateActivityType(updated)
    }
}
