import SwiftUI

/// Component for displaying session information in the viewing mode
struct SessionViewOptions: View {
    let session: SessionRecord
    let projects: [Project]
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    public init(
        session: SessionRecord,
        projects: [Project],
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.session = session
        self.projects = projects
        self.onEdit = onEdit
        self.onDelete = onDelete
    }


    @State private var isExpanded = false
    
    public var body: some View {
        HStack(spacing: 0) {
            // --- Card content ------------------------------------
              VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                  /* ────── TOP ROW: Project + Mood ───────────── */
                  HStack {
                      // Project name with emoji (left)
                      HStack(spacing: Theme.spacingExtraSmall) {
                          Text(sessionProjectEmoji)
                              .font(Theme.Fonts.header)
                          Text(session.projectName)
                              .font(Theme.Fonts.header)
                              .lineLimit(1)
                              .help(session.projectName)     // tooltip for truncated names
                      }
                      
                      Spacer()
                      
                      // Mood (right, only if set)
                      if let mood = session.mood {
                          HStack(spacing: Theme.spacingExtraSmall) {
                              Image(systemName: "star.fill")
                              Text("Mood: \(mood)/10")
                          }
                          .font(Theme.Fonts.caption)
                          .foregroundColor(moodColor(for: mood))
                          .background(.clear)
                          .clipShape(Capsule())
                      }
                  }
                  
                  /* ────── MIDDLE ROW: Time & Duration ────── */
                  HStack {
                      HStack(spacing: Theme.spacingExtraSmall) {
                          Image(systemName: "clock")
                          Text("\(formattedStartTime) - \(formattedEndTime)")
                      }
                      .font(Theme.Fonts.caption)
                      .foregroundColor(Theme.Colors.textSecondary)
                      
                      Spacer()
                      
                      Text(formatDuration(session.durationMinutes))
                          .font(Theme.Fonts.caption.weight(.semibold))
                          .foregroundColor(Theme.Colors.textSecondary)
                  }
                  
                  /* ────── NOTES SECTION (if present) ────── */
                  if !session.notes.isEmpty {
                      VStack(alignment: .leading, spacing: 0) {
                          Text(session.notes)
                              .font(Theme.Fonts.body)
                              .foregroundColor(Theme.Colors.textPrimary)
                              .lineLimit(isExpanded ? nil : 3)
                              .fixedSize(horizontal: false, vertical: true)
                              .frame(maxWidth: .infinity, alignment: .leading)
                          
                          // Expand/Collapse button for long notes
                          if session.notes.count > 100 {
                              Button(isExpanded ? "Show Less" : "Show More") {
                                  isExpanded.toggle()
                              }
                              .font(.caption)
                              .foregroundColor(Theme.Colors.textSecondary)
                              .buttonStyle(PlainButtonStyle())
                          }
                      }
                  }
                  
                  /* ────── BOTTOM ROW: Edit / Delete ────── */
                  HStack {
                      Spacer()
                      HStack(spacing: Theme.spacingExtraSmall) {
                          Button(action: onEdit) {
                              Image(systemName: "pencil")
                          }
                          .buttonStyle(SimpleIconButtonStyle(iconSize: 12))
                          
                          Button(action: onDelete) {
                              Image(systemName: "trash")
                          }
                          .buttonStyle(SimpleIconButtonStyle(iconSize: 12))
                      }
                  }
                  
                  // If there's no notes, push everything up
                  if session.notes.isEmpty { Spacer() }
              }
              .padding(.vertical, Theme.spacingSmall)
              .padding(.horizontal, Theme.spacingSmall)
              .contentShape(Rectangle())
              .onTapGesture {
                  // Expand notes on tap if there are notes and they're long
                  if !session.notes.isEmpty && session.notes.count > 100 {
                      isExpanded.toggle()
                  }
              }
          }
      }

    
    private var sessionProjectColor: Color {
        // Find the project and return its color
        if let project = projects.first(where: { $0.name == session.projectName }) {
            return project.swiftUIColor
        }
        return Theme.Colors.accentColor
    }
    
    private var sessionProjectEmoji: String {
        // Find the project and return its emoji
        if let project = projects.first(where: { $0.name == session.projectName }) {
            return project.emoji
        }
        return "📁" // Default fallback emoji
    }
    
    private var formattedDate: String {
        // Use consistent date formatting for display
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: parseDate())
    }
    
    private var formattedStartTime: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let components = startTimeComponents
        if let date = Calendar.current.date(from: DateComponents(hour: components.hour, minute: components.minute)) {
            return timeFormatter.string(from: date)
        }
        return ""
    }
    
    private var formattedEndTime: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let components = endTimeComponents
        if let date = Calendar.current.date(from: DateComponents(hour: components.hour, minute: components.minute)) {
            return timeFormatter.string(from: date)
        }
        return ""
    }
    
    private var startTimeComponents: (hour: Int, minute: Int) {
        let parts = session.startTime.components(separatedBy: ":")
        let hour = Int(parts[0]) ?? 0
        let minute = Int(parts[1]) ?? 0
        return (hour, minute)
    }
    
    private var endTimeComponents: (hour: Int, minute: Int) {
        let parts = session.endTime.components(separatedBy: ":")
        let hour = Int(parts[0]) ?? 0
        let minute = Int(parts[1]) ?? 0
        return (hour, minute)
    }
    
    private func parseDate() -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: session.date) ?? Date()
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
    
    private func ordinalSuffix(for day: Int) -> String {
        let ones = day % 10
        let tens = day % 100
        if tens >= 11 && tens <= 13 {
            return "th"
        }
        switch ones {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
    
    private func moodColor(for mood: Int) -> Color {
        switch mood {
        case 1...4: return Theme.Colors.error
        case 5...7: return sessionProjectColor.opacity(0.8)
        case 8: return sessionProjectColor.opacity(0.8)
        case 9: return sessionProjectColor.opacity(0.9)
        case 10: return sessionProjectColor
        default: return Theme.Colors.error
        }
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionViewOptions_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Preview with short notes
            SessionViewOptions(
                session: SessionRecord(
                    id: "1",
                    date: "2024-01-15",
                    startTime: "09:00:00",
                    endTime: "10:30:00",
                    durationMinutes: 90,
                    projectName: "Project Alpha",
                    notes: "Quick meeting about the new features.",
                    mood: 7
                ),
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0, emoji: "💼"),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0, emoji: "🏠")
                ],
                onEdit: { print("Edit clicked") },
                onDelete: { print("Delete clicked") }
            )
            .frame(width: 300, height: 140)
            .background(Theme.Colors.surface)
            
            Divider()
            
            // Preview with long notes
            SessionViewOptions(
                session: SessionRecord(
                    id: "2",
                    date: "2024-01-15",
                    startTime: "14:00:00",
                    endTime: "16:00:00",
                    durationMinutes: 120,
                    projectName: "Project Beta",
                    notes: "Long detailed notes about the implementation process and technical decisions made during the development session. This should demonstrate how the notes field handles longer text content and how the layout adapts to accommodate it.",
                    mood: 9
                ),
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0, emoji: "💼"),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0, emoji: "🏠")
                ],
                onEdit: { print("Edit clicked") },
                onDelete: { print("Delete clicked") }
            )
            .frame(width: 300, height: 140)
            .background(Theme.Colors.surface)

            Divider()
            
            // Preview with no mood
            SessionViewOptions(
                session: SessionRecord(
                    id: "3",
                    date: "2024-01-16",
                    startTime: "10:00:00",
                    endTime: "11:00:00",
                    durationMinutes: 60,
                    projectName: "Project Alpha",
                    notes: "Review session",
                    mood: nil
                ),
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0, emoji: "💼"),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0, emoji: "🏠")
                ],
                onEdit: { print("Edit clicked") },
                onDelete: { print("Delete clicked") }
            )
            .frame(width: 300, height: 140)
            .background(Theme.Colors.surface)

            Divider()
            
            // Preview with no notes
            SessionViewOptions(
                session: SessionRecord(
                    id: "4",
                    date: "2024-01-17",
                    startTime: "13:00:00",
                    endTime: "14:30:00",
                    durationMinutes: 90,
                    projectName: "Project Gamma",
                    notes: "",
                    mood: 5
                ),
                projects: [
                    Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0, emoji: "💼"),
                    Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0, emoji: "🏠"),
                    Project(id: "3", name: "Project Gamma", color: "#8B5CF6", about: nil, order: 0, emoji: "📚")
                ],
                onEdit: { print("Edit clicked") },
                onDelete: { print("Delete clicked") }
            )
            .frame(width: 300, height: 140)
            .background(Theme.Colors.surface)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
