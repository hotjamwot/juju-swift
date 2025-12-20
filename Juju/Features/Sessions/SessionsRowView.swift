import SwiftUI
import Combine

// MARK: - PulseBarView (Integrated into SessionsRowView)
/// Visual time-of-day pulse bar for sessions
/// Shows when a session happened within the day and how long it lasted
/// Always visible, purely decorative, does not affect row height or interactability
struct PulseBarView: View {
    let startTime: String
    let endTime: String
    let projectColor: Color
    
    // Day window: 07:00 to 23:00 (16 hours)
    private let dayStartHour = 7.0
    private let dayEndHour = 23.0
    private let dayDurationHours: Double = 16.0
    
    var body: some View {
        GeometryReader { geometry in
            let usableWidth = geometry.size.width
            let baselineY = geometry.size.height - 2 // Position baseline at bottom
            
            // Baseline bar (faint) - spans entire usable width with subtle glow
            Rectangle()
                .fill(projectColor.opacity(0.16))
                .frame(height: 2)
                .position(x: usableWidth / 2, y: baselineY)            
            // Pulse segment (active) - positioned and sized based on session time
            if let startX = pulseXPosition(usableWidth: usableWidth, timeString: startTime),
               let endX = pulseXPosition(usableWidth: usableWidth, timeString: endTime) {
                let width = max(0, endX - startX)
                
                Rectangle()
                    .fill(projectColor.opacity(0.45))
                    .frame(width: width, height: 2)
                    .cornerRadius(2)
                    .position(x: startX + (width / 2), y: baselineY - 1) // Center the pulse between start and end
                    .animation(.easeInOut(duration: 0.25), value: startTime)
                    .animation(.easeInOut(duration: 0.25), value: endTime)
            }
        }
        .frame(height: 6) // Total height: 3px baseline + 3px pulse
    }
    
    /// Calculate X position for the pulse segment based on time string
    private func pulseXPosition(usableWidth: CGFloat, timeString: String) -> CGFloat? {
        guard let components = timeStringToComponents(timeString) else {
            return nil
        }
        
        let totalHours = Double(components.hour) + (Double(components.minute) / 60.0)
        let clampedTime = max(min(totalHours, dayEndHour), dayStartHour)
        let progress = (clampedTime - dayStartHour) / dayDurationHours
        let position = CGFloat(progress) * usableWidth
        
        return position
    }
    
    
    /// Parse time string (HH:mm:ss) to hour and minute components
    private func timeStringToComponents(_ timeString: String) -> (hour: Int, minute: Int)? {
        let components = timeString.components(separatedBy: ":")
        
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }
        
        // Validate hour and minute ranges
        guard hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 else {
            return nil
        }
        
        return (hour: hour, minute: minute)
    }
}

// MARK: - Session Observer Helper
class SessionObserver: ObservableObject {
    @Published var refreshTrigger = UUID()
    private var observer: NSObjectProtocol?
    
