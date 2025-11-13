import SwiftUI

// MARK: - Filter State Management
public class FilterExportState: ObservableObject {
    @Published var isExpanded: Bool = false
    
    // Filter state
    @Published var projectFilter: String = "All"
    @Published var selectedDateFilter: SessionsDateFilter = .thisWeek
    @Published var customDateRange: DateRange? = nil
    
    // Export state
    @Published var exportFormat: ExportFormat = .csv
    @Published var isExporting: Bool = false
    
    // Invoice preview state (future functionality)
    @Published var selectedProjects: Set<String> = []
    @Published var showInvoicePreview: Bool = false
}

// MARK: - Date Filter Enum
public enum SessionsDateFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case custom = "Custom Range"
    case clear = "Clear"
    
    public var id: String { rawValue }
    public var title: String { rawValue }
}

// MARK: - Date Range Model
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

// MARK: - Export Format Enum
public enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case txt = "Text"
    case md = "Markdown"
    case pdf = "PDF" // Future invoice support
    
    public var id: String { rawValue }
    public var title: String { rawValue }
    public var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .txt: return "txt"
        case .md: return "md"
        case .pdf: return "pdf"
        }
    }
}

// MARK: - Filter and Export Controls Component
struct FilterExportControls: View {
    @ObservedObject var state: FilterExportState
    
    // Data sources
    private let projects: [Project]
    private let filteredSessionsCount: Int
    
    // Callbacks
    let onDateFilterChange: (SessionsDateFilter) -> Void
    let onCustomDateRangeChange: (DateRange?) -> Void
    let onProjectFilterChange: (String) -> Void
    let onExport: (ExportFormat) -> Void
    var onInvoicePreviewToggle: (() -> Void)? = nil
    let onApplyFilters: () -> Void
    
    // Animation
    @State private var animationOffset: CGFloat = 0
    
    public init(
        state: FilterExportState,
        projects: [Project],
        filteredSessionsCount: Int,
        onDateFilterChange: @escaping (SessionsDateFilter) -> Void,
        onCustomDateRangeChange: @escaping (DateRange?) -> Void,
        onProjectFilterChange: @escaping (String) -> Void,
        onExport: @escaping (ExportFormat) -> Void,
        onInvoicePreviewToggle: (() -> Void)? = nil,
        onApplyFilters: @escaping () -> Void
    ) {
        self.state = state
        self.projects = projects
        self.filteredSessionsCount = filteredSessionsCount
        self.onDateFilterChange = onDateFilterChange
        self.onCustomDateRangeChange = onCustomDateRangeChange
        self.onProjectFilterChange = onProjectFilterChange
        self.onExport = onExport
        self.onInvoicePreviewToggle = onInvoicePreviewToggle
        self.onApplyFilters = onApplyFilters
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Toggle Button
            FilterExportToggleButton(
                isExpanded: state.isExpanded,
                filteredCount: filteredSessionsCount,
                action: toggleExpansion
            )
            
            // Expandable Controls Panel
            if state.isExpanded {
                controlsPanel
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom),
                            removal: .move(edge: .bottom)
                        )
                    )
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Design.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            }
        }
    }
    
    private var controlsPanel: some View {
        VStack(spacing: Theme.spacingMedium) {
            // Horizontal Filter Controls
            HStack(spacing: Theme.spacingMedium) {
                // Project Filter Dropdown
                ProjectFilterDropdown
                
                // Date Filter Dropdown  
                DateFilterDropdown
                
                // Export Dropdown
                ExportDropdown
                
                // Spacer to push apply and close buttons to right
                Spacer()
                
                // Apply Filters Button
                ApplyFiltersButton
                
                // Close Button
                CloseButton
            }
            .padding(.horizontal, Theme.spacingLarge)
            .padding(.vertical, Theme.spacingMedium)
            
            // Custom Date Range Picker (when custom is selected)
            if state.selectedDateFilter == .custom {
                CustomDateRangePicker
            }
        }
    }
    
    // MARK: - New Horizontal Layout Components
    
    private var ProjectFilterDropdown: some View {
        VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
            Text("Project")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.textSecondary)
            
            Picker("Project", selection: $state.projectFilter) {
                Text("All Projects").tag("All")
                ForEach(projects) { project in
                    Text(project.name).tag(project.name)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: state.projectFilter) { _, newValue in
                onProjectFilterChange(newValue)
            }
        }
        .frame(minWidth: 120)
    }
    
    private var DateFilterDropdown: some View {
        VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
            Text("Date")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.textSecondary)
            
            Picker("Date Filter", selection: $state.selectedDateFilter) {
                ForEach(SessionsDateFilter.allCases.filter { $0 != .custom }, id: \.id) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: state.selectedDateFilter) { _, newValue in
                onDateFilterChange(newValue)
                if newValue == .custom {
                    state.customDateRange = DateRange(
                        startDate: Calendar.current.startOfDay(for: Date()),
                        endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                    )
                }
            }
        }
        .frame(minWidth: 100)
    }
    
    private var ExportDropdown: some View {
        VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
            Text("Export")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.textSecondary)
            
            Picker("Export Format", selection: $state.exportFormat) {
                ForEach(ExportFormat.allCases, id: \.id) { format in
                    Text(format.title).tag(format)
                }
            }
            .pickerStyle(.menu)
            .disabled(state.isExporting)
            .onChange(of: state.exportFormat) { _, newValue in
                onExport(newValue)
            }
        }
        .frame(minWidth: 80)
    }
    
    private var ApplyFiltersButton: some View {
        Button(action: onApplyFilters) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Theme.Colors.accentColor)
        }
        .help("Apply current filters to update session list")
        .buttonStyle(.simpleIcon)
    }
    
    private var CloseButton: some View {
        Button(action: toggleExpansion) {
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .help("Close filters")
        .buttonStyle(.simpleIcon)
    }
    
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
                                state.customDateRange?.startDate ?? Date()
                            },
                            set: { newDate in
                                if var existingRange = state.customDateRange {
                                    existingRange.startDate = newDate
                                    state.customDateRange = existingRange
                                    onCustomDateRangeChange(state.customDateRange)
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
                                state.customDateRange?.endDate ?? Date()
                            },
                            set: { newDate in
                                if var existingRange = state.customDateRange {
                                    existingRange.endDate = newDate
                                    state.customDateRange = existingRange
                                    onCustomDateRangeChange(state.customDateRange)
                                }
                            }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }
                
                Spacer()
            }
            
            if let range = state.customDateRange, !range.isValid {
                Text("Invalid date range")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.error)
            } else if let range = state.customDateRange {
                Text("Range: \(range.durationDescription)")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, Theme.spacingLarge)
        .padding(.vertical, Theme.spacingSmall)
        .background(Theme.Colors.background)
        .cornerRadius(Theme.Design.cornerRadius / 2)
    }
    
    private var InvoicePreviewSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
            Text("Invoice Tools:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.textPrimary)
            
            Button("Preview Invoice") {
                onInvoicePreviewToggle?()
            }
            .buttonStyle(.secondary)
            .help("Preview invoice for selected project(s) and date range")
        }
    }
    
    private func toggleExpansion() {
        withAnimation(.easeInOut(duration: 0.3)) {
            state.isExpanded.toggle()
        }
    }
}

