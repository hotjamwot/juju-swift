import SwiftUI

struct ActiveSessionStatusView: View {
    @ObservedObject var sessionManager: SessionManager
    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    private let activityTypeManager = ActivityTypeManager.shared
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Live indicator — small pulsing dot
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.Colors.accentColor)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .fill(Theme.Colors.accentColor.opacity(0.4))
                            .frame(width: 12, height: 12)
                    )
                Text("Live")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.accentColor)
            }
            
            // Subtle divider
            Circle()
                .fill(Theme.Colors.divider)
                .frame(width: 3, height: 3)
            
            // Activity icon + Project name
            let project = getProjectForSession()
            let activity = getActivityForSession()
            Image(systemName: activity?.sfSymbol ?? "bolt")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)
            
            Text(project?.name ?? "Unknown Project")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            // Live Timer
            if let activeSession = sessionManager.activeSession {
                LiveTimerView(session: activeSession)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
    }
    
    private func getProjectForSession() -> Project? {
        guard let activeSession = sessionManager.activeSession else { return nil }
        return projectsViewModel.projects.first { $0.id == activeSession.projectID }
    }
    
    private func getActivityForSession() -> ActivityType? {
        guard let activeSession = sessionManager.activeSession,
              let activityTypeID = activeSession.activityTypeID else { return nil }
        return activityTypeManager.getActivityType(id: activityTypeID)
    }
}

struct LiveTimerView: View {
    let session: SessionRecord
    
    @State private var liveDurationSeconds: Int
    @State private var timer: Timer?
    
    init(session: SessionRecord) {
        self.session = session
        let durationMinutes = session.durationMinutes
        self._liveDurationSeconds = State(initialValue: durationMinutes * 60)
    }
    
    var body: some View {
        Text(formatDurationWithSeconds(liveDurationSeconds))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(Theme.Colors.textSecondary)
            .monospacedDigit()
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
    }
    
    private func startTimer() {
        stopTimer() // Ensure no duplicate timers
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let startTime = session.startDate
            let durationSeconds = Int(Date().timeIntervalSince(startTime))
            liveDurationSeconds = durationSeconds
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatDurationWithSeconds(_ totalSeconds: Int) -> String {
        if totalSeconds <= 0 {
            return "0:00"
        }
        
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}


// MARK: - Preview
#Preview {
    return ActiveSessionStatusView_PreviewsContent()
        .frame(width: 800, height: 100)
        .background(Color(NSColor.windowBackgroundColor))
        .padding()
}

struct ActiveSessionStatusView_PreviewsContent: View {
    @StateObject var sessionManager = SessionManager.shared
    
    var body: some View {
        ActiveSessionStatusView(sessionManager: sessionManager)
            .onAppear {
                // Simulate an active session for preview by starting a session
                sessionManager.startSession(for: "Sample Project")
            }
    }
}
