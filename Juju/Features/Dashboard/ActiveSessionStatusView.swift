import SwiftUI

struct ActiveSessionStatusView: View {
    @ObservedObject var sessionManager: SessionManager
    
    var body: some View {
        VStack(spacing: Theme.spacingSmall) {
            HStack {
                Text("Current Activity")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                if sessionManager.activeSession != nil {
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
                }
            }
            
            if let activeSession = sessionManager.activeSession {
                ActiveSessionInfoView(session: activeSession)
            } else {
                NoActiveSessionView()
            }
        }
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
    }
}

struct ActiveSessionInfoView: View {
    let session: SessionRecord
    
    var body: some View {
        HStack(spacing: Theme.spacingMedium) {
            // Activity Type Emoji
            VStack(spacing: Theme.spacingExtraSmall) {
                Text(session.getActivityTypeDisplay().emoji)
                    .font(.system(size: 32, weight: .medium))
                
                Text(session.getActivityTypeDisplay().name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
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
                    
                    Text(formatDuration(session.durationMinutes))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.Colors.accentColor)
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
