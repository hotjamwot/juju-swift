import SwiftUI

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(@ViewBuilder build: @escaping () -> Content) {
        self.build = build
    }
    var body: some View {
        build()
    }
}

struct ProjectsNativeView: View {
    @StateObject private var viewModel = ProjectsViewModel()
    @State private var path = NavigationPath()
    @State private var showingAddProject = false
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                // Grid View with Add Project Button
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    // Add Project Button
                    Button(action: {
                        showingAddProject = true
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(height: 100)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.accentColor)
                                )
                            
                            Text("Add Project")
                                .lineLimit(1)
                                .font(Theme.Fonts.header)
                        }
                        .padding(Theme.spacingMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.clear)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accentColor.opacity(0.3))
                        )
                    }
                    
                    // Existing Projects
                    ForEach(viewModel.filteredProjects) { project in
                        NavigationLink(value: project) {
                            ProjectGridItemView(
                                project: project,
                                isSelected: false,
                                onSelect: {}
                            )
                        }
                    }
                }
                .padding()
                .scrollContentBackground(.hidden)
                
                if viewModel.filteredProjects.isEmpty {
                    Spacer()
                    Text("No projects found. Click 'Add Project' to create one.")
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                }
            }
            .navigationTitle("Projects")
            .sheet(isPresented: $showingAddProject) {
                AddProjectView(onSave: { project in
                    viewModel.addProject(name: project.name)
                    showingAddProject = false
                })
            }
            .navigationDestination(for: Project.self) { project in
                LazyView {
                    ProjectDetailView(
                        project: project,
                        onSave: { updatedProject in
                            viewModel.updateProject(updatedProject)
                        },
                        onDelete: { projectToDelete in
                            viewModel.deleteProject(projectToDelete)
                            path.removeLast()  // Pop back to projects list
                        }
                    )
                }
                .navigationTitle("Edit Project")
            }
            .task {
                await viewModel.loadProjects()
            }
        }
    }
}
