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
    
    // Export state (removed - no longer needed)
    
    
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
}

// MARK: - Bottom Floating Filter Bar
struct BottomFilterBar: View {
    @ObservedObject var filterState: FilterExportState
    
    // Data sources (use active projects and activity types only)
    private let projects: [Project]
    private let activityTypes: [ActivityType]
    private let filteredSessionsCount: Int
    
    // Callbacks
    let onDateFilterChange: (SessionsDateFilter) -> Void
    let onCustomDateRangeChange: (DateRange?) -> Void
    let onProjectFilterChange: (String) -> Void
    let onActivityTypeFilterChange: (String) -> Void
    let onConfirmFilters: () -> Void
    let onClose: () -> Void
    
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
        onDateFilterChange: @escaping (SessionsDateFilter) -> Void,
        onCustomDateRangeChange: @escaping (DateRange?) -> Void,
        onProjectFilterChange: @escaping (String) -> Void,
        onActivityTypeFilterChange: @escaping (String) -> Void,
        onConfirmFilters: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.filterState = filterState
        self.projects = projects
        self.activityTypes = activityTypes
        self.filteredSessionsCount = filteredSessionsCount
        self.onDateFilterChange = onDateFilterChange
        self.onCustomDateRangeChange = onCustomDateRangeChange
        self.onProjectFilterChange = onProjectFilterChange
        self.onActivityTypeFilterChange = onActivityTypeFilterChange
        self.onConfirmFilters = onConfirmFilters
        self.onClose = onClose
        
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
            mainFilterBarContent
            customDateRangePicker
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        )
        .animation(.easeInOut(duration: 0.3), value: filterState.isExpanded)
    }
    
    // MARK: - Main Filter Bar Content
    @ViewBuilder
    private var mainFilterBarContent: some View {
        HStack(spacing: Theme.spacingSmall) {
            // Project Dropdown
            projectDropdown()
            
            // Activity Type Dropdown
            activityTypeDropdown()
            
            // Date Filter Dropdown
            dateFilterDropdown()
            
            // Session Count Badge
            sessionCountBadge
            
            // Spacer to push buttons to right
            Spacer()
            
            // Confirm Button
            ConfirmButton
            
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
    
    // MARK: - Custom Date Range Picker
    @ViewBuilder
    private var customDateRangePicker: some View {
        if filterState.selectedDateFilter == .custom {
            CustomDateRangePicker
        }
    }
    
    // MARK: - Project Dropdown
    @ViewBuilder
    private func projectDropdown() -> some View {
        Menu {
            Button(action: { onProjectFilterChange("All") }) {
                Text("All Projects")
            }
            // Only show active (non-archived) projects
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
                    // Find the project by ID and display only its name (no emoji)
                    if let project = projects.first(where: { $0.id == filterState.projectFilter }) {
                        Text(project.name)
                            .font(Theme.Fonts.body.weight(.medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        // Fallback if project not found - show ID in red to indicate issue
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
    
    // MARK: - Activity Type Dropdown
    @ViewBuilder
    private func activityTypeDropdown() -> some View {
        Menu {
            Button(action: { onActivityTypeFilterChange("All") }) {
                Text("All Activities")
            }
            // Only show active (non-archived) activity types
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
                } else {
                    // Find the activity type by ID and display only its name (no emoji)
                    if let activityType = activityTypes.first(where: { $0.id == filterState.activityTypeFilter }) {
                        Text(activityType.name)
                            .font(Theme.Fonts.body.weight(.medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        // Fallback if activity type not found - show ID in red to indicate issue
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
    
    // MARK: - Date Filter Dropdown
    @ViewBuilder
    private func dateFilterDropdown() -> some View {
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
            .background(Theme.Colors.divider.opacity(0.2))
            .clipShape(Capsule())
    }
    
    // MARK: - Confirm Button
    private var ConfirmButton: some View {
        Button(action: {
            // Apply temporary custom date range to filter state when Confirm is clicked
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
                Text("Confirm")
                    .font(.system(size: 12, weight: .medium))
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
                
                // Session count badge
                Text("\(filteredSessionsCount) sessions")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.divider.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            // Show validation for temporary dates
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
            ActivityType(id: "1", name: "Coding", emoji: "💻", description: "Software development"),
            ActivityType(id: "2", name: "Writing", emoji: "✍️", description: "Content creation"),
            ActivityType(id: "3", name: "Design", emoji: "🎨", description: "UI/UX design")
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
