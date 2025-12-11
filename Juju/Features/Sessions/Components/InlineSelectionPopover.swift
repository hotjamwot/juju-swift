import SwiftUI

// MARK: - Generic Selection Item Protocol
protocol SelectionItem: Identifiable, Hashable {
    var displayName: String { get }
    var displayEmoji: String? { get }
    var displayColor: Color? { get }
}

// MARK: - Selection Item ID Wrapper
/// Wrapper to ensure we always work with String IDs for selection state
struct SelectionItemWrapper<Item: SelectionItem>: SelectionItem {
    let wrapped: Item
    
    var id: String {
        String(describing: wrapped.id)
    }
    
    var displayName: String {
        wrapped.displayName
    }
    
    var displayEmoji: String? {
        wrapped.displayEmoji
    }
    
    var displayColor: Color? {
        wrapped.displayColor
    }
}

// MARK: - Project Selection Item Extension
extension Project: SelectionItem {
    var displayName: String {
        name
    }
    
    var displayEmoji: String? {
        emoji
    }
    
    var displayColor: Color? {
        swiftUIColor
    }
}

// MARK: - Inline Selection Popover
/// Generic popover view for selecting from a list of items
/// Can be used for projects, activity types, phases, etc.
struct InlineSelectionPopover<Item: SelectionItem>: View {
    let items: [Item]
    let currentID: String?
    let onItemSelected: (Item) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedID: String?
    
