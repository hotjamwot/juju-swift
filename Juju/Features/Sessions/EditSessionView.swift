import SwiftUI

struct EditSessionView: View {
    let session: SessionRecord
    let projectNames: [String]
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedDate: String = ""
    @State private var editedStartTime: String = "09:00"
    @State private var editedEndTime: String = "17:00"
    @State private var editedProject: String = ""
    @State private var editedNotes: String = ""
    @State private var selectedMood: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Date
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date")
                            .font(.headline)
                        TextField("YYYY-MM-DD", text: $editedDate)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Times
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Times")
                            .font(.headline)
                        HStack(spacing: 16) {
                            TextField("Start", text: $editedStartTime)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 120)
                            TextField("End", text: $editedEndTime)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 120)
                        }
                    }
                    
                    // Project
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Project")
                            .font(.headline)
                        Picker("Project", selection: $editedProject) {
                            Text("-- Select Project --").tag("")
                            ForEach(projectNames, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 250)
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.headline)
                        TextEditor(text: $editedNotes)
                            .frame(height: 120)
                            .border(Theme.surface, width: 1)
                            .cornerRadius(4)
                    }
                    
                    // Mood
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mood (0-10)")
                            .font(.headline)
                        Picker("Mood", selection: $selectedMood) {
                            Text("-- No mood --").tag("")
                            ForEach(0...10, id: \.self) { mood in
                                Text("\(mood)").tag("\(mood)")
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSession()
                    }
                    .disabled(editedProject.isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600) // Increased default size to fit all fields
        .onAppear {
            editedDate = session.date
            editedStartTime = String(session.startTime.prefix(5))
            editedEndTime = String(session.endTime.prefix(5))
            editedProject = session.projectName
            editedNotes = session.notes
            selectedMood = session.mood.map { "\($0)" } ?? ""
        }
    }
    
    private func saveSession() {
        _ = SessionManager.shared.updateSessionFull(
            id: session.id,
            date: editedDate,
            startTime: editedStartTime + ":00",
            endTime: editedEndTime + ":00",
            projectName: editedProject,
            notes: editedNotes,
            mood: selectedMood.isEmpty ? nil : Int(selectedMood)
        )
        
        dismiss()
    }
}
