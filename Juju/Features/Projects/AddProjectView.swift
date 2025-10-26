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
            
            // Create Button
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
            .background(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.Colors.accent.opacity(0.8) : Theme.Colors.accent)
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
        .background(Theme.Colors.background)
    }
}

// MARK: - Preview
struct AddProjectView_Previews: PreviewProvider {
    // A tiny no‑op closure for the preview – the real app will handle the save.
    static var dummyOnSave: (Project) -> Void = { _ in /* no‑op */ }
    static var previews: some View {
        Group {
            // Regular light‑mode preview
            AddProjectView(onSave: dummyOnSave)
                .frame(minWidth: 500, minHeight: 400)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Light")
            // Dark‑mode preview – handy for testing Theme colors
            AddProjectView(onSave: dummyOnSave)
                .preferredColorScheme(.dark)
                .frame(minWidth: 500, minHeight: 600)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Dark")
        }
    }
}
