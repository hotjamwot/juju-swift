import SwiftUI

struct SwiftUIDashboardRootView: View {
    // Keep track of which tab is selected
    private enum Tab {
        case charts, sessions, projects
    }
    @State private var selected: Tab = .charts

    var body: some View {
        VStack(spacing: 0) {
            // Only show projects toolbar for projects tab
            if selected == .projects {
                ProjectsToolbarView()
            }
            
            TabView(selection: $selected) {
                WebDashboardView()
                    .tabItem { Text("Juju") }
                    .tag(Tab.charts)

                SessionsView()
                    .tabItem { Text("Sessions") }
                    .tag(Tab.sessions)

                ProjectsNativeView()
                    .tabItem { Text("Projects") }
                    .tag(Tab.projects)
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}

// Separate toolbar view for projects
struct ProjectsToolbarView: View {
    @StateObject private var viewModel = ProjectsViewModel()
    @State private var showingAddSheet = false
    @State private var newProjectName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with Add, Search, Order, and View toggle
            HStack {
                Spacer()
                
                HStack(spacing: 16) {
                    // Add button
                    Button(action: {
                        newProjectName = ""
                        showingAddSheet = true
                    }) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    // Search field
                    TextField("Search projects...", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                    
                    // Order menu
                    Menu {
                        Button("Order") { viewModel.sortOrder = .order }
                        Button("Name") { viewModel.sortOrder = .name }
                        Button("Date Created") { viewModel.sortOrder = .dateCreated }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("Order")
                    }
                    
                    // View toggle
                    Button(action: {
                        viewModel.isGridView.toggle()
                    }) {
                        Image(systemName: viewModel.isGridView ? "list.bullet" : "square.grid.2x2")
                        Text(viewModel.isGridView ? "List" : "Grid")
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .border(Color.gray.opacity(0.3), width: 1)
            
            // Add project sheet
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
}
