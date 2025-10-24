import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    let onSave: (Project) -> Void
    let onDelete: (Project) -> Void

    @State private var editedName: String
    @State private var editedColor: Color
    @State private var editedAbout: String
    @State private var showingDeleteAlert = false
    @State private var isDeleteHover = false
    
    init(project: Project, onSave: @escaping (Project) -> Void, onDelete: @escaping (Project) -> Void) {
        self.project = project
        self.onSave = onSave
        self.onDelete = onDelete
        self._editedName = State(initialValue: project.name)
        self._editedAbout = State(initialValue: project.about ?? "")
        self._editedColor = State(initialValue: project.swiftUIColor)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            // Project Name
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Name")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("Project Name", text: $editedName)
                    .textFieldStyle(.plain)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.spacingMedium)
                    .padding(.vertical, Theme.spacingSmall)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            }
            
            // Color Picker
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Color")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                ColorPicker("", selection: $editedColor)
                    .labelsHidden()
            }
            
            // About Text Editor
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("About")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextEditor(text: $editedAbout)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(minHeight: 120)
                    .padding(Theme.spacingMedium)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            }
            
            Spacer()
            
            // Delete Button
            Button("Delete Project") {
                showingDeleteAlert = true
            }
            .font(Theme.Fonts.caption)
            .foregroundColor(Theme.Colors.error)
            .padding(.horizontal, Theme.spacingMedium)
            .padding(.vertical, Theme.spacingSmall)
            .background(isDeleteHover ? Theme.Colors.surface : Color.clear)
            .cornerRadius(Theme.Design.cornerRadius)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .onHover { hovering in
                isDeleteHover = hovering
            }
        }
        .padding(Theme.spacingLarge)
        .frame(minWidth: 400, minHeight: 300)
        .background(Theme.Colors.surface)
        .onDisappear {
            updateProject()
        }
        .alert("Are You Sure?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete(project)
            }
            Button("Cancel", role: .cancel) {
                // Do nothing
            }
        } message: {
            Text("This will permanently delete the project and cannot be undone.")
        }
    }
    
    private func updateProject() {
        let updatedProject = Project(
            id: project.id,
            name: editedName,
            color: editedColor.toHex,
            about: editedAbout.isEmpty ? nil : editedAbout,
            order: project.order
        )
        onSave(updatedProject)
    }
}
