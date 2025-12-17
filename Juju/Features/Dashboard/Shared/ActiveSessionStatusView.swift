import SwiftUI

struct ActiveSessionStatusView: View {
    @ObservedObject var sessionManager: SessionManager
    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    
    var body: some View {
        HStack(spacing: Theme.DashboardLayout.chartGap) {
            // Live Pill Indicator (left side)
            Text("Live")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, Theme.DashboardLayout.chartPadding)
                .padding(.vertical, Theme.DashboardLayout.chartPadding / 2) // Reduced vertical padding
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
            HStack(spacing: Theme.DashboardLayout.chartPadding) {
                let project = getProjectForSession()
                Text(project?.emoji ?? sessionManager.activeSession?.getActivityTypeDisplay().emoji ?? "⚡")
                    .font(.system(size: 16, weight: .bold))
                
                Text(sessionManager.activeSession?.projectName ?? "Unknown Project")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            // Live Timer (right side)
            if let activeSession = sessionManager.activeSession {
                LiveTimerView(session: activeSession)
            }
        }
        .padding(.horizontal, Theme.DashboardLayout.chartPadding)
        .padding(.vertical, Theme.DashboardLayout.chartPadding / 3) // Further reduced vertical padding
        .background(
            LinearGradient(
                colors: [Theme.Colors.accentColor, Theme.Colors.accentColor.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider.opacity(0.5), lineWidth: 1)
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
        // Calculate initial duration using DurationCalculator
        let durationMinutes = DurationCalculator.calculateDuration(start: session.startDate, end: session.endDate)
        self._liveDurationSeconds = State(initialValue: durationMinutes * 60)
    }
    
    var body: some View {
        Text(formatDurationWithSeconds(liveDurationSeconds))
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white)
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