    init(sessionID: String) {
        observer = NotificationCenter.default.addObserver(
            forName: .sessionDidEnd,
            object: nil,
            queue: .main
        ) { notification in
            if let observedSessionID = notification.userInfo?["sessionID"] as? String,
               observedSessionID == sessionID {
                DispatchQueue.main.async {
                    self.refreshTrigger = UUID()
                }
            }
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

/// Fixed-height row view for displaying session information in list layout
/// Simplified view with all UI elements visible at once, no interactive behavior
struct SessionsRowView: View {
    let session: SessionRecord
    let projects: [Project]
    let activityTypes: [ActivityType]
    let onDelete: ((SessionRecord) -> Void)
    let onNotesChanged: ((String) -> Void)? // New callback for notes changes
    let onShowNoteOverlay: ((SessionRecord) -> Void)? // Callback to show overlay in SessionsView
    let onProjectChanged: (() -> Void)? // New callback to notify parent when project changes
    
    // Interactive state for hover effects
    @State private var isHovering = false
    @State private var isProjectHovering = false
    @State private var isEditing = false
    @State private var editedNotes: String
    
    // Project selection state
    @State private var showingProjectPopover = false
    @State private var selectedProjectID: String?
    
    // Phase selection state
    @State private var showingPhasePopover = false
    @State private var selectedPhaseID: String?
    @State private var phasePopoverKey: UUID = UUID() // Force popover refresh when project changes
    
    // Activity type selection state
    @State private var showingActivityTypePopover = false
    @State private var selectedActivityTypeID: String?
    @State private var isActivityTypeHovering = false
    
    // Mood selection state
    @State private var showingMoodPopover = false
    @State private var selectedMood: Int?
    @State private var isMoodHovering = false
    
    // Milestone selection state
    @State private var showingMilestonePopover = false
    @State private var milestoneText: String = ""
    @State private var isMilestoneHovering = false
    
    // Time picker state for start time
    @State private var showingStartTimePicker = false
    @State private var isStartTimeHovering = false
    
    // Time picker state for end time
    @State private var showingEndTimePicker = false
    @State private var isEndTimeHovering = false
    
    // Date picker state
    @State private var showingDatePicker = false
    @State private var isDateHovering = false
    
    // Phase selection hover state
    @State private var isPhaseHovering = false
    
    // State to trigger refresh when session data changes
    @StateObject private var sessionObserver: SessionObserver
    
    // Track the current session state for reactive updates
    @State private var currentSession: SessionRecord
    
    // Track project data version to ensure popover shows correct phases
    @State private var projectDataVersion: UUID = UUID()
    
    // Initialize with session observer
    init(session: SessionRecord, projects: [Project], activityTypes: [ActivityType], onDelete: ((SessionRecord) -> Void)? = nil, onNotesChanged: ((String) -> Void)? = nil, onShowNoteOverlay: ((SessionRecord) -> Void)? = nil, onProjectChanged: (() -> Void)? = nil) {
        self.session = session
        self.projects = projects
        self.activityTypes = activityTypes
        self.onDelete = onDelete ?? { _ in }
        self.onNotesChanged = onNotesChanged
        self.onShowNoteOverlay = onShowNoteOverlay
        self.onProjectChanged = onProjectChanged
        self._editedNotes = State(initialValue: session.notes)
        self._sessionObserver = StateObject(wrappedValue: SessionObserver(sessionID: session.id))
        self._currentSession = State(initialValue: session)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main row content - consolidated display logic
            HStack(spacing: Theme.Row.compactSpacing) {
                // Project capsule with popover (fixed width, left aligned)
                Button(action: {
                    showingProjectPopover = true
                    selectedProjectID = currentSession.projectID
                }) {
                    HStack(spacing: 6) {
                        // Project color dot
                        Circle()
                            .fill(projectColor)
                            .frame(width: Theme.Row.projectDotSize, height: Theme.Row.projectDotSize)
                        
                        // Project emoji
                        Text(projectEmoji)
                            .font(.system(size: 12))
                        
                        // Project name
                        Text(currentSession.projectName)
                            .font(Theme.Fonts.body.weight(.semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(projectColor.opacity(0.1))
                            .opacity(isProjectHovering ? 1.0 : 0.0)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(projectColor.opacity(0.3), lineWidth: 1)
                            .opacity(isProjectHovering ? 1.0 : 0.0)
                    )
                    .contentShape(Rectangle()) // Make entire capsule tappable
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    isProjectHovering = hovering
                }
                .popover(isPresented: $showingProjectPopover) {
                    InlineSelectionPopover(
                        items: projects.filter { !$0.archived }, // Only show active (non-archived) projects
                        currentID: currentSession.projectID, // Use current session's projectID directly
                        onItemSelected: { project in
                            // Update session with new project and reset phase
                            updateSessionProject(project)
                        },
                        onDismiss: {
                            showingProjectPopover = false
                        }
                    )
                    .padding()
                }
                .frame(width: 200, alignment: .leading) // Fixed width for project capsule, left aligned
                .padding(.leading, Theme.Row.contentPadding)
                
                // Session details (horizontal layout with optimized spacing)
                HStack(spacing: Theme.Row.compactSpacing) {
                    // Start and End Time (fixed width) - now clickable with hover effects
                    HStack(spacing: 2) {
                        // Date picker (compact clock icon button)
                        Button(action: {
                            showingDatePicker = true
                        }) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            isDateHovering = hovering
                        }
                        .popover(isPresented: $showingDatePicker) {
                            DatePickerPopover(
                                title: "Edit Date",
                                dateString: formatDate(currentSession.startDate),
                                onDateChanged: { newDate in
                                    updateSessionDate(newDate)
                                },
                                onDismiss: {
                                    showingDatePicker = false
                                }
                            )
                            .padding()
                        }
                        .background(
                            Theme.Colors.divider.opacity(0.2)
                                .opacity(isDateHovering ? 0.4 : 0.2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .stroke(projectColor.opacity(0.3), lineWidth: 1)
                                .opacity(isDateHovering ? 1.0 : 0.0)
                        )
                        .clipShape(Circle())
                        .contentShape(Rectangle()) // Make entire area tappable
                        .frame(width: 28, height: 28)
                        // Start Time
                        Button(action: {
                            showingStartTimePicker = true
                        }) {
                            Text(formatTime(currentSession.startDate))
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            isStartTimeHovering = hovering
                        }
                        .popover(isPresented: $showingStartTimePicker) {
                            TimePickerPopover(
                                title: "Edit Start Time",
                                timeString: formatTime(currentSession.startDate),
                                onTimeChanged: { newStartTime in
                                    updateSessionStartTime(newStartTime)
                                },
                                onDismiss: {
                                    showingStartTimePicker = false
                                }
                            )
                            .padding()
                        }
                        .background(
                            Theme.Colors.divider.opacity(0.2)
                                .opacity(isStartTimeHovering ? 0.4 : 0.2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .stroke(projectColor.opacity(0.3), lineWidth: 1)
                                .opacity(isStartTimeHovering ? 1.0 : 0.0)
                        )
                        .clipShape(Capsule())
                        .contentShape(Rectangle()) // Make entire area tappable
                        
                        Text("-")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                        
                        // End Time
                        Button(action: {
                            showingEndTimePicker = true
                        }) {
                            Text(formatTime(currentSession.endDate))
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            isEndTimeHovering = hovering
                        }
                        .popover(isPresented: $showingEndTimePicker) {
                            TimePickerPopover(
                                title: "Edit End Time",
                                timeString: formatTime(currentSession.endDate),
                                onTimeChanged: { newEndTime in
                                    updateSessionEndTime(newEndTime)
                                },
                                onDismiss: {
                                    showingEndTimePicker = false
                                }
                            )
                            .padding()
                        }
                        .background(
                            Theme.Colors.divider.opacity(0.2)
                                .opacity(isEndTimeHovering ? 0.4 : 0.2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .stroke(projectColor.opacity(0.3), lineWidth: 1)
                                .opacity(isEndTimeHovering ? 1.0 : 0.0)
                        )
                        .clipShape(Capsule())
                        .contentShape(Rectangle()) // Make entire area tappable
                    }
                    .frame(width: 140)
                    
                    // Activity Type (with fallback to "Uncategorized")
                    if let activityType = getActivityTypeDisplay() {
                        Button(action: {
                            showingActivityTypePopover = true
                            selectedActivityTypeID = currentSession.activityTypeID
                        }) {
                            HStack(spacing: 4) {
                                Text(activityType.emoji)
                                    .font(.system(size: 10))
                                Text(activityType.name)
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Theme.Colors.divider.opacity(0.2)
                                    .opacity(isActivityTypeHovering ? 0.4 : 0.2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .stroke(projectColor.opacity(0.3), lineWidth: 1)
                                    .opacity(isActivityTypeHovering ? 1.0 : 0.0)
                            )
                            .clipShape(Capsule())
                            .contentShape(Rectangle()) // Make entire area tappable
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            isActivityTypeHovering = hovering
                        }
                        .popover(isPresented: $showingActivityTypePopover) {
                            ActivityTypeSelectionPopover(
                                activityTypes: activityTypes,
                                currentActivityTypeID: currentSession.activityTypeID,
                                onActivityTypeSelected: { activityType in
                                    updateSessionActivityType(activityType)
                                },
                                onDismiss: {
                                    showingActivityTypePopover = false
                                }
                            )
                            .padding()
                        }
                        .frame(minWidth: 100, maxWidth: 140)
                    } else {
                        // Empty space when no activity type - make it clickable to add one
                        Button(action: {
                            showingActivityTypePopover = true
                            selectedActivityTypeID = currentSession.activityTypeID
                        }) {
                            HStack(spacing: 4) {
                                Text("📝")
                                    .font(.system(size: 10))
                                Text("Activity Type")
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Theme.Colors.divider.opacity(0.2)
                                    .opacity(isActivityTypeHovering ? 0.4 : 0.2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .stroke(projectColor.opacity(0.3), lineWidth: 1)
                                    .opacity(isActivityTypeHovering ? 1.0 : 0.0)
                            )
                            .clipShape(Capsule())
                            .contentShape(Rectangle()) // Make entire area tappable
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            isActivityTypeHovering = hovering
                        }
                        .popover(isPresented: $showingActivityTypePopover) {
                            ActivityTypeSelectionPopover(
                                activityTypes: activityTypes,
                                currentActivityTypeID: currentSession.activityTypeID,
                                onActivityTypeSelected: { activityType in
                                    updateSessionActivityType(activityType)
                                },
                                onDismiss: {
                                    showingActivityTypePopover = false
                                }
                            )
                            .padding()
                        }
                        .frame(minWidth: 100, maxWidth: 140)
                    }
                    
                    // Project Phase (fixed width)
                    Button(action: {
                        showingPhasePopover = true
                        selectedPhaseID = currentSession.projectPhaseID
                    }) {
                        if let phaseName = getProjectPhaseDisplay() {
                            HStack(spacing: 4) {
                                Image(systemName: "play.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                                Text(phaseName)
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        } else {
                            // Empty space when no phase - make it clickable to add a phase
                            Image(systemName: "play.circle")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        isPhaseHovering = hovering
                    }
                    .popover(isPresented: $showingPhasePopover) {
                        // Always get the current project to ensure we show the correct phases
                        // Include projectDataVersion as a dependency to force refresh when project data changes
                        if let projectID = currentSession.projectID,
                           let project = projects.first(where: { $0.id == projectID }) {
                            PhaseSelectionPopover(
                                project: project,
                                currentPhaseID: currentSession.projectPhaseID,
                                onPhaseSelected: { phase in
                                    updateSessionPhase(phase)
                                },
                                onDismiss: {
                                    showingPhasePopover = false
                                }
                            )
                            .padding()
                            .id(projectDataVersion) // Force refresh when project data version changes
                        }
                    }
                    .background(
                        Theme.Colors.divider.opacity(0.2)
                            .opacity(isPhaseHovering ? 0.4 : 0.2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 999)
                            .stroke(projectColor.opacity(0.3), lineWidth: 1)
                            .opacity(isPhaseHovering ? 1.0 : 0.0)
                    )
                    .clipShape(Capsule())
                    .contentShape(Rectangle()) // Make entire area tappable
                    .frame(width: 100)
                    
                    // Milestone (flexible width)
                    Button(action: {
                        showingMilestonePopover = true
                        milestoneText = currentSession.milestoneText ?? ""
                    }) {
                        if let milestone = currentSession.milestoneText, !milestone.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(projectColor.opacity(0.9))
                                Text(milestone)
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Theme.Colors.divider.opacity(0.2))
                            .clipShape(Capsule())
                        } else {
                            // Grayed out star icon when no milestone (nil or empty string)
                            Image(systemName: "star")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        isMilestoneHovering = hovering
                    }
                    .popover(isPresented: $showingMilestonePopover) {
                        MilestoneSelectionPopover(
                            currentMilestone: currentSession.milestoneText,
                            onMilestoneChanged: { milestone in
                                updateSessionMilestone(milestone)
                            },
                            onDismiss: {
                                showingMilestonePopover = false
                            }
                        )
                        .padding()
                    }
                    .background(
                        Theme.Colors.divider.opacity(0.2)
                            .opacity(isMilestoneHovering ? 0.4 : 0.2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 999)
                            .stroke(projectColor.opacity(0.3), lineWidth: 1)
                            .opacity(isMilestoneHovering ? 1.0 : 0.0)
                    )
                    .clipShape(Capsule())
                    .contentShape(Rectangle()) // Make entire area tappable
                    .frame(minWidth: 160, maxWidth: 180)
                    
                    // Notes (expanded flexible width - takes more space)
                    if !currentSession.notes.isEmpty {
                        Text(currentSession.notes)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                            .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle()) // Make entire area tappable
                            .onTapGesture {
                                onShowNoteOverlay?(currentSession)
                            }
                    } else {
                        // Empty space when no notes - expanded to fill more space
                        // Make this tappable too for adding notes
                        Text("No notes")
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
                            .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle()) // Make entire area tappable
                            .onTapGesture {
                                onShowNoteOverlay?(currentSession)
                            }
                    }
                    
                    // Mood (fixed width)
                    Button(action: {
                        showingMoodPopover = true
                        selectedMood = currentSession.mood
                    }) {
                        if let mood = currentSession.mood {
                            Text("\(mood)/10")
                                .font(Theme.Fonts.caption.weight(.semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                        } else {
                            // Empty space when no mood - make it clickable to add a mood
                            Text("Mood")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        isMoodHovering = hovering
                    }
                    .popover(isPresented: $showingMoodPopover) {
                        MoodSelectionPopover(
                            currentMood: currentSession.mood,
                            onMoodSelected: { mood in
                                updateSessionMood(mood)
                            },
                            onDismiss: {
                                showingMoodPopover = false
                            }
                        )
                        .padding()
                    }
                    .background(
                        Theme.Colors.divider.opacity(0.2)
                            .opacity(isMoodHovering ? 0.4 : 0.2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 999)
                            .stroke(projectColor.opacity(0.3), lineWidth: 1)
                            .opacity(isMoodHovering ? 1.0 : 0.0)
                    )
                    .clipShape(Capsule())
                    .contentShape(Rectangle()) // Make entire area tappable
                    .frame(width: 60)
                }
                
                // Duration (moved to far right with flexible width)
                Text(formatDurationFromDates(currentSession.startDate, currentSession.endDate))
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 80)
                
                // Delete button - appears on hover
                Button(action: {
                    onDelete(currentSession)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.error)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(isHovering ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
                .padding(.trailing, Theme.Row.contentPadding)
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
            // Pulse bar overlay at the bottom of the row
            .overlay(alignment: .bottom) {
                PulseBarView(
                    startTime: formatTime(currentSession.startDate),
                    endTime: formatTime(currentSession.endDate),
                    projectColor: projectColor
                )
                .padding(.horizontal, Theme.Row.contentPadding) // Match row's horizontal padding
                .animation(.easeInOut(duration: 0.25), value: currentSession.startDate)
                .animation(.easeInOut(duration: 0.25), value: currentSession.endDate)
            }
            .onHover { hovering in
                isHovering = hovering
            }
            // React to session observer changes to refresh the session data
            .onReceive(sessionObserver.$refreshTrigger) { _ in
                // Reload the session from the data store to get the updated phaseID
                if let updatedSession = SessionManager.shared.allSessions.first(where: { $0.id == session.id }) {
                    DispatchQueue.main.async {
                        self.currentSession = updatedSession
                    }
                }
            }
            // Note: Removed .sessionDidEnd notification handler to avoid conflicts with the delayed refresh trigger
            // The delayed sessionObserver.refreshTrigger handles the refresh properly after session data is updated
        }
    }
    
    // MARK: - Computed Properties
    
    private var projectColor: Color {
        projects.first { $0.name == currentSession.projectName }?.swiftUIColor ?? Theme.Colors.accentColor
    }
    
    private var projectEmoji: String {
        projects.first { $0.name == currentSession.projectName }?.emoji ?? "📁"
    }
    
    /// Get activity type display info with fallback to "Uncategorized" for legacy sessions
    private func getActivityTypeDisplay() -> (name: String, emoji: String)? {
        guard let activityTypeID = currentSession.activityTypeID else {
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
        // If projects array is empty, we can't display phases yet
        guard !projects.isEmpty else {
            return nil
        }
        
        // If no phaseID is set, return nil to show the placeholder state
        guard let projectPhaseID = currentSession.projectPhaseID,
              let projectID = currentSession.projectID else {
            return nil
        }
        
        // Use the projects array passed from SessionsView instead of loading directly
        // This ensures we're using the same data source that's being managed by ProjectsViewModel
        guard let project = projects.first(where: { $0.id == projectID }) else {
            return nil
        }
        
        // Check if the phase exists and is not archived
        guard let phase = project.phases.first(where: { $0.id == projectPhaseID && !$0.archived }) else {
            return nil
        }
        
        return phase.name
    }
    
    private var formattedStartTime: String {
        formatTime(currentSession.startDate)
    }
    
    private var formattedEndTime: String {
        formatTime(currentSession.endDate)
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatTimeFromDateString(_ dateString: String) -> String {
        // Extract time from date string by creating a Date object and formatting it
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
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
    
    // Overload for Date objects
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
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
    
    private func formatDurationFromDates(_ startDate: Date, _ endDate: Date) -> String {
        let durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
        return formatDuration(durationMinutes)
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
    
    private func moodEmoji(for mood: Int) -> String {
        switch mood {
        case 0...2: return "😞"
        case 3...4: return "😟"
        case 5: return "😐"
        case 6: return "🙂"
        case 7: return "😊"
        case 8: return "😄"
        case 9: return "😁"
        case 10: return "🤩"
        default: return "😊"
        }
    }
    
    // MARK: - Project Selection Handler
    
    /// Update session with new project
    /// This method handles the complete project change workflow:
    /// 1. Updates the session with new projectID and projectName
    /// 2. Checks if the current phase exists in the new project
    /// 3. If the phase doesn't exist, clears the phaseID
    /// 4. Immediately updates the session in the data store
    /// 5. Triggers a UI refresh by calling the callback
    /// 6. Forces an immediate refresh of the session observer to update the UI
    private func updateSessionProject(_ project: Project) {
        print("🔄 Updating session \(session.id) project from '\(currentSession.projectName)' to '\(project.name)' (ID: \(project.id))")
        
        // Determine the new phaseID
        var newPhaseID: String? = currentSession.projectPhaseID
        
        if let currentPhaseID = currentSession.projectPhaseID {
            // Check if the current phase exists in the new project
            let phaseExistsInNewProject = project.phases.contains { $0.id == currentPhaseID && !$0.archived }
            
            if !phaseExistsInNewProject {
                // Clear the phaseID if it doesn't exist in the new project
                newPhaseID = nil
                print("⚠️ Phase \(currentPhaseID) not found in project \(project.name), clearing phaseID")
            } else {
                print("✅ Phase \(currentPhaseID) found in project \(project.name)")
            }
        }
        
        // Update the session with new project information and the appropriate phaseID
        // Format date and time from startDate and endDate
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sessionDate = dateFormatter.string(from: currentSession.startDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let sessionStartTime = timeFormatter.string(from: currentSession.startDate)
        let sessionEndTime = timeFormatter.string(from: currentSession.endDate)
        
        let success = SessionManager.shared.updateSessionFull(
            id: session.id,
            date: sessionDate,
            startTime: sessionStartTime,
            endTime: sessionEndTime,
            projectName: project.name,
            notes: session.notes,
            mood: session.mood,
            activityTypeID: session.activityTypeID,
            projectPhaseID: newPhaseID, // Use the determined phaseID
            milestoneText: session.milestoneText
        )
        
        if success {
            print("✅ Successfully updated session \(session.id) with new project")
            // Force immediate refresh of the session observer to update the UI
            // Use a more robust synchronization approach with multiple refresh attempts
            refreshSessionData()
            
            // Force the phase popover to refresh by changing the key
            self.phasePopoverKey = UUID()
            self.projectDataVersion = UUID() // Force project data refresh
            
            // Notify parent that project has changed so it can refresh the view
            onProjectChanged?()
        } else {
            print("❌ Failed to update session \(session.id) with new project")
        }
    }
    
    /// Refresh session data with robust synchronization
    /// This method ensures that the session data is properly updated before refreshing the UI
    private func refreshSessionData() {
        // First attempt: immediate refresh
        DispatchQueue.main.async {
            self.sessionObserver.refreshTrigger = UUID()
        }
        
        // Second attempt: after a short delay to ensure data store is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.sessionObserver.refreshTrigger = UUID()
        }
        
        // Third attempt: after a longer delay for full synchronization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.sessionObserver.refreshTrigger = UUID()
        }
    }
    
    // MARK: - Phase Selection Handler
    
    /// Update session with new phase
    /// This method handles the phase change workflow:
    /// 1. Updates the session with the new phaseID
    /// 2. Immediately updates the session in the data store
    /// 3. Triggers a UI refresh by calling the callback
    /// 4. Forces an immediate refresh of the session observer to update the UI
    private func updateSessionPhase(_ phase: Phase) {
        // Format date and time from startDate and endDate
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sessionDate = dateFormatter.string(from: currentSession.startDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let sessionStartTime = timeFormatter.string(from: currentSession.startDate)
        let sessionEndTime = timeFormatter.string(from: currentSession.endDate)
        
        // Update the session with the new phaseID
        let success = SessionManager.shared.updateSessionFull(
            id: session.id,
            date: sessionDate,
            startTime: sessionStartTime,
            endTime: sessionEndTime,
            projectName: currentSession.projectName,
            notes: session.notes,
            mood: session.mood,
            activityTypeID: session.activityTypeID,
            projectPhaseID: phase.id, // Use the selected phaseID
            milestoneText: session.milestoneText
        )
        
        if success {
            // Force immediate refresh of the session observer to update the UI
            // Use the same robust synchronization approach as project updates
            refreshSessionData()
            
            // Force the phase popover to refresh by changing the key
            self.phasePopoverKey = UUID()
            self.projectDataVersion = UUID() // Force project data refresh
            
            // Notify parent that project has changed so it can refresh the view
            onProjectChanged?()
        }
    }
    
    // MARK: - Activity Type Selection Handler
    
    /// Update session with new activity type
    /// This method handles the activity type change workflow:
    /// 1. Updates the session with the new activityTypeID
    /// 2. Immediately updates the session in the data store
    /// 3. Triggers a UI refresh by calling the callback
    /// 4. Forces an immediate refresh of the session observer to update the UI
    private func updateSessionActivityType(_ activityType: ActivityType) {
        // Format date and time from startDate and endDate
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sessionDate = dateFormatter.string(from: currentSession.startDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let sessionStartTime = timeFormatter.string(from: currentSession.startDate)
        let sessionEndTime = timeFormatter.string(from: currentSession.endDate)
        
        // Update the session with the new activityTypeID
        let success = SessionManager.shared.updateSessionFull(
            id: session.id,
            date: sessionDate,
            startTime: sessionStartTime,
            endTime: sessionEndTime,
            projectName: currentSession.projectName,
            notes: session.notes,
            mood: session.mood,
            activityTypeID: activityType.id, // Use the selected activityTypeID
            projectPhaseID: session.projectPhaseID,
            milestoneText: session.milestoneText
        )
        
        if success {
            // Force immediate refresh of the session observer to update the UI
            // Use the same robust synchronization approach as project and phase updates
            refreshSessionData()
            
            // Notify parent that project has changed so it can refresh the view
            onProjectChanged?()
        }
    }
    
    // MARK: - Mood Selection Handler
    
    /// Update session with new mood
    /// This method handles the mood change workflow:
    /// 1. Updates the session with the new mood value
    /// 2. Immediately updates the session in the data store
    /// 3. Triggers a UI refresh by calling the callback
    /// 4. Forces an immediate refresh of the session observer to update the UI
    private func updateSessionMood(_ mood: Int) {
        // Format date and time from startDate and endDate
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sessionDate = dateFormatter.string(from: currentSession.startDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let sessionStartTime = timeFormatter.string(from: currentSession.startDate)
        let sessionEndTime = timeFormatter.string(from: currentSession.endDate)
        
        // Update the session with the new mood value
        let success = SessionManager.shared.updateSessionFull(
            id: session.id,
            date: sessionDate,
            startTime: sessionStartTime,
            endTime: sessionEndTime,
            projectName: currentSession.projectName,
            notes: session.notes,
            mood: mood, // Use the selected mood value
            activityTypeID: session.activityTypeID,
            projectPhaseID: session.projectPhaseID,
            milestoneText: session.milestoneText
        )
        
        if success {
            // Force immediate refresh of the session observer to update the UI
            // Use the same robust synchronization approach as project, phase, and activity type updates
            refreshSessionData()
            
            // Notify parent that project has changed so it can refresh the view
            onProjectChanged?()
        }
    }
    
    // MARK: - Start Time Selection Handler
    
    /// Update session with new start time
    /// This method handles the start time change workflow:
    /// 1. Updates the session with the new start time
    /// 2. Immediately updates the session in the data store
    /// 3. Triggers a UI refresh by calling the callback
    /// 4. Forces an immediate refresh of the session observer to update the UI
    private func updateSessionStartTime(_ newStartTime: String) {
        // Format date and time from startDate and endDate
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sessionDate = dateFormatter.string(from: currentSession.startDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let sessionStartTime = newStartTime // Use the new start time
        let sessionEndTime = timeFormatter.string(from: currentSession.endDate)
        
        // Update the session with the new start time
        let success = SessionManager.shared.updateSessionFull(
            id: session.id,
            date: sessionDate,
            startTime: sessionStartTime,
            endTime: sessionEndTime,
            projectName: currentSession.projectName,
            notes: session.notes,
            mood: session.mood,
            activityTypeID: session.activityTypeID,
            projectPhaseID: session.projectPhaseID,
            milestoneText: session.milestoneText
        )
        
        if success {
            // Force immediate refresh of the session observer to update the UI
            // Use the same robust synchronization approach as other updates
            refreshSessionData()
            
            // Notify parent that project has changed so it can refresh the view
            onProjectChanged?()
        }
    }
    
    // MARK: - End Time Selection Handler
    
    /// Update session with new end time
    /// This method handles the end time change workflow:
    /// 1. Updates the session with the new end time
    /// 2. Immediately updates the session in the data store
    /// 3. Triggers a UI refresh by calling the callback
    /// 4. Forces an immediate refresh of the session observer to update the UI
    private func updateSessionEndTime(_ newEndTime: String) {
        // Format date and time from startDate and endDate
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sessionDate = dateFormatter.string(from: currentSession.startDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let sessionStartTime = timeFormatter.string(from: currentSession.startDate)
        let sessionEndTime = newEndTime // Use the new end time
        
        // Update the session with the new end time
        let success = SessionManager.shared.updateSessionFull(
            id: session.id,
            date: sessionDate,
            startTime: sessionStartTime,
            endTime: sessionEndTime,
            projectName: currentSession.projectName,
            notes: session.notes,
            mood: session.mood,
            activityTypeID: session.activityTypeID,
            projectPhaseID: session.projectPhaseID,
            milestoneText: session.milestoneText
        )
        
        if success {
            // Force immediate refresh of the session observer to update the UI
            // Use the same robust synchronization approach as other updates
            refreshSessionData()
            
            // Notify parent that project has changed so it can refresh the view
            onProjectChanged?()
        }
    }
    
    // MARK: - Date Selection Handler
    
    /// Update session with new date
    /// This method handles the date change workflow:
    /// 1. Updates the session with the new date
    /// 2. Immediately updates the session in the data store
    /// 3. Triggers a UI refresh by calling the callback
    /// 4. Forces an immediate refresh of the session observer to update the UI
    private func updateSessionDate(_ newDate: String) {
        // Format date and time from startDate and endDate
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sessionDate = newDate // Use the new date
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let sessionStartTime = timeFormatter.string(from: currentSession.startDate)
        let sessionEndTime = timeFormatter.string(from: currentSession.endDate)
        
        // Update the session with the new date
        let success = SessionManager.shared.updateSessionFull(
            id: session.id,
            date: sessionDate,
            startTime: sessionStartTime,
            endTime: sessionEndTime,
            projectName: currentSession.projectName,
            notes: session.notes,
            mood: session.mood,
            activityTypeID: session.activityTypeID,
            projectPhaseID: session.projectPhaseID,
            milestoneText: session.milestoneText
        )
        
        if success {
            // Force immediate refresh of the session observer to update the UI
            // Use the same robust synchronization approach as other updates
            refreshSessionData()
            
            // Notify parent that project has changed so it can refresh the view
            onProjectChanged?()
        }
    }
    
    // MARK: - Milestone Selection Handler
    
    /// Update session with new milestone
    /// This method handles the milestone change workflow:
    /// 1. Updates the session with the new milestone text
    /// 2. Immediately updates the session in the data store
    /// 3. Triggers a UI refresh by calling the callback
    /// 4. Forces an immediate refresh of the session observer to update the UI
    private func updateSessionMilestone(_ milestone: String?) {
        // Format date and time from startDate and endDate
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sessionDate = dateFormatter.string(from: currentSession.startDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let sessionStartTime = timeFormatter.string(from: currentSession.startDate)
        let sessionEndTime = timeFormatter.string(from: currentSession.endDate)
        
        // Update the session with the new milestone text
        let success = SessionManager.shared.updateSessionFull(
            id: session.id,
            date: sessionDate,
            startTime: sessionStartTime,
            endTime: sessionEndTime,
            projectName: currentSession.projectName,
            notes: session.notes,
            mood: session.mood,
            activityTypeID: session.activityTypeID,
            projectPhaseID: session.projectPhaseID,
            milestoneText: milestone // Use the selected milestone text
        )
        
        if success {
            // Force immediate refresh of the session observer to update the UI
            // Use the same robust synchronization approach as other updates
            refreshSessionData()
            
            // Notify parent that project has changed so it can refresh the view
            onProjectChanged?()
        }
    }
}

// MARK: - Time Picker Popover (Moved from InlineSelectionPopover)
/// Popover wrapper for the inline time picker
/// Provides the same interface as other selection popovers
struct TimePickerPopover: View {
    let title: String
    let timeString: String
    let onTimeChanged: (String) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        InlineTimePicker(
            title: title,
            timeString: timeString,
            onTimeChanged: onTimeChanged,
            onDismiss: onDismiss
        )
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionsRowView_Previews: PreviewProvider {
    static var previews: some View {
        // Use live data from shared instances for preview
        SessionsRowView(
            session: SessionRecord(
                id: "1",
                date: "2024-01-15",
                startTime: "09:00:00",
                endTime: "10:30:00",
                durationMinutes: 90,
                projectName: "Project Alpha",
                projectID: "1",
                activityTypeID: "writing",
                projectPhaseID: "phase-1",
                milestoneText: "First Draft Complete",
                notes: "Quick meeting about the new features.",
                mood: 7
            ),
            projects: ProjectsViewModel.shared.projects,
            activityTypes: ActivityTypesViewModel.shared.activeActivityTypes,
            onDelete: { _ in },
            onNotesChanged: { _ in }
        )
        .onAppear {
            // Load live data for preview
            Task {
                await ProjectsViewModel.shared.loadProjects()
                ActivityTypesViewModel.shared.loadActivityTypes()
            }
        }
        .frame(width: 1300, height: 200)
        .background(Theme.Colors.background)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
