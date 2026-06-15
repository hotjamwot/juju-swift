import SwiftUI

struct ActiveSessionStatusView: View {
    @ObservedObject var sessionManager: SessionManager
    @StateObject private var projectsViewModel = ProjectsViewModel.shared
    private let activityTypeManager = ActivityTypeManager.shared
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header row (always visible)
            headerRow
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            
            // Expanded detail panel (conditionally visible)
            if isExpanded {
                Divider()
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                
                detailPanel
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
        .onAppear {
            applySmartDefaults()
        }
    }
    
    // MARK: - Header Row
    
    private var headerRow: some View {
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
            
            // Chevron indicator
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
    }
    
    // MARK: - Detail Panel
    
    @ViewBuilder
    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Action Field
            VStack(alignment: .leading, spacing: 4) {
                Text("Action")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                TextField("What did you accomplish?", text: $sessionManager.currentAction)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.cardSurface)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            }
            
            // Notes Field
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                TextEditor(text: $sessionManager.currentNotes)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(height: 80)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.cardSurface)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            }
            
            // Activity Type & Phase (side-by-side)
            HStack(spacing: Theme.Spacing.md) {
                // Activity Type Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity Type")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Picker("", selection: $sessionManager.currentActivityTypeID) {
                        Text("None").tag(nil as String?)
                        ForEach(activityTypeManager.getActiveActivityTypes()) { type in
                            HStack {
                                Image(systemName: type.sfSymbol)
                                Text(type.name)
                            }.tag(type.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Phase Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phase")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Picker("", selection: $sessionManager.currentProjectPhaseID) {
                        Text("None").tag(nil as String?)
                        if let project = getProjectForSession() {
                            let activePhases = project.phases.filter { !$0.archived }
                            if activePhases.isEmpty {
                                Text("No phases available").tag("no-phases" as String?)
                            } else {
                                ForEach(activePhases) { phase in
                                    Text(phase.name).tag(phase.id as String?)
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(getProjectForSession() == nil)
                }
            }
            
            // Mood & Milestone (side-by-side)
            HStack(spacing: Theme.Spacing.md) {
                // Mood Slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mood")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    HStack(spacing: Theme.Spacing.sm) {
                        Slider(
                            value: Binding(
                                get: { Double(sessionManager.currentMood ?? 5) },
                                set: { sessionManager.currentMood = Int($0.rounded()) }
                            ),
                            in: 0...10,
                            step: 1
                        )
                        .tint(Theme.Colors.accentColor)
                        
                        Text("\(sessionManager.currentMood ?? 5)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.accentColor)
                            .frame(width: 24, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
                
                // Milestone Toggle
                VStack(alignment: .leading, spacing: 4) {
                    Text("Milestone")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Toggle("", isOn: $sessionManager.currentIsMilestone)
                        .labelsHidden()
                        .disabled(sessionManager.currentAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func getProjectForSession() -> Project? {
        guard let activeSession = sessionManager.activeSession else { return nil }
        return projectsViewModel.projects.first { $0.id == activeSession.projectID }
    }
    
    private func getActivityForSession() -> ActivityType? {
        guard let activeSession = sessionManager.activeSession,
              let activityTypeID = activeSession.activityTypeID else { return nil }
        return activityTypeManager.getActivityType(id: activityTypeID)
    }
    
    /// Apply smart defaults from the last session of this project
    private func applySmartDefaults() {
        // Only apply if the fields are still empty (haven't been set by menu bar)
        guard sessionManager.currentActivityTypeID == nil,
              let projectID = sessionManager.currentProjectID else { return }
        
        let sessions = sessionManager.allSessions
            .filter { $0.projectID == projectID }
            .sorted { $0.startDate > $1.startDate }
        
        // Find most recent session with a valid activity type
        for session in sessions {
            if let activityID = session.activityTypeID,
               activityTypeManager.getActivityType(id: activityID) != nil {
                sessionManager.currentActivityTypeID = activityID
                sessionManager.currentProjectPhaseID = session.projectPhaseID
                break
            }
        }
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