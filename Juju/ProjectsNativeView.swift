import SwiftUI

struct ProjectsNativeView: View {
    @StateObject private var viewModel = ProjectsViewModel()
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                if viewModel.isGridView {
                    // Grid View
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
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
                } else {
                    // List View
                    List(viewModel.filteredProjects) { project in
                        NavigationLink(value: project) {
                            ProjectRowView(
                                project: project,
                                isSelected: false,
                                onSelect: {}
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                if viewModel.filteredProjects.isEmpty {
                    Spacer()
                    Text("No projects found. Add one to get started.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .navigationTitle("Projects")
            .navigationDestination(for: Project.self) { project in
                let projectBinding = Binding(
                    get: { project },
                    set: { newValue in
                        if let index = viewModel.projects.firstIndex(where: { $0.id == project.id }) {
                            viewModel.projects[index] = newValue
                        }
                    }
                )
                ProjectDetailView(
                    project: projectBinding,
                    onSave: { updatedProject in
                        viewModel.updateProject(updatedProject)
                    },
                    onDelete: { projectToDelete in
                        viewModel.deleteProject(projectToDelete)
                        path.removeLast()  // Pop back to projects list
                    }
                )
                .navigationTitle("Edit Project")
            }
        }
    }
}
