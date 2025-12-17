import SwiftUI

struct ProjectsNativeView: View {
    @StateObject private var viewModel = ProjectsViewModel.shared
    @EnvironmentObject var sidebarState: SidebarStateManager
    
    @State private var showingAddProjectSheet = false
    @State private var selectedProjectForEdit: Project?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Theme.spacingMedium) {
                HStack {
                    Text("Projects")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer()
                }
            }
            .padding(.vertical, Theme.spacingLarge)
            .padding(.horizontal, Theme.spacingLarge)
            .background(Theme.Colors.background)

            // Projects List
            ScrollView {
                let shouldShowArchived = viewModel.showArchivedProjects && !viewModel.archivedProjects.isEmpty
                let hasAnyProjects = !viewModel.activeProjects.isEmpty || shouldShowArchived
                
                if !hasAnyProjects {
                    Text("No Projects Yet")
                        .foregroundColor(Theme.Colors.surface)
                        .padding(40)
                } else {
                    LazyVStack(spacing: Theme.spacingSmall) {
                        // Active Projects
                        if !viewModel.activeProjects.isEmpty {
                            ForEach(viewModel.activeProjects) { project in
                                Button(action: {
                                    sidebarState.show(.project(project))
                                }) {
                                    ProjectRowView(project: project)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Archived Projects (only show if toggle is enabled)
                        if shouldShowArchived {
                            ForEach(viewModel.archivedProjects) { project in
                                Button(action: {
                                    sidebarState.show(.project(project))
                                }) {
                                    ProjectRowView(project: project, isArchived: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .overlay(
            HStack(spacing: Theme.spacingSmall) {
                // Add Project button with accent color
                Button {
                    // Create a new project instance with empty ID to indicate it's new
                    let newProject = Project(
                        id: "",
                        name: "",
                        color: "#007AFF",
                        about: nil,
                        order: 0,
                        emoji: "📝",
                        phases: []
                    )
                    sidebarState.show(.newProject(newProject))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(Theme.Fonts.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.accentColor)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .pointingHandOnHover()
                .accessibilityLabel("Add Project")
                .accessibilityHint("Creates a new project")
                
                // Archive toggle button
                Button(action: {
                    viewModel.showArchivedProjects.toggle()
                }) {
                    Image(systemName: viewModel.showArchivedProjects ? "archivebox.fill" : "archivebox")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Theme.Colors.divider.opacity(0.3))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .pointingHandOnHover()
                .accessibilityLabel(viewModel.showArchivedProjects ? "Hide Archived Projects" : "Show Archived Projects")
                .accessibilityHint(viewModel.showArchivedProjects ? "Hides archived projects" : "Shows archived projects")
            }
            .padding(.bottom, Theme.spacingLarge)
            .padding(.leading, Theme.spacingLarge),
            alignment: .bottomLeading
        )
        .background(Theme.Colors.background)
        .onReceive(NotificationCenter.default.publisher(for: .projectsDidChange)) { _ in
            // Refresh projects when they change
            Task {
                await viewModel.loadProjects()
            }
        }
    }
}

struct ProjectRowView: View {
    let project: Project
    var isArchived: Bool = false
    @EnvironmentObject var sidebarState: SidebarStateManager
    
    // Hover state for interactive feedback
    @State private var isHovering = false
    @State private var isExpanded = false
    
    // Get current phase from most recent session
    private var currentPhase: Phase? {
        let sessionManager = SessionManager.shared
        let sessions = sessionManager.allSessions
            .filter { $0.projectName == project.name }
            .sorted { $0.startDate > $1.startDate }
        
        guard let mostRecentSession = sessions.first,
              let phaseID = mostRecentSession.projectPhaseID else {
            return nil
        }
        
        return project.phases.first { $0.id == phaseID && !$0.archived }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row content - compact design
            HStack(spacing: Theme.Row.compactSpacing) {
                // Project color dot
                Circle()
                    .fill(project.swiftUIColor)
                    .frame(width: Theme.Row.projectDotSize, height: Theme.Row.projectDotSize)
                    .padding(.leading, Theme.Row.contentPadding)
                
                // Project emoji
                Text(project.emoji)
                    .font(.system(size: 12))
                    .frame(width: 20, alignment: .leading)
                
                // Project details (horizontal layout with flexible spacing)
                HStack(spacing: Theme.Row.compactSpacing) {
                    // Project name (flexible width with minimum)
                    Text(project.name)
                        .font(Theme.Fonts.body.weight(.semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .frame(minWidth: 120, maxWidth: 240)
                    
                    // Project about/description (flexible width - more space)
                    if let about = project.about, !about.isEmpty {
                        Text(about)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                            .frame(minWidth: 240, maxWidth: 400, alignment: .leading)
                    } else {
                        // Empty space when no description
                        Spacer().frame(minWidth: 240, maxWidth: 400)
                    }
                }
                
                Spacer()
                
                // Total duration capsule
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text("\(String(format: "%.1f", project.totalDurationHours))h total")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.divider.opacity(0.3))
                .clipShape(Capsule())
                .frame(width: 120)
                
                // Current phase from most recent session (moved to right side)
                if let currentPhase = currentPhase {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(project.swiftUIColor.opacity(0.9))
                        Text(currentPhase.name)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(project.swiftUIColor.opacity(0.1))
                    .clipShape(Capsule())
                    .frame(width: 140)
                } else {
                    // Empty space when no current phase
                    Spacer().frame(width: 140)
                }
                
                // Archived status or actions (moved to far right)
                if isArchived {
                    HStack(spacing: 8) {
                        Text("Archived")
                            .font(Theme.Fonts.caption.weight(.semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.divider.opacity(0.3))
                            .clipShape(Capsule())
                        
                        Button(action: {
                            // Restore project
                            Task {
                                await ProjectsViewModel.shared.unarchiveProject(project)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 10))
                                Text("Restore")
                                    .font(Theme.Fonts.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.divider.opacity(0.3))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .pointingHandOnHover()
                    }
                    .frame(maxWidth: 160)
                } else {
                        HStack(spacing: 8) {
                            Button(action: {
                                sidebarState.show(.project(project))
                            }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.Colors.divider.opacity(0.3))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandOnHover()
                            .accessibilityLabel("Edit Project")
                            .accessibilityHint("Opens the project editor")
                            
                            Button(action: {
                                Task {
                                    await ProjectsViewModel.shared.archiveProject(project)
                                }
                            }) {
                                Image(systemName: "archivebox")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.Colors.divider.opacity(0.3))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandOnHover()
                            .accessibilityLabel("Archive Project")
                            .accessibilityHint("Archives this project")
                        }
                    .frame(maxWidth: 160)
                }
            }
            .frame(height: Theme.Row.height)
            .background(
                isHovering ? Theme.Colors.surface.opacity(0.9) : Theme.Colors.surface.opacity(0.7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Row.cornerRadius)
                    .stroke(Theme.Colors.divider, lineWidth: 1)
            )
            .cornerRadius(Theme.Row.cornerRadius)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                if !isArchived {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }
            
            // Expanded state - project details (only show when expanded for active projects)
            if isExpanded && !isArchived {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .background(Theme.Colors.divider)
                    
                    // Create a two-column layout: 80% details, 20% actions
                    HStack(alignment: .top, spacing: 0) {
                        // Details Column (80%)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Project Details")
                                    .font(Theme.Fonts.caption.weight(.semibold))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                
                                Spacer()
                            }
                            
                            // Project description
                            if let about = project.about, !about.isEmpty {
                                Text(about)
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("No description provided")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Phases list
                            if !project.phases.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Phases:")
                                        .font(Theme.Fonts.caption.weight(.semibold))
                                        .foregroundColor(Theme.Colors.textSecondary)
                                    
                                    ForEach(project.phases.filter { !$0.archived }) { phase in
                                        HStack {
                                            Circle()
                                                .fill(project.swiftUIColor)
                                                .frame(width: 8, height: 8)
                                            Text(phase.name)
                                                .font(Theme.Fonts.caption)
                                                .foregroundColor(Theme.Colors.textPrimary)
                                            Spacer()
                                            if phase.archived {
                                                Text("Archived")
                                                    .font(Theme.Fonts.caption)
                                                    .foregroundColor(Theme.Colors.textSecondary)
                                            }
                                        }
                                        .padding(.leading, 8)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("No phases defined")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                        .padding(.horizontal, Theme.Row.contentPadding)
                        .padding(.vertical, Theme.Row.contentPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Actions Column (20%)
                        VStack(alignment: .trailing, spacing: Theme.spacingSmall) {
                            // Edit Button
                            Button(action: {
                                sidebarState.show(.project(project))
                            }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.Colors.divider.opacity(0.3))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandOnHover()
                            .accessibilityLabel("Edit Project")
                            .accessibilityHint("Opens the project editor")
                            
                            // Archive Button
                            Button(action: {
                                Task {
                                    await ProjectsViewModel.shared.archiveProject(project)
                                }
                            }) {
                                Image(systemName: "archivebox")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.Colors.divider.opacity(0.3))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandOnHover()
                            .accessibilityLabel("Archive Project")
                            .accessibilityHint("Archives this project")
                        }
                        .padding(.trailing, Theme.Row.contentPadding)
                        .padding(.top, Theme.Row.contentPadding)
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 12.0, *)
struct ProjectsNativeView_Previews: PreviewProvider {
    
    static func createMockViewModel(with projects: [Project]) -> ProjectsViewModel {
        let mockVM = ProjectsViewModel()
        mockVM.projects = projects
        return mockVM
    }

    struct PreviewWrapper: View {
        @StateObject var viewModel: ProjectsViewModel
        
        var body: some View {

            List(viewModel.filteredProjects) { project in
                ProjectRowView(project: project)
            }
            .frame(width: 800, height: 800)
        }
    }

    static var previews: some View {
        ProjectsNativeView()
            .frame(width: 900, height: 800)
            .previewDisplayName("Live Data (from file)")

        // --- Preview 2: Mock Data ---
        // This is a reliable preview for testing UI with specific data,
        // without touching your real files.
        let mockProjects = [
            Project(name: "Juju Time Tracking", color: "#8E44AD", about: "Internal app dev.", order: 1, emoji: "💼"),
            Project(name: "Client - Acme Inc.", color: "#3498DB", about: "Website redesign.", order: 2, emoji: "🌐"),
            Project(name: "Personal Growth", color: "#2ECC71", about: "", order: 3, emoji: "📚")
        ]

        List(mockProjects) { project in
            ProjectRowView(project: project)
        }
        .frame(width: 650, height: 600)
        .previewDisplayName("Mock Data (for UI testing)")
        
        List {
             Text("No Projects Yet")
                .foregroundColor(.secondary)
                .padding(40)
        }
        .frame(width: 650, height: 600)
        .previewDisplayName("Empty State")
    }
}
#endif
