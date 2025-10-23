import SwiftUI

struct ProjectDetailView: View {
    @Binding var project: Project
    let onSave: (Project) -> Void
    let onDelete: (Project) -> Void
    
    @State private var editedName: String
    @State private var editedColor: Color
    @State private var editedAbout: String
    
    init(project: Binding<Project>, onSave: @escaping (Project) -> Void, onDelete: @escaping (Project) -> Void) {
        self._project = project
        self.onSave = onSave
        self.onDelete = onDelete
        self._editedName = State(initialValue: project.wrappedValue.name)
        self._editedColor = State(initialValue: (NSColor(hex: project.wrappedValue.color) ?? NSColor.systemBlue).swiftUIColor)
        self._editedAbout = State(initialValue: project.wrappedValue.about ?? "")
    }
    
    @State private var showingDeleteAlert = false
    @State private var isDeleteHover = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            // Project Name
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Name")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("Project Name", text: $editedName)
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
                    .onChange(of: editedName) { _, _ in updateProject() }
            }
            
            // Color Picker
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Color")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                ColorPicker("", selection: $editedColor)
                    .labelsHidden()
                    .onChange(of: editedColor) { _, _ in updateProject() }
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
                    .onChange(of: editedAbout) { _, _ in updateProject() }
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
        var updatedProject = project
        updatedProject.name = editedName
        updatedProject.color = editedColor.toHex() ?? "#4E79A7"
        updatedProject.about = editedAbout
        onSave(updatedProject)
    }
}

extension Color {
    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components else { return nil }
        let r = Int(round(components[0] * 255.0))
        let g = Int(round(components[1] * 255.0))
        let b = Int(round(components[2] * 255.0))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