    var filteredItems: [Item] {
        // Sort by name, but put current item first if it exists
        var sorted = items.sorted { $0.displayName < $1.displayName }
        
        if let currentID = currentID,
           let currentIndex = sorted.firstIndex(where: { String(describing: $0.id) == currentID }) {
            let currentItem = sorted.remove(at: currentIndex)
            sorted.insert(currentItem, at: 0)
        }
        
        return sorted
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Items list (clean and simple - no title, no padding, no background)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredItems) { item in
                        ProjectSelectionRow(
                            item: item,
                            isSelected: false, // Remove the tick - we don't need to show selection
                            onSelected: {
                                selectedID = String(describing: item.id)
                                onItemSelected(item)
                                onDismiss()
                            }
                        )
                    }
                }
            }
            .frame(minHeight: 80, maxHeight: 240)
        }
        .frame(minWidth: 200, maxWidth: 240)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onDisappear {
            // Clear focus when popover disappears to prevent blue outline
            selectedID = nil
        }
    }
    
    // MARK: - Project Selection Row
    @ViewBuilder
    private func ProjectSelectionRow(item: Item, isSelected: Bool, onSelected: @escaping () -> Void) -> some View {
        Button(action: onSelected) {
            HStack {
                // Color indicator (if available)
                if let color = item.displayColor {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                } else {
                    // Empty space for alignment
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 10, height: 10)
                }
                
                // Emoji (if available)
                if let emoji = item.displayEmoji {
                    Text(emoji)
                        .font(.system(size: 12))
                        .padding(.trailing, 4)
                }
                
                // Item name
                Text(item.displayName)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                // Checkmark for selected
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.accentColor)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle()) // Make entire row tappable
        }
        .buttonStyle(ProjectSelectionButtonStyle())
    }
    
    // MARK: - Custom Button Style for Hover Effects
    private struct ProjectSelectionButtonStyle: ButtonStyle {
        @State private var isHovering = false
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(
                    Group {
                        if isHovering {
                            Theme.Colors.divider.opacity(0.2)
                        } else {
                            Color.clear
                        }
                    }
                )
                .onHover { hovering in
                    isHovering = hovering
                }
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

// MARK: - Activity Type Selection Item Extension
extension ActivityType: SelectionItem {
    var displayName: String {
        name
    }
    
    var displayEmoji: String? {
        return emoji
    }
    
    var displayColor: Color? {
        return nil // Activity types don't have colors
    }
}

// MARK: - Phase Selection Item Extension
extension Phase: SelectionItem {
    var displayName: String {
        name
    }
    
    var displayEmoji: String? {
        return nil // Phases don't have emojis
    }
    
    var displayColor: Color? {
        return nil // Phases don't have colors
    }
}

// MARK: - Mood Selection Item
/// Represents a mood value for selection in the mood picker
struct MoodItem: SelectionItem {
    let id: String
    let moodValue: Int
    
    var displayName: String {
        "\(moodValue)/10"
    }
    
    var displayEmoji: String? {
        moodEmoji(for: moodValue)
    }
    
    var displayColor: Color? {
        moodColor(for: moodValue)
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
    
    private func moodColor(for mood: Int) -> Color {
        switch mood {
        case 0...2: return Theme.Colors.error
        case 3...4: return Color.orange
        case 5: return Color.gray
        case 6: return Color.blue.opacity(0.7)
        case 7: return Color.green.opacity(0.8)
        case 8: return Color.green
        case 9: return Color.yellow
        case 10: return Theme.Colors.accentColor
        default: return Color.gray
        }
    }
}

// MARK: - Mood Selection Popover
/// Popover view for selecting a mood value (0-10)
struct MoodSelectionPopover: View {
    let currentMood: Int?
    let onMoodSelected: (Int) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedMood: Int?
    @FocusState private var isFocused: Bool
    
    // Create mood items for values 0-10
    private let moodItems: [MoodItem] = (0...10).map { MoodItem(id: String($0), moodValue: $0) }
    
    var body: some View {
        VStack(spacing: 0) {
            // Mood items list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(moodItems) { moodItem in
                        MoodSelectionRow(
                            moodItem: moodItem,
                            isSelected: false, // Remove the tick - we don't need to show selection
                            onSelected: {
                                selectedMood = moodItem.moodValue
                                onMoodSelected(moodItem.moodValue)
                                onDismiss()
                            }
                        )
                    }
                }
            }
            .frame(minHeight: 80, maxHeight: 200)
        }
        .frame(minWidth: 140, maxWidth: 160)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onDisappear {
            // Clear focus when popover disappears to prevent blue outline
            isFocused = false
        }
    }
    
    // MARK: - Mood Selection Row
    @ViewBuilder
    private func MoodSelectionRow(moodItem: MoodItem, isSelected: Bool, onSelected: @escaping () -> Void) -> some View {
        Button(action: onSelected) {
            HStack {
                // Emoji
                Text(moodItem.displayEmoji ?? "😊")
                    .font(.system(size: 12))
                    .padding(.trailing, 4)
                
                // Mood value and description
                Text(moodItem.displayName)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                // Checkmark for selected
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.accentColor)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle()) // Make entire row tappable
        }
        .buttonStyle(MoodSelectionButtonStyle())
    }
    
    // MARK: - Custom Button Style for Hover Effects
    private struct MoodSelectionButtonStyle: ButtonStyle {
        @State private var isHovering = false
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(
                    Group {
                        if isHovering {
                            Theme.Colors.divider.opacity(0.2)
                        } else {
                            Color.clear
                        }
                    }
                )
                .onHover { hovering in
                    isHovering = hovering
                }
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

// MARK: - Activity Type Selection Popover (Convenience Wrapper)
/// Convenience wrapper for activity type selection
struct ActivityTypeSelectionPopover: View {
    let activityTypes: [ActivityType]
    let currentActivityTypeID: String?
    let onActivityTypeSelected: (ActivityType) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        InlineSelectionPopover(
            items: activityTypes,
            currentID: currentActivityTypeID,
            onItemSelected: onActivityTypeSelected,
            onDismiss: onDismiss
        )
    }
}

// MARK: - Project Selection Popover (Convenience Wrapper)
/// Convenience wrapper for project selection
struct ProjectSelectionPopover: View {
    let projects: [Project]
    let currentProjectID: String?
    let onProjectSelected: (Project) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        InlineSelectionPopover(
            items: projects,
            currentID: currentProjectID,
            onItemSelected: onProjectSelected,
            onDismiss: onDismiss
        )
    }
}

// MARK: - Phase Selection Popover
/// Popover view for selecting a phase from a specific project
/// Shows only active (non-archived) phases for the given project
struct PhaseSelectionPopover: View {
    let project: Project
    let currentPhaseID: String?
    let onPhaseSelected: (Phase) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedPhaseID: String?
    
