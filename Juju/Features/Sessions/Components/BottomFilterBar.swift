import SwiftUI

// MARK: - Filter Types (moved here to avoid circular dependencies)
public enum SessionsDateFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case allTime = "All Time"
    case custom = "Custom Range"
    case clear = "Clear"
    
    public var id: String { rawValue }
    public var title: String { rawValue }
}

public struct DateRange: Identifiable {
    public let id = UUID()
    public var startDate: Date
    public var endDate: Date
    
    var isValid: Bool {
        return startDate <= endDate
    }
    
    var durationDescription: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .weekOfMonth]
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = .abbreviated
        
        let duration = endDate.timeIntervalSince(startDate)
        return formatter.string(from: duration) ?? "0d"
    }
}

public class FilterExportState: ObservableObject {
    @Published var isExpanded: Bool = false
    
    // Filter state
    @Published var projectFilter: String = "All"
    @Published var activityTypeFilter: String = "All"
    @Published var selectedDateFilter: SessionsDateFilter = .thisWeek
    @Published var customDateRange: DateRange? = nil
    
    // Bulk edit state
    @Published var isBulkEditing: Bool = false
    @Published var selectedSessionIDs: Set<String> = []
    @Published var lastSelectedSessionID: String? = nil // For shift-click range selection
    
    // Bulk edit pending values (nil = no change)
    @Published var pendingBulkProjectID: String? = nil
    @Published var pendingBulkPhaseID: String? = nil
    @Published var pendingBulkMood: Int? = nil
    
    // Manual refresh control
    @Published var shouldRefresh: Bool = false
    
    /// Call this when you want to manually refresh the filtered data
    func requestManualRefresh() {
        shouldRefresh.toggle()
    }
    
    /// Clear all filters and reset to default state
    func clearFilters() {
        projectFilter = "All"
        activityTypeFilter = "All"
        selectedDateFilter = .thisWeek
        customDateRange = nil
    }
    
    // MARK: - Bulk Edit Methods
    
    /// Enter bulk edit mode with optional first selected session
    func enterBulkEditMode(firstSessionID: String? = nil) {
        isBulkEditing = true
        selectedSessionIDs = []
        lastSelectedSessionID = nil
        pendingBulkProjectID = nil
        pendingBulkPhaseID = nil
        pendingBulkMood = nil
        
        if let sessionID = firstSessionID {
            selectedSessionIDs.insert(sessionID)
            lastSelectedSessionID = sessionID
        }
        
        // Ensure the filter bar is expanded when entering bulk editing
        isExpanded = true
    }
    
    /// Exit bulk edit mode and clear all selections
    func exitBulkEditMode() {
        isBulkEditing = false
        selectedSessionIDs = []
        lastSelectedSessionID = nil
        pendingBulkProjectID = nil
        pendingBulkPhaseID = nil
        pendingBulkMood = nil
    }
    
    /// Toggle selection for a session, with shift-click range support
    func toggleSessionSelection(_ sessionID: String, isShiftHeld: Bool = false, in flatSessionOrder: [SessionRecord] = []) {
        if isShiftHeld, let lastID = lastSelectedSessionID, !flatSessionOrder.isEmpty {
            // Find range between last selected and this one
            guard let lastIndex = flatSessionOrder.firstIndex(where: { $0.id == lastID }),
                  let currentIndex = flatSessionOrder.firstIndex(where: { $0.id == sessionID }) else {
                // Fall back to simple toggle
                selectedSessionIDs.insert(sessionID)
                lastSelectedSessionID = sessionID
                return
            }
            
            let lower = min(lastIndex, currentIndex)
            let upper = max(lastIndex, currentIndex)
            let rangeIDs = flatSessionOrder[lower...upper].map { $0.id }
            for id in rangeIDs {
                selectedSessionIDs.insert(id)
            }
            lastSelectedSessionID = sessionID
        } else {
            if selectedSessionIDs.contains(sessionID) {
                selectedSessionIDs.remove(sessionID)
            } else {
                selectedSessionIDs.insert(sessionID)
            }
            lastSelectedSessionID = sessionID
        }
    }
}

