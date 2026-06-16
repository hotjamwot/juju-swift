import SwiftUI

/// Info panel displayed below the 90-day stacked bar chart.
///
/// Shows per-session details for the currently hovered day (or a milestone date).
/// Each session row displays the project colour, action, start/end time, duration,
/// and a truncated note preview.
struct DaySessionInfoPanel: View {
    /// The day stack to display — driven by chart hover or milestone hover.
    let dayStack: DayStack?
    
    // MARK: - Formatting Helpers
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()
    
    private let notePreviewLimit = 80
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let day = dayStack {
                dayContent(day)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(Theme.Design.blockCornerRadius)
        .animation(.easeOut(duration: 0.12), value: dayStack?.id)
    }
    
    // MARK: - Placeholder
    
    @ViewBuilder
    private var placeholder: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "cursorarrow.motionlines")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
            Text("Hover a day to see session details")
                .font(Theme.Fonts.narrative)
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.xs)
    }
    
    // MARK: - Day Content
    
    @ViewBuilder
    private func dayContent(_ day: DayStack) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Header: date + total
            HStack(spacing: Theme.Spacing.xs) {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(Theme.Fonts.subheader)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                if day.totalHours > 0 {
                    Text("\(formattedHours(day.totalHours)) total")
                        .font(Theme.Fonts.narrativeAccent)
                        .foregroundColor(Theme.Colors.accentColor)
                }
                
                Spacer()
                
                if day.isMilestone {
                    HStack(spacing: Theme.Spacing.micro) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Theme.Colors.milestone)
                        Text("Milestone")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.milestone)
                    }
                }
            }
            
            if day.sessions.isEmpty {
                // No sessions — show empty state
                Text("No sessions")
                    .font(Theme.Fonts.narrative)
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                    .padding(.vertical, Theme.Spacing.xxs)
            } else {
                Divider()
                    .background(Theme.Colors.divider.opacity(0.3))
                
                // Session rows — sorted by start time
                ForEach(day.sessions.sorted(by: { $0.startDate < $1.startDate })) { session in
                    sessionRow(session)
                }
            }
        }
    }
    
    // MARK: - Session Row
    
    @ViewBuilder
    private func sessionRow(_ session: SessionRecord) -> some View {
        // Resolve project info from the DayStack's segments (avoids singleton coupling)
        let segment = dayStack?.segments.first { $0.projectID == session.projectID }
        let projectColor = Color(hex: segment?.color ?? "#999999")
        let projectName = segment?.projectName ?? "Unknown"
        let projectEmoji = segment?.emoji ?? Project.defaultEmoji
        
        VStack(alignment: .leading, spacing: Theme.Spacing.micro) {
            // Line 1: Colour dot + emoji + project name + time range + duration
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(projectColor)
                    .frame(width: 6, height: 6)
                
                Text(projectEmoji)
                    .font(Theme.Fonts.caption)
                
                Text(projectName)
                    .font(Theme.Fonts.narrative.weight(.semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                // Time range
                Text("\(Self.timeFormatter.string(from: session.startDate)) – \(Self.timeFormatter.string(from: session.endDate))")
                    .font(Theme.Fonts.caption.monospaced())
                    .foregroundColor(Theme.Colors.textSecondary)
                
                // Duration
                Text(formattedDuration(session.durationMinutes))
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            // Line 2: Action text (if present)
            if let action = session.action, !action.isEmpty {
                HStack(spacing: Theme.Spacing.micro) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
                    Text(action)
                        .font(Theme.Fonts.narrative)
                        .foregroundColor(Theme.Colors.textPrimary.opacity(0.85))
                        .lineLimit(1)
                }
            }
            
            // Line 3: Note preview (if present)
            if !session.notes.isEmpty {
                HStack(spacing: Theme.Spacing.micro) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.4))
                    Text(String(session.notes.prefix(notePreviewLimit)))
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                    if session.notes.count > notePreviewLimit {
                        Text("…")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xxs)
        
        // Separator between sessions (not after the last one)
        if session.id != dayStack?.sessions.last?.id {
            Divider()
                .background(Theme.Colors.divider.opacity(0.2))
        }
    }
    
    // MARK: - Formatting
    
    private func formattedHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
    
    private func formattedDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(m)m"
    }
}

// MARK: - Preview

#Preview("With data") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    
    let project = Project(name: "Writing", color: "#E15759", order: 0, emoji: "📝")
    
    let session1 = SessionRecord(
        id: UUID().uuidString,
        startDate: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: today)!,
        endDate: calendar.date(bySettingHour: 11, minute: 45, second: 0, of: today)!,
        projectID: project.id,
        action: "Finished the intro chapter draft",
        isMilestone: true,
        notes: "Spent the morning refining the opening paragraphs. The narrative arc is starting to feel right — need to revisit the second section tomorrow."
    )
    
    let session2 = SessionRecord(
        id: UUID().uuidString,
        startDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!,
        endDate: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: today)!,
        projectID: project.id,
        action: "Research for chapter two",
        notes: ""
    )
    
    let dayStack = DayStack(
        date: today,
        segments: [ProjectSegment(projectID: project.id, projectName: project.name, emoji: project.emoji, color: project.color, hours: 3.75)],
        isMilestone: true,
        sessions: [session1, session2]
    )
    
    DaySessionInfoPanel(dayStack: dayStack)
        .padding()
        .frame(width: 500)
        .background(Theme.Colors.background)
}

#Preview("Empty state") {
    DaySessionInfoPanel(dayStack: nil)
        .padding()
        .frame(width: 500)
        .background(Theme.Colors.background)
}