    var activePhases: [Phase] {
        // Get active phases and sort by order
        var phases = project.phases.filter { !$0.archived }.sorted { $0.order < $1.order }
        
        // Put current phase first if it exists
        if let currentPhaseID = currentPhaseID,
           let currentIndex = phases.firstIndex(where: { $0.id == currentPhaseID }) {
            let currentPhase = phases.remove(at: currentIndex)
            phases.insert(currentPhase, at: 0)
        }
        
        return phases
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Phases list
            ScrollView {
                VStack(spacing: 0) {
                    if activePhases.isEmpty {
                        // No phases available
                        VStack(spacing: 8) {
                            Text("No phases")
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            Text("Add phases to this project in the Projects view")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ForEach(activePhases) { phase in
                            PhaseSelectionRow(
                                phase: phase,
                                isSelected: false, // Remove the tick - we don't need to show selection
                                onSelected: {
                                    selectedPhaseID = phase.id
                                    onPhaseSelected(phase)
                                    onDismiss()
                                }
                            )
                        }
                    }
                }
            }
            .frame(minHeight: 80, maxHeight: 240)
        }
        .frame(minWidth: 200, maxWidth: 240)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Phase Selection Row
    @ViewBuilder
    private func PhaseSelectionRow(phase: Phase, isSelected: Bool, onSelected: @escaping () -> Void) -> some View {
        Button(action: onSelected) {
            HStack {
                // Phase name
                Text(phase.name)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                // Checkmark for selected
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.accentColor)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle()) // Make entire row tappable
        }
        .buttonStyle(PhaseSelectionButtonStyle())
    }
    
    // MARK: - Custom Button Style for Hover Effects
    private struct PhaseSelectionButtonStyle: ButtonStyle {
        @State private var isHovering = false
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(
                    Group {
                        if isHovering {
                            Theme.Colors.divider.opacity(0.2)
                        } else {
                            Color.clear
                        }
                    }
                )
                .onHover { hovering in
                    isHovering = hovering
                }
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

// MARK: - Milestone Selection Popover
/// Popover view for editing milestone text with a text field and save functionality
struct MilestoneSelectionPopover: View {
    let currentMilestone: String?
    let onMilestoneChanged: (String?) -> Void
    let onDismiss: () -> Void
    
    @State private var milestoneText: String
    @FocusState private var isTextFieldFocused: Bool
    
    init(currentMilestone: String?, onMilestoneChanged: @escaping (String?) -> Void, onDismiss: @escaping () -> Void) {
        self.currentMilestone = currentMilestone
        self.onMilestoneChanged = onMilestoneChanged
        self.onDismiss = onDismiss
        self._milestoneText = State(initialValue: currentMilestone ?? "")
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Title
            Text("Edit Milestone")
                .font(Theme.Fonts.body.weight(.semibold))
                .foregroundColor(Theme.Colors.textPrimary)
            
            // Text field
            TextField("Enter milestone text", text: $milestoneText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isTextFieldFocused)
                .frame(minWidth: 200, maxWidth: 280)
                .onSubmit {
                    saveMilestone()
                }
            
            // Buttons
            HStack(spacing: 8) {
                Button("Cancel") {
                    cancelMilestone()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Save") {
                    saveMilestone()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(16)
        .frame(minWidth: 240, maxWidth: 320)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            isTextFieldFocused = true
        }
        .onDisappear {
            // Clear focus when popover disappears to prevent blue outline
            isTextFieldFocused = false
        }
    }
    
    private func saveMilestone() {
        let trimmedText = milestoneText.trimmingCharacters(in: .whitespacesAndNewlines)
        let milestoneToSave = trimmedText.isEmpty ? "" : trimmedText
        onMilestoneChanged(milestoneToSave)
        onDismiss()
    }
    
    private func cancelMilestone() {
        onDismiss()
    }
}

// MARK: - Time Picker Component
/// Simple time picker using SwiftUI's built-in DatePicker
/// Provides a compact, keyboard-friendly interface for time selection
struct InlineTimePicker: View {
    let title: String
    let timeString: String
    let onTimeChanged: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedTime: Date
    