// MARK: - Bottom Floating Filter Bar
struct BottomFilterBar: View {
    @ObservedObject var filterState: FilterExportState
    
    // Data sources (use active projects and activity types only)
    private let projects: [Project]
    private let activityTypes: [ActivityType]
    private let filteredSessionsCount: Int
    private let selectedSessions: [SessionRecord]
    
    // Callbacks
    let onDateFilterChange: (SessionsDateFilter) -> Void
    let onCustomDateRangeChange: (DateRange?) -> Void
    let onProjectFilterChange: (String) -> Void
    let onActivityTypeFilterChange: (String) -> Void
    let onConfirmFilters: () -> Void
    let onClose: () -> Void
    let onBulkEditToggle: (() -> Void)? // Callback for toggling bulk edit mode
    
    // Animation
    @State private var isHovering = false
    
    // Temporary state for custom date range (only update filterState when Confirm is clicked)
    @State private var tempCustomStartDate: Date
    @State private var tempCustomEndDate: Date
    
    init(
        filterState: FilterExportState,
        projects: [Project],
        activityTypes: [ActivityType],
        filteredSessionsCount: Int,
        selectedSessions: [SessionRecord] = [],
        onDateFilterChange: @escaping (SessionsDateFilter) -> Void,
        onCustomDateRangeChange: @escaping (DateRange?) -> Void,
        onProjectFilterChange: @escaping (String) -> Void,
        onActivityTypeFilterChange: @escaping (String) -> Void,
        onConfirmFilters: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onBulkEditToggle: (() -> Void)? = nil
    ) {
        self.filterState = filterState
        self.projects = projects
        self.activityTypes = activityTypes
        self.filteredSessionsCount = filteredSessionsCount
        self.selectedSessions = selectedSessions
        self.onDateFilterChange = onDateFilterChange
        self.onCustomDateRangeChange = onCustomDateRangeChange
        self.onProjectFilterChange = onProjectFilterChange
        self.onActivityTypeFilterChange = onActivityTypeFilterChange
        self.onConfirmFilters = onConfirmFilters
        self.onClose = onClose
        self.onBulkEditToggle = onBulkEditToggle
        
        // Initialize temporary state with current filter state
        if let customRange = filterState.customDateRange {
            self._tempCustomStartDate = State(initialValue: customRange.startDate)
            self._tempCustomEndDate = State(initialValue: customRange.endDate)
        } else {
            let today = Date()
            self._tempCustomStartDate = State(initialValue: today)
            self._tempCustomEndDate = State(initialValue: today)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if filterState.isBulkEditing {
                bulkEditControls
            } else {
                filterControls
            }
            
            if filterState.selectedDateFilter == .custom && !filterState.isBulkEditing {
                CustomDateRangePicker
            }
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        )
        .animation(.easeInOut(duration: 0.3), value: filterState.isExpanded)
    }
    
