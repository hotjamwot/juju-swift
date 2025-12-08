import SwiftUI

struct ProjectsNativeView: View {
    @StateObject private var viewModel = ProjectsViewModel.shared
    @EnvironmentObject var sidebarState: SidebarStateManager
    
    @State private var showingAddProjectSheet = false
    @State private var selectedProjectForEdit: Project?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Projects")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                
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
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Project")
                    }
                }
                .buttonStyle(.primary)
            }
            .padding(.vertical, Theme.spacingLarge)
            .padding(.horizontal, Theme.spacingLarge)
            .background(Theme.Colors.background)

            // Projects List
            ScrollView {
                if viewModel.activeProjects.isEmpty && viewModel.archivedProjects.isEmpty {
                    Text("No Projects Yet")
                        .foregroundColor(Theme.Colors.surface)
                        .padding(40)
                } else {
                    LazyVStack(spacing: Theme.spacingMedium) {
                        // Active Projects Section
                        if !viewModel.activeProjects.isEmpty {
                            Section {
                                ForEach(viewModel.activeProjects) { project in
                                    Button(action: {
                                        sidebarState.show(.project(project))
                                    }) {
                                        ProjectRowView(project: project)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                Text("Active Projects")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.leading)
                            }
                            
                            // Archived Projects Section
                            if !viewModel.archivedProjects.isEmpty {
                                Section {
                                    ForEach(viewModel.archivedProjects) { project in
                                        Button(action: {
                                            sidebarState.show(.project(project))
                                        }) {
                                            ProjectRowView(project: project, isArchived: true)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } header: {
                                    Text("Archived Projects")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.leading)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
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
    
    var body: some View {
        HStack(spacing: Theme.spacingMedium) {
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .fill(project.swiftUIColor)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
                // Project name with emoji
                HStack(spacing: Theme.spacingSmall) {
                    Text(project.emoji)
                        .font(Theme.Fonts.header)
                    Text(project.name)
                        .font(Theme.Fonts.header)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    if isArchived {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                if let about = project.about, !about.isEmpty {
                    Text(about)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1))
        .opacity(isArchived ? 0.7 : 1.0)
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
            .frame(width: 650, height: 600)
        }
    }

    static var previews: some View {
        ProjectsNativeView()
            .frame(width: 650, height: 600)
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
