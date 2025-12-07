import Foundation
import SwiftUI

// MARK: - Sidebar Content Types
enum SidebarContent: Identifiable {
    case session(SessionRecord)
    case project(Project)
    case activityType(ActivityType)
    case newProject
    case newActivityType
    
    var id: String {
        switch self {
        case .session(let session):
            return "session-\(session.id)"
        case .project(let project):
            return "project-\(project.id)"
        case .activityType(let activityType):
            return "activityType-\(activityType.id)"
        case .newProject:
            return "new-project"
        case .newActivityType:
            return "new-activity-type"
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
        
        // Store the callback for session editing
        if case .session = content {
            // Store callback in a way that can be accessed by SessionSidebarEditView
            // We'll use a singleton approach for now
            SessionSidebarEditView.sharedSessionUpdatedCallback = onSessionUpdated
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
