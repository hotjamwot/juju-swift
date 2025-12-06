import SwiftUI

/// Compact row view for displaying session information in list layout
/// Now uses sidebar for editing instead of inline editing
struct SessionsRowView: View {
    @Binding var session: SessionRecord
    let projects: [Project]
    
    // Optional editing parameters (for backward compatibility)
    let isEditing: Bool?
    let onEdit: ((SessionRecord) -> Void)?
    let onSave: (() -> Void)?
    let onDelete: ((SessionRecord) -> Void)?
    
    @StateObject private var sidebarState = SidebarStateManager()
    
    // Hover state for interactive feedback
    @State private var isHovering = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row content
            HStack(spacing: Theme.Row.compactSpacing) {
                // Project color dot
                Circle()
                    .fill(projectColor)
                    .frame(width: Theme.Row.projectDotSize, height: Theme.Row.projectDotSize)
                    .padding(.leading, Theme.Row.contentPadding)
                
                // Project emoji
                Text(projectEmoji)
                    .font(.system(size: Theme.Row.emojiSize))
                    .frame(width: 24, alignment: .leading)
                
                // Session details (compact)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(session.projectName)
                            .font(Theme.Fonts.caption.weight(.semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Mood indicator (if set)
                        if let mood = session.mood {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(moodColor(for: mood))
                                Text("\(mood)/10")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(moodColor(for: mood))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(moodColor(for: mood).opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    
                    HStack {
                        // Time info
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("\(formattedStartTime) - \(formattedEndTime)")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Duration
                        Text(formatDuration(session.durationMinutes))
                            .font(Theme.Fonts.caption.weight(.semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                .padding(.vertical, Theme.Row.contentPadding)
                
                Spacer()
                
                // Notes preview (truncated)
                if !session.notes.isEmpty {
                    Text(session.notes)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: 200, alignment: .leading)
                }
                
                // Edit button
                Button(action: {
                    sidebarState.show(.session(session))
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                        Text("Edit")
                            .font(Theme.Fonts.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.divider.opacity(0.3))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .pointingHandOnHover()
                .padding(.trailing, Theme.Row.contentPadding)
            }
            .frame(height: Theme.Row.height)
            .background(
                (isHovering ? Theme.Colors.surface.opacity(Theme.Row.hoverOpacity) : Theme.Colors.surface.opacity(0.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Row.cornerRadius)
                    .stroke(Theme.Colors.divider, lineWidth: 1)
            )
            .cornerRadius(Theme.Row.cornerRadius)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                toggleNotes()
            }
            
            // Expandable notes section
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Theme.Colors.divider)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(Theme.Fonts.caption.weight(.semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        Text(session.notes)
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, Theme.Row.contentPadding)
                    .padding(.bottom, Theme.Row.contentPadding)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var projectColor: Color {
        projects.first { $0.name == session.projectName }?.swiftUIColor ?? Theme.Colors.accentColor
    }
    
    private var projectEmoji: String {
        projects.first { $0.name == session.projectName }?.emoji ?? "📁"
    }
    
    private var formattedStartTime: String {
        formatTime(session.startTime)
    }
    
    private var formattedEndTime: String {
        formatTime(session.endTime)
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ timeString: String) -> String {
        let components = timeString.components(separatedBy: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return timeString
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeStyle = .short
        
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return formatter.string(from: date)
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
    
    private func moodColor(for mood: Int) -> Color {
        switch mood {
        case 1...4: return Theme.Colors.error
        case 5...7: return projectColor.opacity(0.8)
        case 8: return projectColor.opacity(0.8)
        case 9: return projectColor.opacity(0.9)
        case 10: return projectColor
        default: return Theme.Colors.error
        }
    }
    
    private func toggleNotes() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
        }
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionsRowView_Previews: PreviewProvider {
    @State static var session = SessionRecord(
        id: "1",
        date: "2024-01-15",
        startTime: "09:00:00",
        endTime: "10:30:00",
        durationMinutes: 90,
        projectName: "Project Alpha",
        notes: "Quick meeting about the new features.",
        mood: 7
    )
    
    static var previews: some View {
        SessionsRowView(
            session: $session,
            projects: [
                Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0, emoji: "💼"),
                Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0, emoji: "🏠")
            ],
            isEditing: false,
            onEdit: { _ in },
            onSave: { },
            onDelete: { _ in }
        )
        .frame(width: 800)
        .background(Theme.Colors.background)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
