import SwiftUI

struct AddProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var color: String = "#4E79A7"
    @State private var about: String = ""
    
    let colorOptions = [
        "#4E79A7", "#F28E2C", "#E15759", "#76B7B2", 
        "#59A14F", "#EDC949", "#AF7AA1", "#FF9DA7",
        "#9C755F", "#BAB0AB", "#FFB07B", "#B07AA1"
    ]
    
    var onSave: (Project) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            // Header
            HStack {
                Text("New Project")
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .buttonStyle(PlainButtonStyle())
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
            }
            .padding(.bottom, Theme.spacingMedium)
            
            Divider()
                .background(Theme.Colors.divider)
                .padding(.bottom, Theme.spacingLarge)
            
            // Name Field
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Project Name")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextField("Project Name", text: $name)
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
                HStack(spacing: Theme.spacingSmall) {
                    ForEach(colorOptions, id: \.self) { colorOption in
                        Button(action: {
                            self.color = colorOption
                        }) {
                            Circle()
                                .fill(Color(hex: colorOption))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Theme.Colors.divider, lineWidth: colorOption == color ? 2 : 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // About
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Description (optional)")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextEditor(text: $about)
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
            
            // Create Button
            Divider()
                .background(Theme.Colors.divider)
                .padding(.bottom, Theme.spacingMedium)
            
            Button("Create Project") {
                if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let newProject = Project(name: name.trimmingCharacters(in: .whitespacesAndNewlines), 
                                           color: color, 
                                           about: about.isEmpty ? nil : about)
                    onSave(newProject)
                }
            }
            .font(Theme.Fonts.body.weight(.semibold))
            .foregroundColor(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.Colors.accent.opacity(0.5) : Theme.Colors.accent)
            .cornerRadius(Theme.Design.cornerRadius)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .scaleEffect(0.95)
            .onHover { isHovered in
                if isHovered && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
        }
        .padding(Theme.spacingLarge)
        .frame(minWidth: 400, minHeight: 300)
        .background(Theme.Colors.surface)
    }
}
