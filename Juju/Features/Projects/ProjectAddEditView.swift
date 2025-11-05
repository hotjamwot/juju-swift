import SwiftUI

struct ProjectAddEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var color: String = "#4E79A7"
    @State private var about: String = ""
    @State private var showingColorPicker = false
    
    let colorOptions = [
        "#4E79A7", "#F28E2C", "#E15759", "#76B7B2", 
        "#59A14F", "#EDC949", "#AF7AA1", "#FF9DA7",
        "#9C755F", "#BAB0AB", "#FFB07B", "#B07AA1",
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A",
        "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9"
    ]
    
    var project: Project?
    var onSave: (Project) -> Void
    var onDelete: ((Project) -> Void)?
    
    init(project: Project? = nil, onSave: @escaping (Project) -> Void, onDelete: ((Project) -> Void)? = nil) {
        self.project = project
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var isEditing: Bool {
        project != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            // Header
            HStack {
                Text(isEditing ? "Edit Project" : "New Project")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.simpleIcon)
                            .pointingHandOnHover()
                        }
                        .padding(.bottom, Theme.spacingMedium)
            
            // Name Field
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Project Name")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("Project Name", text: $name)
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
            
            // Color Section
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Color")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Button(action: {
                    showingColorPicker = true
                }) {
                    HStack(spacing: Theme.spacingSmall) {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Theme.Colors.divider, lineWidth: 1)
                            )
                        
                        Text("Choose Color")
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Spacer()
                        
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
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
                .sheet(isPresented: $showingColorPicker) {
                    ColorPickerView(selectedColor: $color)
                }
            }
            
            // About
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Description (optional)")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextEditor(text: $about)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(minHeight: 100)
                    .padding(Theme.spacingLarge)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            }
            
            Spacer()
            
            HStack {
                // Delete Button (only for editing)
                if isEditing, let onDelete = onDelete, let project = project {
                                Button("Delete Project") {
                                    onDelete(project)
                                    dismiss()
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(Theme.Colors.error)
                                .font(Theme.Fonts.caption)
                                .padding(.horizontal, Theme.spacingExtraSmall)
                                .pointingHandOnHover()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                
                // Save/Create Button
                Button(isEditing ? "Save Changes" : "Create Project") {
                    if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalAbout = about.isEmpty ? nil : about
                        
                        if isEditing, let project = project {
                            // Update existing project
                            let updatedProject = Project(
                                id: project.id,
                                name: finalName,
                                color: color,
                                about: finalAbout,
                                order: project.order
                            )
                            onSave(updatedProject)
                        } else {
                            // Create new project
                            let newProject = Project(name: finalName, color: color, about: finalAbout)
                            onSave(newProject)
                        }
                        
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.primary)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .pointingHandOnHover()
            }
        }
        .padding(Theme.spacingLarge)
        .frame(minWidth: 400, minHeight: 520)
        .background(Theme.Colors.background)
        .onAppear {
            if let project = project {
                name = project.name
                color = project.color ?? "#4E79A7"
                about = project.about ?? ""
            }
        }
    }
}

// MARK: - Color Picker View
struct ColorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: String
    
    let colorOptions = [
        "#4E79A7", "#F28E2C", "#E15759", "#76B7B2", 
        "#59A14F", "#EDC949", "#AF7AA1", "#FF9DA7",
        "#9C755F", "#BAB0AB", "#FFB07B", "#B07AA1",
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A",
        "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9",
        "#2ECC71", "#E74C3C", "#3498DB", "#F39C12",
        "#9B59B6", "#1ABC9C", "#34495E", "#95A5A6"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            HStack {
                Text("Choose a Color")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.simpleIcon)
                            .pointingHandOnHover()
                        }
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Theme.spacingSmall) {
                    ForEach(colorOptions, id: \.self) { colorOption in
                        Button(action: {
                            selectedColor = colorOption
                            dismiss()
                        }) {
                            Circle()
                                .fill(Color(hex: colorOption))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Theme.Colors.divider, lineWidth: selectedColor == colorOption ? 3 : 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .pointingHandOnHover()
                        }
                    }
                }
            }
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.background)
    }
}

// MARK: - Preview
struct ProjectAddEditView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Add Project Preview
            ProjectAddEditView(onSave: { _ in })
                .frame(minWidth: 250, minHeight: 600)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Add Project")
            
            // Edit Project Preview
            let sampleProject = Project(name: "Sample Project", color: "#4E79A7", about: "A sample project for preview")
            ProjectAddEditView(project: sampleProject, onSave: { _ in }, onDelete: { _ in })
                .frame(minWidth: 250, minHeight: 600)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Edit Project")
        }
    }
}
