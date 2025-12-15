import SwiftUI

// MARK: - Bottom Floating Filter Bar
struct BottomFilterBar: View {
    @ObservedObject var filterState: FilterExportState
    
    // Data sources
    private let projects: [Project]
    private let activityTypes: [ActivityType]
    private let filteredSessionsCount: Int
    
    // Callbacks
    let onDateFilterChange: (SessionsDateFilter) -> Void
    let onCustomDateRangeChange: (DateRange?) -> Void
    let onProjectFilterChange: (String) -> Void
    let onActivityTypeFilterChange: (String) -> Void
    let onConfirmFilters: () -> Void
    let onExport: (ExportFormat) -> Void
    let onClose: () -> Void
    
    // Animation
    @State private var isHovering = false
    
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
        onExport: @escaping (ExportFormat) -> Void,
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
        self.onExport = onExport
        self.onClose = onClose
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
            
            // Spacer to push buttons to right
            Spacer()
            
            // Confirm Button
            ConfirmButton
            
            // Export Button
            ExportButton
            
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
                HStack {
                    Text("📁")
                    Text("All")
                }
            }
            ForEach(projects.filter { !$0.archived }) { project in
                Button(action: { onProjectFilterChange(project.id) }) {
                    HStack {
                        Text(project.emoji)
                        Text(project.name)
                    }
                }
            }
        } label: {
            HStack {
                if filterState.projectFilter == "All" {
                    Text("📁")
                    Text("All")
                } else {
                    if let project = projects.first(where: { $0.id == filterState.projectFilter && !$0.archived }) {
                        Text(project.emoji)
                        Text(project.name)
                    } else {
                        Text("📁")
                        Text(filterState.projectFilter)
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
        .frame(minWidth: 200)
    }
    
    // MARK: - Activity Type Dropdown
    @ViewBuilder
    private func activityTypeDropdown() -> some View {
        Menu {
            Button(action: { onActivityTypeFilterChange("All") }) {
                HStack {
                    Text("📋")
                    Text("All")
                }
            }
            ForEach(activityTypes.filter { !$0.archived }) { type in
                Button(action: { onActivityTypeFilterChange(type.id) }) {
                    HStack {
                        Text(type.emoji)
                        Text(type.name)
                    }
                }
            }
        } label: {
            HStack {
                if filterState.activityTypeFilter == "All" {
                    Text("📋")
                    Text("All")
                } else {
                    if let activityType = activityTypes.first(where: { $0.id == filterState.activityTypeFilter && !$0.archived }) {
                        Text(activityType.emoji)
                        Text(activityType.name)
                    } else {
                        Text("📋")
                        Text(filterState.activityTypeFilter)
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
        .frame(minWidth: 200)
    }
    
    // MARK: - Date Filter Dropdown
    @ViewBuilder
    private func dateFilterDropdown() -> some View {
        Menu {
            ForEach(SessionsDateFilter.allCases.filter { $0 != .custom }, id: \.id) { filter in
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
    
    // MARK: - Confirm Button
    private var ConfirmButton: some View {
        Button(action: onConfirmFilters) {
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
    
    // MARK: - Export Button
    private var ExportButton: some View {
        Button(action: {
            onExport(.csv) // Default to CSV
        }) {
            HStack(spacing: Theme.spacingExtraSmall) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .medium))
                Text("Export")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.horizontal, Theme.spacingSmall)
            .padding(.vertical, Theme.spacingExtraSmall)
            .background(
                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius / 2)
                    .fill(Theme.Colors.divider.opacity(0.2))
            )
        }
        .help("Export filtered sessions using native macOS dialog")
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
                        selection: Binding(
                            get: { 
                                filterState.customDateRange?.startDate ?? Date()
                            },
                            set: { newDate in
                                if var existingRange = filterState.customDateRange {
                                    existingRange.startDate = newDate
                                    filterState.customDateRange = existingRange
                                    onCustomDateRangeChange(filterState.customDateRange)
                                }
                            }
                        ),
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
                        selection: Binding(
                            get: { 
                                filterState.customDateRange?.endDate ?? Date()
                            },
                            set: { newDate in
                                if var existingRange = filterState.customDateRange {
                                    existingRange.endDate = newDate
                                    filterState.customDateRange = existingRange
                                    onCustomDateRangeChange(filterState.customDateRange)
                                }
                            }
                        ),
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
            
            if let range = filterState.customDateRange, !range.isValid {
                Text("Invalid date range")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.error)
            } else if let range = filterState.customDateRange {
                Text("Range: \(range.durationDescription)")
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
                onExport: { _ in },
                onClose: { }
            )
        }
        .padding()
        .background(Theme.Colors.background)
    }
}
#endif