    // Initialize with current time values
    init(title: String, timeString: String, onTimeChanged: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.title = title
        self.timeString = timeString
        self.onTimeChanged = onTimeChanged
        self.onDismiss = onDismiss
        
        // Parse the time string to initialize state
        self._selectedTime = State(initialValue: Self.parseTimeString(timeString))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Time picker using SwiftUI's built-in DatePicker
            DatePicker(
                "",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            
            // Buttons
            HStack(spacing: 8) {
                Button("Cancel") {
                    cancelTime()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Save") {
                    saveTime()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(12)
        .frame(minWidth: 160, maxWidth: 200)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func saveTime() {
        let newTimeString = formatTimeToString(selectedTime)
        onTimeChanged(newTimeString)
        onDismiss()
    }
    
    private func cancelTime() {
        onDismiss()
    }
    
    private var formattedTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: selectedTime)
    }
    
    // MARK: - Time Parsing and Formatting
    
    private static func parseTimeString(_ timeString: String) -> Date {
        let components = timeString.components(separatedBy: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return Date()
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? Date()
    }
    
    private func formatTimeToString(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d:00", hour, minute)
    }
}

// MARK: - Date Picker Component
/// Simple date picker using SwiftUI's built-in DatePicker
/// Provides a compact, popover-friendly interface for date selection
struct InlineDatePicker: View {
    let title: String
    let dateString: String
    let onDateChanged: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedDate: Date
    
    // Initialize with current date values
    init(title: String, dateString: String, onDateChanged: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.title = title
        self.dateString = dateString
        self.onDateChanged = onDateChanged
        self.onDismiss = onDismiss
        
        // Parse the date string to initialize state
        self._selectedDate = State(initialValue: Self.parseDateString(dateString))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Date picker using SwiftUI's built-in DatePicker
            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            
            // Buttons
            HStack(spacing: 8) {
                Button("Cancel") {
                    cancelDate()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Save") {
                    saveDate()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(12)
        .frame(minWidth: 160, maxWidth: 200)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func saveDate() {
        let newDateString = formatDateToString(selectedDate)
        onDateChanged(newDateString)
        onDismiss()
    }
    
    private func cancelDate() {
        onDismiss()
    }
    
    private var formattedDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }
    
    // MARK: - Date Parsing and Formatting
    
    private static func parseDateString(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }
    
    private func formatDateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Date Picker Popover
/// Popover wrapper for the inline date picker
/// Provides the same interface as other selection popovers
struct DatePickerPopover: View {
    let title: String
    let dateString: String
    let onDateChanged: (String) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        InlineDatePicker(
            title: title,
            dateString: dateString,
            onDateChanged: onDateChanged,
            onDismiss: onDismiss
        )
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct InlineSelectionPopover_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            InlineSelectionPopover(
                items: [
                    Project(name: "Work", color: "#4E79A7", emoji: "💼"),
                    Project(name: "Personal", color: "#F28E2C", emoji: "🏠"),
                    Project(name: "Learning", color: "#E15759", emoji: "📚")
                ],
                currentID: "1",
                onItemSelected: { _ in },
                onDismiss: {}
            )
            
            ProjectSelectionPopover(
                projects: [
                    Project(name: "Work", color: "#4E79A7", emoji: "💼"),
                    Project(name: "Personal", color: "#F28E2C", emoji: "🏠"),
                    Project(name: "Learning", color: "#E15759", emoji: "📚")
                ],
                currentProjectID: "1",
                onProjectSelected: { _ in },
                onDismiss: {}
            )
            
            ActivityTypeSelectionPopover(
                activityTypes: [
                    ActivityType(id: "writing", name: "Writing", emoji: "✍️"),
                    ActivityType(id: "coding", name: "Coding", emoji: "💻"),
                    ActivityType(id: "editing", name: "Editing", emoji: "✂️")
                ],
                currentActivityTypeID: "1",
                onActivityTypeSelected: { _ in },
                onDismiss: {}
            )
            
            PhaseSelectionPopover(
                project: Project(
                    name: "Test Project",
                    color: "#4E79A7",
                    emoji: "💼",
                    phases: [
                        Phase(name: "Planning", order: 0, archived: false),
                        Phase(name: "Development", order: 1, archived: false),
                        Phase(name: "Testing", order: 2, archived: false),
                        Phase(name: "Archived Phase", order: 3, archived: true)
                    ]
                ),
                currentPhaseID: "1",
                onPhaseSelected: { _ in },
                onDismiss: {}
            )
            
            MoodSelectionPopover(
                currentMood: 7,
                onMoodSelected: { _ in },
                onDismiss: {}
            )
            
            MilestoneSelectionPopover(
                currentMilestone: "First Draft Complete",
                onMilestoneChanged: { _ in },
                onDismiss: {}
            )
            
            InlineTimePicker(
                title: "Start Time",
                timeString: "09:30:00",
                onTimeChanged: { _ in },
                onDismiss: {}
            )
            
            InlineDatePicker(
                title: "Start Date",
                dateString: "2024-01-15",
                onDateChanged: { _ in },
                onDismiss: {}
            )
            
            DatePickerPopover(
                title: "End Date",
                dateString: "2024-01-15",
                onDateChanged: { _ in },
                onDismiss: {}
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif
