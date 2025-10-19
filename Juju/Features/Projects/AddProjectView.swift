import SwiftUI

struct AddProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var color: String = "#4E79A7"
    @State private var about: String = ""
    @State private var showingColorPicker = false
    
    let colorOptions = [
        "#4E79A7", "#F28E2C", "#E15759", "#76B7B2", 
        "#59A14F", "#EDC949", "#AF7AA1", "#FF9DA7",
        "#9C755F", "#BAB0AB", "#FFB07B", "#B07AA1"
    ]
    
    var onSave: (Project) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Project Details")) {
                    TextField("Project Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("Color")
                        .foregroundColor(.primary)
                    
                    HStack {
                        ForEach(colorOptions, id: \.self) { colorOption in
                            Button(action: {
                                self.color = colorOption
                            }) {
                                Circle()
                                    .fill(Color(hex: colorOption))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.3), lineWidth: self.color == colorOption ? 2 : 0)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    TextField("Description (optional)", text: $about, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section {
                    Button("Create Project") {
                        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let newProject = Project(name: name.trimmingCharacters(in: .whitespacesAndNewlines), 
                                                   color: color, 
                                                   about: about.isEmpty ? nil : about)
                            onSave(newProject)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
