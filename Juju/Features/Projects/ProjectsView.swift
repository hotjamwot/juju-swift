import SwiftUI

struct ProjectsView: View {
    @StateObject private var viewModel = ProjectsViewModel.shared
    @EnvironmentObject var sidebarState: SidebarStateManager
    
    @State private var showingAddProjectSheet = false
    @State private var selectedProjectForEdit: Project?
    @State private var showArchivedProjects = false
    @State private var projectToDeleteForConfirmation: Project?
    @State private var selectedMigrationTargetForConfirmation: Project?
    
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
                                    ProjectRowView(
                                        project: project,
                                        projectToDeleteForConfirmation: $projectToDeleteForConfirmation,
                                        selectedMigrationTargetForConfirmation: $selectedMigrationTargetForConfirmation
                                    )
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
                                    ProjectRowView(
                                        project: project,
                                        isArchived: true,
                                        projectToDeleteForConfirmation: $projectToDeleteForConfirmation,
                                        selectedMigrationTargetForConfirmation: $selectedMigrationTargetForConfirmation
                                    )
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
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.showArchivedProjects ? "archivebox.fill" : "archivebox")
                            .font(.system(size: 14))
                        Text(viewModel.showArchivedProjects ? "Hide Archived Projects" : "Archived Projects")
                            .font(Theme.Fonts.caption)
                    }
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
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

// MARK: - Delete Project Popover

struct DeleteProjectPopover: View {
    let project: Project?
    let availableProjects: [Project]
    @Binding var selectedProject: Project?
    let onDelete: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.spacingLarge) {
            VStack(spacing: Theme.spacingMedium) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.error)
                
                Text("Delete Project")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("Are you sure you want to delete '\(project?.name ?? "")'?")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let project = project, !availableProjects.isEmpty {
                VStack(spacing: Theme.spacingSmall) {
                    Text("Migrate Sessions")
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Select which project to migrate \(project.totalDurationHours > 0 ? "\(Int(project.totalDurationHours))h" : "0h") of sessions to:")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Picker("Select Project", selection: $selectedProject) {
                        ForEach(availableProjects, id: \.id) { project in
                            Text(project.name).tag(project as Project?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Theme.spacingMedium)
            } else if let project = project, project.totalDurationHours > 0 {
                Text("This project has sessions that will be lost if deleted.")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: Theme.spacingMedium) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(ConfirmationSecondaryButtonStyle())
                
                Button("Delete", action: onDelete)
                    .buttonStyle(ConfirmationDangerButtonStyle())
            }
            .padding(.bottom, Theme.spacingMedium)
        }
        .padding(.horizontal, Theme.spacingLarge)
        .padding(.vertical, Theme.spacingLarge)
        .background(Theme.Colors.background)
    }
}

// MARK: - Custom Button Styles

struct ConfirmationSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.caption)
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.Colors.divider.opacity(0.3))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ConfirmationDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.Colors.error)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ProjectRowView: View {
    let project: Project
    var isArchived: Bool = false
    @EnvironmentObject var sidebarState: SidebarStateManager
    
    // Bindings for delete confirmation
    @Binding var projectToDeleteForConfirmation: Project?
    @Binding var selectedMigrationTargetForConfirmation: Project?
    
    // Hover state for interactive feedback
    @State private var isHovering = false
    @State private var isExpanded = false
    
    // Get current phase from project model (cached)
    private var currentPhase: Phase? {
        project.currentPhase
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
                    
                    // Current phase from most recent session (with more padding)
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
                    
                    // Add extra padding between phase and project info
                    Spacer().frame(width: 16)
                    
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
                
                // Archived status or actions (moved inside, before duration)
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
                    // No buttons in main row - they're in the expanded dropdown
                    Spacer().frame(maxWidth: 160)
                }
                
                // Total duration capsule (now at the far right, last element)
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
            }
            .frame(height: Theme.Row.height)
            .background(
                isHovering ? Theme.Colors.surface.opacity(0.9) : Theme.Colors.surface.opacity(0.7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Row.cornerRadius)
                    .stroke(project.swiftUIColor.opacity(0.3), lineWidth: 2)
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
                            
                            // Delete Button (Error color) with Popover
                            Button(action: {
                                // Show delete confirmation popover
                                projectToDeleteForConfirmation = project
                                selectedMigrationTargetForConfirmation = ProjectsViewModel.shared.activeProjects.first { $0.id != project.id }
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.error)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.Colors.divider.opacity(0.3))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandOnHover()
                            .accessibilityLabel("Delete Project")
                            .accessibilityHint("Deletes this project and migrates its sessions")
                            .popover(isPresented: .constant(projectToDeleteForConfirmation != nil)) {
                                DeleteProjectPopover(
                                    project: projectToDeleteForConfirmation,
                                    availableProjects: ProjectsViewModel.shared.activeProjects.filter { $0.id != projectToDeleteForConfirmation?.id },
                                    selectedProject: $selectedMigrationTargetForConfirmation,
                                    onDelete: {
                                        if let project = projectToDeleteForConfirmation, let target = selectedMigrationTargetForConfirmation {
                                            Task {
                                                await ProjectsViewModel.shared.deleteProjectWithMigration(project, targetProject: target)
                                                projectToDeleteForConfirmation = nil
                                                selectedMigrationTargetForConfirmation = nil
                                            }
                                        }
                                    },
                                    onCancel: {
                                        projectToDeleteForConfirmation = nil
                                        selectedMigrationTargetForConfirmation = nil
                                    }
                                )
                                .padding(20)
                                .background(Theme.Colors.background)
                            }
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
struct ProjectsView_Previews: PreviewProvider {
    
    static func createMockViewModel(with projects: [Project]) -> ProjectsViewModel {
        let mockVM = ProjectsViewModel()
        mockVM.projects = projects
        return mockVM
    }

    struct PreviewWrapper: View {
        @StateObject var viewModel: ProjectsViewModel
        
        var body: some View {

            List(viewModel.filteredProjects) { project in
                ProjectRowView(
                    project: project,
                    projectToDeleteForConfirmation: .constant(nil),
                    selectedMigrationTargetForConfirmation: .constant(nil)
                )
            }
            .frame(width: 800, height: 800)
        }
    }

    static var previews: some View {
        ProjectsView()
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
            ProjectRowView(
                project: project,
                projectToDeleteForConfirmation: .constant(nil),
                selectedMigrationTargetForConfirmation: .constant(nil)
            )
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
