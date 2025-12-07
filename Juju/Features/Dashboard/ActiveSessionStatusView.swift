import SwiftUI

struct ActiveSessionStatusView: View {
    @ObservedObject var sessionManager: SessionManager
    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    
    var body: some View {
        HStack(spacing: Theme.spacingMedium) {
            // Live Pill Indicator (left side)
            Text("Live")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, Theme.spacingSmall)
                .padding(.vertical, Theme.spacingExtraSmall)
                .background(
                    LinearGradient(
                        colors: [Theme.Colors.accentColor, Theme.Colors.accentColor.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(Theme.Design.cornerRadius)
            
            Spacer()
            
            // Project Emoji and Name (centered)
            VStack(spacing: Theme.spacingExtraSmall) {
                let project = getProjectForSession()
                Text(project?.emoji ?? sessionManager.activeSession?.getActivityTypeDisplay().emoji ?? "⚡")
                    .font(.system(size: 24, weight: .bold))
                
                Text(sessionManager.activeSession?.projectName ?? "Unknown Project")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Live Timer (right side)
            if let activeSession = sessionManager.activeSession {
                LiveTimerView(session: activeSession)
            }
        }
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
    }
    
    private func getProjectForSession() -> Project? {
        guard let activeSession = sessionManager.activeSession,
              let projectID = activeSession.projectID else {
            return nil
        }
        return projectsViewModel.projects.first { $0.id == projectID }
    }
}

struct LiveTimerView: View {
    let session: SessionRecord
    
    @State private var liveDurationSeconds: Int
    @State private var timer: Timer?
    
    init(session: SessionRecord) {
        self.session = session
        // Convert initial duration to seconds
        self._liveDurationSeconds = State(initialValue: session.durationMinutes * 60)
    }
    
    var body: some View {
        Text(formatDurationWithSeconds(liveDurationSeconds))
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(Theme.Colors.accentColor)
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
            if let startTime = session.startDateTime {
                let durationSeconds = Int(Date().timeIntervalSince(startTime))
                liveDurationSeconds = durationSeconds
            }
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

struct ActiveSessionInfoView: View {
    let session: SessionRecord
    @ObservedObject var projectsViewModel: ProjectsViewModel
    
    @State private var liveDuration: Int
    @State private var timer: Timer?
    
    init(session: SessionRecord, projectsViewModel: ProjectsViewModel) {
        self.session = session
        self.projectsViewModel = projectsViewModel
        self._liveDuration = State(initialValue: session.durationMinutes)
    }
    
    var body: some View {
        HStack(spacing: Theme.spacingMedium) {
            // Project Type Emoji (more prominent than activity type)
            VStack(spacing: Theme.spacingExtraSmall) {
                // Get project info for the active session
                let project = getProjectForSession()
                
                Text(project?.emoji ?? session.getActivityTypeDisplay().emoji)
                    .font(.system(size: 40, weight: .bold))
                    .scaleEffect(project != nil ? 1.2 : 1.0)
                
                Text(project?.name ?? session.getActivityTypeDisplay().name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(Theme.spacingMedium)
            .background(Theme.Colors.background)
            .cornerRadius(Theme.Design.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                    .stroke(Theme.Colors.divider, lineWidth: 1)
            )
            
            // Session Details
            VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
                HStack {
                    Text("Working on:")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: Theme.spacingExtraSmall) {
                        Text(session.projectName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
                
                HStack {
                    Text("Started:")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Spacer()
                    
                    if let startTime = session.startDateTime {
                        Text(startTime, style: .time)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
                
                HStack {
                    Text("Duration:")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Spacer()
                    
                    // Live timer that updates every second
                    Text(formatDuration(liveDuration))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.accentColor)
                        .onAppear {
                            startTimer()
                        }
                        .onDisappear {
                            stopTimer()
                        }
                }
                
                if let milestoneText = session.milestoneText, !milestoneText.isEmpty {
                    HStack {
                        Text("Milestone:")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text(milestoneText)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
            }
            .padding(Theme.spacingMedium)
            .background(Theme.Colors.background)
            .cornerRadius(Theme.Design.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                    .stroke(Theme.Colors.divider, lineWidth: 1)
            )
            
            Spacer()
        }
        .padding(.horizontal, Theme.spacingMedium)
    }
    
    private func getProjectForSession() -> Project? {
        guard let projectID = session.projectID else {
            return nil
        }
        return projectsViewModel.projects.first { $0.id == projectID }
    }
    
    private func startTimer() {
        stopTimer() // Ensure no duplicate timers
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let startTime = session.startDateTime {
                let durationMs = Date().timeIntervalSince(startTime)
                liveDuration = Int(round(durationMs / 60))
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct NoActiveSessionView: View {
    var body: some View {
        VStack(spacing: Theme.spacingMedium) {
            Text("No active session")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.Colors.textSecondary)
            
            Text("Start a new session to track your creative work")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.background)
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
    }
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

// MARK: - Preview
#Preview {
    return ActiveSessionStatusView_PreviewsContent()
        .frame(width: 600, height: 200)
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