    // MARK: - Filter Controls (Normal Mode)
    @ViewBuilder
    private var filterControls: some View {
        HStack(spacing: Theme.spacingSmall) {
            // Bulk Edit Toggle Button (left side, before project dropdown)
            bulkEditToggleButton
            
            // Project Dropdown
            filterProjectDropdown()
            
            // Activity Type Dropdown
            filterActivityTypeDropdown()
            
            // Date Filter Dropdown
            filterDateDropdown()
            
            // Session Count Badge
            sessionCountBadge
            
            // Spacer to push buttons to right
            Spacer()
            
            // Confirm Button (no text, just icon)
            confirmButton
            
            // Close Button
            CloseButton
        }
        .padding(.horizontal, Theme.spacingMedium)
        .padding(.vertical, Theme.spacingSmall)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Row.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Row.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.3), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    // MARK: - Bulk Edit Toggle Button
    private var bulkEditToggleButton: some View {
        Button(action: {
            onBulkEditToggle?()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .medium))
                Text("Bulk Edit")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(Theme.Colors.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius / 2)
                    .stroke(Theme.Colors.accentColor.opacity(0.4), lineWidth: 1)
                    .background(Theme.Colors.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Design.cornerRadius / 2))
            )
        }
        .help("Enter bulk edit mode")
        .buttonStyle(.plain)
    }
    
    // MARK: - Bulk Edit Controls
    @ViewBuilder
    private var bulkEditControls: some View {
        HStack(spacing: Theme.spacingSmall) {
            // Selection count
            Text("\(filterState.selectedSessionIDs.count) selected")
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.Colors.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.accentColor.opacity(0.1))
                .cornerRadius(Theme.Design.cornerRadius)
            
            Divider()
                .frame(height: 20)
            
            // Bulk Project dropdown
            bulkProjectDropdown()
            
            // Bulk Phase dropdown
            bulkPhaseDropdown()
            
            // Bulk Mood button
            bulkMoodButton()
            
            Spacer()
            
            // Save & Exit button (icon only)
            Button(action: {
                filterState.requestManualRefresh()
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.Colors.accentColor)
                    .padding(.horizontal, Theme.spacingSmall)
                    .padding(.vertical, Theme.spacingExtraSmall)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius / 2)
                            .fill(Theme.Colors.accentColor.opacity(0.1))
                    )
            }
            .help("Apply bulk edits and exit bulk edit mode")
            .buttonStyle(.plain)
            
            // Cancel button (icon only)
            Button(action: {
                filterState.exitBulkEditMode()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.horizontal, Theme.spacingSmall)
                    .padding(.vertical, Theme.spacingExtraSmall)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius / 2)
                            .fill(Theme.Colors.divider.opacity(0.2))
                    )
            }
            .help("Exit bulk edit mode without saving")
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.spacingMedium)
        .padding(.vertical, Theme.spacingSmall)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Row.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Row.cornerRadius)
                .stroke(Theme.Colors.accentColor.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Bulk Project Dropdown
    @ViewBuilder
    private func bulkProjectDropdown() -> some View {
        Menu {
            ForEach(projects.filter { !$0.archived }) { project in
                Button(action: {
                    filterState.pendingBulkProjectID = project.id
                    filterState.pendingBulkPhaseID = nil // Reset phase when project changes
                }) {
                    HStack {
                        Circle()
                            .fill(project.swiftUIColor)
                            .frame(width: 8, height: 8)
                        Text(project.name)
                        if filterState.pendingBulkProjectID == project.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.Colors.accentColor)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                if let pid = filterState.pendingBulkProjectID,
                   let project = projects.first(where: { $0.id == pid }) {
                    Text(project.name)
                        .font(.caption.weight(.medium))
                } else {
                    Text("Project")
                        .font(.caption.weight(.medium))
                }
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.Colors.divider.opacity(0.2))
            .cornerRadius(Theme.Design.cornerRadius)
        }
        .frame(minWidth: 120)
        .help("Set project for all selected sessions")
    }
    
    // MARK: - Bulk Phase Dropdown
    @ViewBuilder
    private func bulkPhaseDropdown() -> some View {
        let sameProjectInfo = resolveBulkPhaseProject()
        
        Menu {
            if sameProjectInfo.same, let project = sameProjectInfo.project {
                ForEach(project.phases.filter { !$0.archived }) { phase in
                    Button(action: {
                        filterState.pendingBulkPhaseID = phase.id
                    }) {
                        HStack {
                            Text(phase.name)
                            if filterState.pendingBulkPhaseID == phase.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.Colors.accentColor)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "play.circle")
                    .font(.system(size: 10))
                if let pid = filterState.pendingBulkPhaseID,
                   let project = sameProjectInfo.project,
                   let phase = project.phases.first(where: { $0.id == pid }) {
                    Text(phase.name)
                        .font(.caption.weight(.medium))
                } else {
                    Text("Phase")
                        .font(.caption.weight(.medium))
                }
            }
            .foregroundColor(sameProjectInfo.same ? Theme.Colors.textPrimary : Theme.Colors.textSecondary.opacity(0.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.Colors.divider.opacity(0.2))
            .cornerRadius(Theme.Design.cornerRadius)
        }
        .disabled(!sameProjectInfo.same)
        .frame(minWidth: 100)
        .help(sameProjectInfo.same ? "Set phase for all selected sessions" : "All sessions must be same project to edit phase")
    }
    
    /// Resolves the project to use for phase editing.
    /// Uses the pending bulk project if set; otherwise checks if all selected sessions belong to the same project.
    private func resolveBulkPhaseProject() -> (same: Bool, project: Project?) {
        if let pendingID = filterState.pendingBulkProjectID {
            // A bulk project has been selected, use that
            let project = projects.first(where: { $0.id == pendingID })
            return (project != nil, project)
        }
        // Check if all selected sessions belong to the same project
        let selectedProjectIDs = Set(selectedSessions.filter { filterState.selectedSessionIDs.contains($0.id) }.map { $0.projectID })
        if selectedProjectIDs.count == 1, let projectID = selectedProjectIDs.first {
            let project = projects.first(where: { $0.id == projectID })
            return (project != nil, project)
        }
        return (false, nil)
    }
    
    // MARK: - Bulk Mood Button
    @State private var showingBulkMoodPopover = false
    
    @ViewBuilder
    private func bulkMoodButton() -> some View {
        Button(action: {
            showingBulkMoodPopover = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "bolt")
                    .font(.system(size: 10))
                if let mood = filterState.pendingBulkMood {
                    Text("\(mood)/10")
                        .font(.caption.weight(.medium))
                } else {
                    Text("Mood")
                        .font(.caption.weight(.medium))
                }
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.Colors.divider.opacity(0.2))
            .cornerRadius(Theme.Design.cornerRadius)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingBulkMoodPopover) {
            MoodSelectionPopover(
                currentMood: filterState.pendingBulkMood,
                onMoodSelected: { mood in
                    filterState.pendingBulkMood = mood
                    showingBulkMoodPopover = false
                },
                onDismiss: {
                    showingBulkMoodPopover = false
                }
            )
            .padding()
        }
        .help("Set mood for all selected sessions")
    }
    
    // MARK: - Filter Project Dropdown
    @ViewBuilder
    private func filterProjectDropdown() -> some View {
        Menu {
            Button(action: { onProjectFilterChange("All") }) {
                Text("All Projects")
            }
            ForEach(projects.filter { !$0.archived }) { project in
                Button(action: { onProjectFilterChange(project.id) }) {
                    Text(project.name)
                        .font(Theme.Fonts.body.weight(.medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } label: {
            HStack {
                if filterState.projectFilter == "All" {
                    Text("All Projects")
                } else {
                    if let project = projects.first(where: { $0.id == filterState.projectFilter }) {
                        Text(project.name)
                            .font(Theme.Fonts.body.weight(.medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text("❌")
                        Text("Project not found: \(filterState.projectFilter)")
                            .foregroundColor(Theme.Colors.error)
                    }
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.Colors.divider.opacity(0.2))
            .cornerRadius(Theme.Design.cornerRadius)
        }
        .frame(minWidth: 240)
    }
    
    // MARK: - Filter Activity Type Dropdown
    @ViewBuilder
    private func filterActivityTypeDropdown() -> some View {
        Menu {
            Button(action: { onActivityTypeFilterChange("All") }) {
                Text("All Activities")
            }
            Button(action: { onActivityTypeFilterChange("Uncategorized") }) {
                HStack {
                    Text("Uncategorized")
                        .font(Theme.Fonts.body.weight(.medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("(no activity type)")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(activityTypes.filter { !$0.archived }) { type in
                Button(action: { onActivityTypeFilterChange(type.id) }) {
                    Text(type.name)
                        .font(Theme.Fonts.body.weight(.medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } label: {
            HStack {
                if filterState.activityTypeFilter == "All" {
                    Text("All Activities")
                } else if filterState.activityTypeFilter == "Uncategorized" {
                    HStack {
                        Text("Uncategorized")
                            .font(Theme.Fonts.body.weight(.medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                } else {
                    if let activityType = activityTypes.first(where: { $0.id == filterState.activityTypeFilter }) {
                        Text(activityType.name)
                            .font(Theme.Fonts.body.weight(.medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text("❌")
                        Text("Activity type not found: \(filterState.activityTypeFilter)")
                            .foregroundColor(Theme.Colors.error)
                    }
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.Colors.divider.opacity(0.2))
            .cornerRadius(Theme.Design.cornerRadius)
        }
        .frame(minWidth: 240)
    }
    
    // MARK: - Filter Date Dropdown
    @ViewBuilder
    private func filterDateDropdown() -> some View {
        Menu {
            ForEach(SessionsDateFilter.allCases.filter { $0 != .clear }, id: \.id) { filter in
                Button(action: { onDateFilterChange(filter) }) {
                    Text(filter.title)
                }
            }
        } label: {
            HStack {
                Text(filterState.selectedDateFilter.title)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.Colors.divider.opacity(0.2))
            .cornerRadius(Theme.Design.cornerRadius)
        }
        .frame(minWidth: 120)
    }
    
    // MARK: - Session Count Badge
    private var sessionCountBadge: some View {
        Text("\(filteredSessionsCount) sessions")
            .font(.caption.weight(.medium))
            .foregroundColor(Theme.Colors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
    
    // MARK: - Confirm Button (no text label, just icon)
    private var confirmButton: some View {
        Button(action: {
            if filterState.selectedDateFilter == .custom {
                let newRange = DateRange(startDate: tempCustomStartDate, endDate: tempCustomEndDate)
                filterState.customDateRange = newRange
                onCustomDateRangeChange(newRange)
            }
            onConfirmFilters()
        }) {
            HStack(spacing: Theme.spacingExtraSmall) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(Theme.Colors.accentColor)
            .padding(.horizontal, Theme.spacingSmall)
            .padding(.vertical, Theme.spacingExtraSmall)
            .background(
                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius / 2)
                    .fill(Theme.Colors.accentColor.opacity(0.1))
            )
        }
        .help("Apply current filters to update session list")
        .buttonStyle(.plain)
    }
    
    // MARK: - Close Button
    private var CloseButton: some View {
        Button(action: onClose) {
            Image(systemName: "chevron.down")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)
                .padding(Theme.spacingExtraSmall)
                .background(
                    Circle()
                        .fill(Theme.Colors.divider.opacity(0.2))
                )
        }
        .help("Hide filter bar")
        .buttonStyle(.plain)
    }
    
    // MARK: - Custom Date Range Picker
    private var CustomDateRangePicker: some View {
        VStack(spacing: Theme.spacingSmall) {
            HStack(spacing: Theme.spacingMedium) {
                VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
                    Text("From:")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    DatePicker(
                        "Start Date",
                        selection: $tempCustomStartDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }
                
                VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
                    Text("To:")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    DatePicker(
                        "End Date",
                        selection: $tempCustomEndDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }
                
                Spacer()
                
                Text("\(filteredSessionsCount) sessions")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            
            let tempRange = DateRange(startDate: tempCustomStartDate, endDate: tempCustomEndDate)
            if !tempRange.isValid {
                Text("Invalid date range")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.error)
            } else {
                Text("Range: \(tempRange.durationDescription)")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, Theme.spacingMedium)
        .padding(.vertical, Theme.spacingSmall)
        .background(Theme.Colors.background)
        .cornerRadius(Theme.Row.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Row.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct BottomFilterBar_Previews: PreviewProvider {
    static var previews: some View {
        let filterState = FilterExportState()
        let projects = [
            Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0),
            Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0),
            Project(id: "3", name: "Project Gamma", color: "#8B5CF6", about: nil, order: 0)
        ]
        let activityTypes = [
            ActivityType(id: "1", name: "Coding", sfSymbol: "chevron.left.forwardslash.chevron.right", description: "Software development"),
            ActivityType(id: "2", name: "Writing", sfSymbol: "pencil", description: "Content creation"),
            ActivityType(id: "3", name: "Design", sfSymbol: "paintbrush", description: "UI/UX design")
        ]
        
        VStack {
            Spacer()
            BottomFilterBar(
                filterState: filterState,
                projects: projects,
                activityTypes: activityTypes,
                filteredSessionsCount: 42,
                onDateFilterChange: { _ in },
                onCustomDateRangeChange: { _ in },
                onProjectFilterChange: { _ in },
                onActivityTypeFilterChange: { _ in },
                onConfirmFilters: { },
                onClose: { }
            )
        }
        .padding()
        .background(Theme.Colors.background)
    }
}
#endif