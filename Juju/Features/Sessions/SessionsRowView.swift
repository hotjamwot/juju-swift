import SwiftUI

/// Compact row view for displaying session information in list layout
/// Consolidated view that handles both display and expanded states with actions
struct SessionsRowView: View {
    @Binding var session: SessionRecord
    let projects: [Project]
    let activityTypes: [ActivityType]
    let sidebarState: SidebarStateManager
    let onDelete: (SessionRecord) -> Void
    
    // Hover state for interactive feedback
    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var isNotesExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row content - consolidated display logic
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
                        
                        // Activity Type (with fallback to "Uncategorized")
                        if let activityType = getActivityTypeDisplay() {
                            HStack(spacing: 4) {
                                Text(activityType.emoji)
                                    .font(.system(size: 10))
                                Text(activityType.name)
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.divider.opacity(0.2))
                            .clipShape(Capsule())
                        }
                        
                        // Project Phase (if available)
                        if let phaseName = getProjectPhaseDisplay() {
                            HStack(spacing: 4) {
                                Image(systemName: "number.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(projectColor.opacity(0.8))
                                Text(phaseName)
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(projectColor.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        
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
            }
            .frame(height: Theme.Row.height)
            .background(
                Theme.Colors.surface.opacity(0.7)
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
            
            // Expanded state - consolidated notes and actions (only show when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .background(Theme.Colors.divider)
                    
                    // Create a two-column layout: 90% notes, 10% buttons
                    HStack(alignment: .top, spacing: 0) {
                        // Notes Column (90%)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Notes")
                                    .font(Theme.Fonts.caption.weight(.semibold))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                
                                Spacer()
                            }
                            
                            Text(session.notes)
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, Theme.Row.contentPadding)
                        .padding(.vertical, Theme.Row.contentPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Buttons Column (10%)
                        VStack(alignment: .trailing, spacing: Theme.spacingSmall) {
                            // Edit Button
                            Button(action: {
                                sidebarState.show(.session(session))
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12))
                                    Text("Edit Session")
                                        .font(Theme.Fonts.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.Colors.divider.opacity(0.3))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandOnHover()
                            .accessibilityLabel("Edit Session")
                            .accessibilityHint("Opens the session editor to modify session details")
                            
                            // Delete Button
                            Button(action: {
                                onDelete(session)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.Colors.error)
                                    Text("Delete Session")
                                        .font(Theme.Fonts.caption)
                                        .foregroundColor(Theme.Colors.error)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.Colors.error.opacity(0.15))
                                .foregroundColor(Theme.Colors.error)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.Colors.error.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandOnHover()
                            .accessibilityLabel("Delete Session")
                            .accessibilityHint("Deletes this session permanently")
                        }
                        .padding(.trailing, Theme.Row.contentPadding)
                        .padding(.top, Theme.Row.contentPadding)
                    }
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
    
    /// Get activity type display info with fallback to "Uncategorized" for legacy sessions
    private func getActivityTypeDisplay() -> (name: String, emoji: String)? {
        guard let activityTypeID = session.activityTypeID else {
            // Fallback to "Uncategorized" for legacy sessions
            let uncategorized = ActivityTypeManager.shared.getUncategorizedActivityType()
            return (uncategorized.name, uncategorized.emoji)
        }
        
        // Use the passed activity types array to avoid repeated disk access
        let activityType = activityTypes.first { $0.id == activityTypeID }
        if let activityType = activityType {
            return (activityType.name, activityType.emoji)
        } else {
            // Fallback to manager if not found in passed array
            return ActivityTypeManager.shared.getActivityTypeDisplay(id: activityTypeID)
        }
    }
    
    /// Get project phase display name with fallback for legacy sessions
    private func getProjectPhaseDisplay() -> String? {
        guard let projectPhaseID = session.projectPhaseID,
              let projectID = session.projectID else {
            return nil
        }
        
        let projects = ProjectManager.shared.loadProjects()
        guard let project = projects.first(where: { $0.id == projectID }),
              let phase = project.phases.first(where: { $0.id == projectPhaseID && !$0.archived }) else {
            return nil
        }
        
        return phase.name
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
        projectID: "1",
        activityTypeID: "writing",
        projectPhaseID: "phase-1",
        milestoneText: nil,
        notes: "Quick meeting about the new features.",
        mood: 7
    )
    
    static var previews: some View {
        SessionsRowView(
            session: $session,
            projects: [
                Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0, emoji: "💼", phases: [
                    Phase(id: "phase-1", name: "Planning", order: 0, archived: false),
                    Phase(id: "phase-2", name: "Development", order: 1, archived: false)
                ]),
                Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0, emoji: "🏠")
            ],
            activityTypes: [
                ActivityType(id: "writing", name: "Writing", emoji: "✍️", description: "Drafting and creating new content", archived: false),
                ActivityType(id: "editing", name: "Editing", emoji: "✂️", description: "Refining and improving existing content", archived: false)
            ],
            sidebarState: SidebarStateManager(),
            onDelete: { _ in }
        )
        .frame(width: 800)
        .background(Theme.Colors.background)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
