import SwiftUI

struct ProjectDetailView: View {
    @Binding var project: Project
    let onSave: (Project) -> Void
    
    @State private var editedName: String
    @State private var editedColor: Color
    @State private var editedAbout: String
    
    init(project: Binding<Project>, onSave: @escaping (Project) -> Void) {
        self._project = project
        self.onSave = onSave
        self._editedName = State(initialValue: project.wrappedValue.name)
        self._editedColor = State(initialValue: Color(hex: project.wrappedValue.color))
        self._editedAbout = State(initialValue: project.wrappedValue.about ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Project Name
            VStack(alignment: .leading) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Project Name", text: $editedName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: editedName) { _ in updateProject() }
            }
            
            // Color Picker
            VStack(alignment: .leading) {
                Text("Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ColorPicker("", selection: $editedColor)
                    .labelsHidden()
                    .onChange(of: editedColor) { _ in updateProject() }
            }
            
            // About Text Editor
            VStack(alignment: .leading) {
                Text("About")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $editedAbout)
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2))
                    )
                    .onChange(of: editedAbout) { _ in updateProject() }
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 300)
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