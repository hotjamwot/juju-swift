import Foundation
import SwiftUI

// MARK: - Sidebar Content Types
enum SidebarContent: Identifiable {
    case project(Project)
    case activityType(ActivityType)
    case newProject(Project)  // Store the actual project instance
    case newActivityType(ActivityType)  // Store the actual activity type instance
    
    var id: String {
        switch self {
        case .project(let project):
            return "project-\(project.id)"
        case .activityType(let activityType):
            return "activityType-\(activityType.id)"
        case .newProject(let project):
            return "new-project-\(project.id)"
        case .newActivityType(let activityType):
            return "new-activity-type-\(activityType.id)"
        }
    }
}

// MARK: - Sidebar State Manager
final class SidebarStateManager: ObservableObject {
    @Published var isVisible = false
    @Published var content: SidebarContent? = nil
    
    func show(_ content: SidebarContent) {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.content = content
            self.isVisible = true
        }
    }
    
    func show(_ content: SidebarContent, onSessionUpdated: (() -> Void)? = nil) {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.content = content
            self.isVisible = true
        }
    }
    
    func hide() {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.isVisible = false
        }
        // Clear content after animation completes - use 0.35s to ensure animation finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.content = nil
        }
    }
}
