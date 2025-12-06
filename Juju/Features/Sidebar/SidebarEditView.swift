import SwiftUI

/// Main container for the right-hand sidebar that slides in from the right
/// when editing any entity (Sessions, Projects, Activity Types)
struct SidebarEditView: View {
    @EnvironmentObject var sidebarState: SidebarStateManager
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Background dimming (optional - keeping it subtle)
            if sidebarState.isVisible {
                Color.black.opacity(0.05)
                    .ignoresSafeArea()
                    .onTapGesture {
                        sidebarState.hide()
                    }
            }
            
            // Sidebar content
            if let content = sidebarState.content {
                sidebarContent(content)
                    .frame(width: 420)
                    .transition(.move(edge: .trailing))
                    .zIndex(1000)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sidebarState.isVisible)
    }
    
    @ViewBuilder
    private func sidebarContent(_ content: SidebarContent) -> some View {
        VStack(spacing: 0) {
            // Header with title and close button
            sidebarHeader(content)
            
            // Divider
            Divider()
                .padding(.horizontal)
            
            // Content area
            ScrollView {
                VStack(spacing: Theme.spacingMedium) {
                    switch content {
                    case .session(let session):
                        SessionSidebarEditView(session: session)
                    case .project(let project):
                        ProjectSidebarEditView(project: project)
                    case .activityType(let activityType):
                        ActivityTypeSidebarEditView(activityType: activityType)
                    case .newProject:
                        let newProject = Project(
                            id: UUID().uuidString,
                            name: "",
                            color: "#007AFF",
                            about: nil,
                            order: 0,
                            emoji: "📝",
                            phases: []
                        )
                        ProjectSidebarEditView(project: newProject)
                    case .newActivityType:
                        let newActivityType = ActivityType(
                            id: UUID().uuidString,
                            name: "",
                            emoji: "⚡",
                            description: "",
                            archived: false
                        )
                        ActivityTypeSidebarEditView(activityType: newActivityType)
                    }
                }
                .padding()
            }
        }
        .background(
            Theme.Colors.surface
                .blur(radius: 8)
                .opacity(0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Theme.Colors.divider, lineWidth: 1)
                .frame(width: 1)
                .offset(x: 0)
        )
        .offset(x: sidebarState.isVisible ? 0 : 420)
    }
    
    private func sidebarHeader(_ content: SidebarContent) -> some View {
        HStack {
            Text(sidebarTitle(for: content))
                .font(.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
            
            Button(action: {
                sidebarState.hide()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Theme.Colors.surface)
    }
    
    private func sidebarTitle(for content: SidebarContent) -> String {
        switch content {
        case .session:
            return "Edit Session"
        case .project:
            return "Edit Project"
        case .activityType:
            return "Edit Activity Type"
        case .newProject:
            return "New Project"
        case .newActivityType:
            return "New Activity Type"
        }
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SidebarEditView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            SidebarEditView()
                .environmentObject(SidebarStateManager())
        }
        .background(Color.gray.opacity(0.2))
    }
}
#endif
