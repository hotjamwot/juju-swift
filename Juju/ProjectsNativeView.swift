import SwiftUI

struct ProjectsNativeView: View {
    @StateObject private var viewModel = ProjectsViewModel()
    @State private var showingAddSheet = false
    @State private var newProjectName = ""
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
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button("Add") {
                        newProjectName = ""
                        showingAddSheet = true
                    }
                }
                
                ToolbarItemGroup(placement: .navigation) {
                    HStack {
                        TextField("Search", text: $viewModel.searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 150)
                        
                        Menu {
                            Button("Order") { viewModel.sortOrder = .order }
                            Button("Name") { viewModel.sortOrder = .name }
                            Button("Date Created") { viewModel.sortOrder = .dateCreated }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        
                        Button {
                            viewModel.isGridView.toggle()
                        } label: {
                            Image(systemName: viewModel.isGridView ? "list.bullet" : "square.grid.2x2")
                        }
                    }
                }
            }
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
        .sheet(isPresented: $showingAddSheet) {
            VStack(spacing: 20) {
                Text("New Project")
                    .font(.headline)
                
                TextField("Project Name", text: $newProjectName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    Button("Cancel") { showingAddSheet = false }
                        .keyboardShortcut(.escape)
                    
                    Button("Create") {
                        if !newProjectName.trimmingCharacters(in: .whitespaces).isEmpty {
                            viewModel.addProject(name: newProjectName.trimmingCharacters(in: .whitespaces))
                            showingAddSheet = false
                        }
                    }
                    .keyboardShortcut(.return)
                    .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
            .frame(minWidth: 300)
        }
    }
}