// MARK: - Supporting Views

struct FilterExportToggleButton: View {
    let isExpanded: Bool
    let filteredCount: Int
    let action: () -> Void
    
    var body: some View {
        if isExpanded {
            // When expanded, show minimal UI (close handled in menu)
            EmptyView()
        } else {
            // When collapsed, show the original button with text
            HStack {
                // Left side: Text and session count
                VStack(alignment: .leading, spacing: 2) {
                    Text("Filters & Export")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(filteredCount) sessions")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                // Right side: Circular toggle button
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                .buttonStyle(.circularToggleIcon)
                .help("Show filters & export")
            }
            .padding(.horizontal, Theme.spacingLarge)
            .padding(.vertical, Theme.spacingSmall)
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(title, action: action)
            .buttonStyle(SessionsFilterButtonStyle(isSelected: isSelected))
    }
}

struct ExportButton: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(title, action: action)
            .buttonStyle(.secondary)
            .opacity(isDisabled ? 0.5 : 1.0)
    }
}

// MARK: - Button Styles
struct SessionsFilterButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(isSelected ? Theme.Colors.accentColor : Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.spacingExtraSmall)
            .padding(.vertical, Theme.spacingExtraSmall)
            .background(
                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius / 2)
                    .fill(isSelected ? Theme.Colors.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius / 2)
                    .stroke(isSelected ? Theme.Colors.accentColor : Theme.Colors.divider, lineWidth: 1)
            )
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct FilterExportControls_Previews: PreviewProvider {
    static var previews: some View {
        let state = FilterExportState()
        let projects = [
            Project(id: "1", name: "Project Alpha", color: "#3B82F6", about: nil, order: 0),
            Project(id: "2", name: "Project Beta", color: "#10B981", about: nil, order: 0),
            Project(id: "3", name: "Project Gamma", color: "#8B5CF6", about: nil, order: 0)
        ]
        
        VStack {
            Spacer()
            
            FilterExportControls(
                state: state,
                projects: projects,
                filteredSessionsCount: 42,
                onDateFilterChange: { _ in },
                onCustomDateRangeChange: { _ in },
                onProjectFilterChange: { _ in },
                onExport: { _ in },
                onApplyFilters: { }
            )
        }
        .padding()
        .background(Theme.Colors.background)
    }
}
#endif
