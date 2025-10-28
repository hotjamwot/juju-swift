import SwiftUI

struct ProjectsNativeView: View {
    @StateObject private var viewModel = ProjectsViewModel()
    @State private var showingAddProject = false
    @State private var selectedProject: Project?
    
    var body: some View {
        VStack {
            // Header with title
            HStack {
                Text("Projects")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: {
                    showingAddProject = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add Project")
                            .font(Theme.Fonts.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.spacingMedium)
                    .padding(.vertical, Theme.spacingSmall)
                    .background(Theme.Colors.accent)
                    .cornerRadius(Theme.Design.cornerRadius)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
            }
            .padding()
            
            // Projects List
            ScrollView {
                LazyVStack(spacing: Theme.spacingMedium) {
                    ForEach(viewModel.filteredProjects) { project in
                        Button(action: {
                            selectedProject = project
                        }) {
                            ProjectRowView(project: project)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if viewModel.filteredProjects.isEmpty {
                        VStack(spacing: Theme.spacingSmall) {
                            Image(systemName: "folder")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            Text("No projects found")
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            Text("Click 'Add Project' to create your first project")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
        }
        .background(Theme.Colors.background)
        .sheet(isPresented: $showingAddProject) {
            ProjectAddEditView(onSave: { newProject in
                viewModel.addProject(name: newProject.name)
                showingAddProject = false
            })
        }
        .sheet(item: $selectedProject) { project in
            ProjectAddEditView(
                project: project,
                onSave: { updatedProject in
                    viewModel.updateProject(updatedProject)
                },
                onDelete: { projectToDelete in
                    viewModel.deleteProject(projectToDelete)
                }
            )
        }
        .task {
            await viewModel.loadProjects()
        }
    }
}

struct ProjectRowView: View {
    let project: Project
    
    var body: some View {
        HStack(spacing: Theme.spacingMedium) {
            // Project Color Indicator
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .fill(project.swiftUIColor)
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
            
            // Project Info
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                if let about = project.about, !about.isEmpty {
                    Text(about)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Navigation Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}
