import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Native Export Button
struct NativeExportButton: View {
    let sessions: [SessionRecord]
    let onExportComplete: (Bool, String) -> Void
    
    // Export state
    @State private var isExporting = false
    @State private var exportFormat: ExportFormat = .csv
    @State private var showingExportDialog = false
    
    var body: some View {
        Button(action: {
            showingExportDialog = true
        }) {
            HStack(spacing: Theme.spacingExtraSmall) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .medium))
                Text("Export")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.horizontal, Theme.spacingSmall)
            .padding(.vertical, Theme.spacingExtraSmall)
            .background(
                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius / 2)
                    .fill(Theme.Colors.divider.opacity(0.2))
            )
        }
        .help("Export filtered sessions using native macOS dialog")
        .buttonStyle(.plain)
        .disabled(isExporting || sessions.isEmpty)
        .opacity(sessions.isEmpty ? 0.5 : 1.0)
        .fileExporter(
            isPresented: $showingExportDialog,
            documents: [ExportDocument(sessions: sessions, format: exportFormat)],
            contentType: exportFormat == .csv ? UTType.commaSeparatedText : UTType.plainText
        ) { result in
            switch result {
            case .success(let urls):
                // File was successfully saved
                if let url = urls.first {
                    onExportComplete(true, url.path)
                } else {
                    onExportComplete(false, "Export failed: No URL returned")
                }
            case .failure(let error):
                // Handle error
                print("Export failed: \(error)")
                onExportComplete(false, "Export failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Export Document
struct ExportDocument: FileDocument {
    static var readableContentTypes = [UTType.commaSeparatedText, UTType.plainText]
    
    let sessions: [SessionRecord]
    let format: ExportFormat
    
    init(sessions: [SessionRecord], format: ExportFormat) {
        self.sessions = sessions
        self.format = format
    }
    
    init(configuration: ReadConfiguration) throws {
        // This initializer is required but not used for export
        // For FileDocument, we don't need to actually read the file
        // Just initialize with empty values
        sessions = []
        format = .csv
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let content = generateExportContent()
        let data = Data(content.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
    
    private func generateExportContent() -> String {
        switch format {
        case .csv:
            return generateCSVContent()
        case .txt:
            return generateTextContent()
        case .md:
            return generateMarkdownContent()
        }
    }
    
    private func generateCSVContent() -> String {
        var csv = "Date,Start Time,End Time,Duration (minutes),Project,Activity Type,Notes,Mood\n"
        
        for session in sessions {
            let activityName = getActivityName(from: session)
            let mood = session.mood ?? 0
            
            // Escape quotes and commas in fields
            let notes = session.notes.replacingOccurrences(of: "\"", with: "\"\"")
            
            csv += "\"\(session.date)\",\"\(session.startTime)\",\"\(session.endTime)\",\(session.durationMinutes),\"\(session.projectName)\",\"\(activityName)\",\"\(notes)\",\(mood)\n"
        }
        
        return csv
    }
    
    private func generateTextContent() -> String {
        var text = "Juju Session Export\n"
        text += "Generated on: \(Date())\n"
        text += "Total sessions: \(sessions.count)\n\n"
        
        for session in sessions {
            let activityName = getActivityName(from: session)
            let mood = session.mood ?? 0
            
            text += "Date: \(session.date)\n"
            text += "Time: \(session.startTime) - \(session.endTime)\n"
            text += "Duration: \(session.durationMinutes) minutes\n"
            text += "Project: \(session.projectName)\n"
            text += "Activity: \(activityName)\n"
            if !session.notes.isEmpty {
                text += "Notes: \(session.notes)\n"
            }
            text += "Mood: \(mood)/10\n"
            text += "---\n\n"
        }
        
        return text
    }
    
    private func generateMarkdownContent() -> String {
        var markdown = "# Juju Session Export\n\n"
        markdown += "**Generated on:** \(Date())\n"
        markdown += "**Total sessions:** \(sessions.count)\n\n"
        
        for session in sessions {
            let activityName = getActivityName(from: session)
            let mood = session.mood ?? 0
            
            markdown += "## \(session.projectName)\n\n"
            markdown += "- **Date:** \(session.date)\n"
            markdown += "- **Time:** \(session.startTime) - \(session.endTime)\n"
            markdown += "- **Duration:** \(session.durationMinutes) minutes\n"
            markdown += "- **Activity:** \(activityName)\n"
            if !session.notes.isEmpty {
                markdown += "- **Notes:** \(session.notes)\n"
            }
            markdown += "- **Mood:** \(mood)/10\n\n"
        }
        
        return markdown
    }
    
    private func getActivityName(from session: SessionRecord) -> String {
        // This would ideally use the ActivityTypeManager to get the name
        // For now, return the activity type ID or a default
        return session.activityTypeID ?? "Unknown"
    }
}

// MARK: - UTType Extension
extension UTType {
    static let markdown = UTType(filenameExtension: "md", conformingTo: .plainText)!
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct NativeExportButton_Previews: PreviewProvider {
    static var previews: some View {
        let sessions = [
            SessionRecord(
                id: "1",
                date: "2024-01-01",
                startTime: "09:00:00",
                endTime: "10:00:00",
                durationMinutes: 60,
                projectName: "Test Project",
                projectID: "project-1",
                activityTypeID: "1",
                projectPhaseID: nil,
                milestoneText: nil,
                notes: "Test notes",
                mood: 8
            )
        ]
        
        VStack {
            NativeExportButton(
                sessions: sessions,
                onExportComplete: { success, message in
                    print("Export: \(success ? "Success" : "Failed") - \(message)")
                }
            )
            .padding()
            .background(Theme.Colors.background)
        }
    }
}
#endif
