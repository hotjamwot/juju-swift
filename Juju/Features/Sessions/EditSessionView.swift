import SwiftUI

struct EditSessionView: View {
    // MARK: – Public Properties
    let session: SessionRecord
    let projectNames: [String]

    // MARK: – Environment & State
    @Environment(\.dismiss) private var dismiss
    @State private var editedDate = ""
    @State private var editedStartTime = "09:00"
    @State private var editedEndTime = "17:00"
    @State private var editedProject = ""
    @State private var editedNotes = ""
    @State private var selectedMood = ""

    // MARK: – Body
    var body: some View {
        Form {
            // ── Date ──────────────────────────────────────
            Section(header: Text("Date")) {
                TextField("YYYY-MM-DD", text: $editedDate)
                    .textFieldStyle(.roundedBorder)
            }

            // ── Times ──────────────────────────────────────
            Section(header: Text("Times")) {
                HStack(spacing: Theme.spacingLarge) {
                    TextField("Start", text: $editedStartTime)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    TextField("End", text: $editedEndTime)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
            }

            // ── Project ───────────────────────────────────
            Section(header: Text("Project")) {
                Picker("Project", selection: $editedProject) {
                    Text("-- Select Project --").tag("")
                    ForEach(projectNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // ── Notes ─────────────────────────────────────
            Section(header: Text("Notes")) {
                TextEditor(text: $editedNotes)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .stroke(Theme.surface, lineWidth: 1)
                    )
            }

            // ── Mood ───────────────────────────────────────
            Section(header: Text("Mood (0‑10)")) {
                Picker("Mood", selection: $selectedMood) {
                    Text("-- No mood --").tag("")
                    ForEach(0...10, id: \.self) { mood in
                        Text("\(mood)").tag("\(mood)")
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, Theme.spacingLarge) 
        .navigationTitle("Edit Session")            // Shows on iOS; macOS shows the window title
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveSession() }
                    .disabled(editedProject.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
            }
        }
        .frame(minWidth: 500, minHeight: 600)        // Comfortable default size
        .onAppear {
            editedDate       = session.date
            editedStartTime  = String(session.startTime.prefix(5))
            editedEndTime    = String(session.endTime.prefix(5))
            editedProject    = session.projectName
            editedNotes      = session.notes
            selectedMood     = session.mood.map { "\($0)" } ?? ""
        }
    }

    // MARK: – Helpers
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
