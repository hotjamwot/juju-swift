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
    let onInvoicePreviewToggle: (() -> Void)? = nil
    
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
        onInvoicePreviewToggle: (() -> Void)? = nil
    ) {
        self.state = state
        self.projects = projects
        self.filteredSessionsCount = filteredSessionsCount
        self.onDateFilterChange = onDateFilterChange
        self.onCustomDateRangeChange = onCustomDateRangeChange
        self.onProjectFilterChange = onProjectFilterChange
        self.onExport = onExport
        // self.onInvoicePreviewToggle = onInvoicePreviewToggle
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
            // Main Controls Section
            VStack(spacing: Theme.spacingLarge) {
                // Project Filter
                ProjectFilterSection
                
                // Date Filter Section
                DateFilterSection
                
                // Export Section
                ExportSection
                
                // Invoice Preview Section (Future)
                if onInvoicePreviewToggle != nil {
                    InvoicePreviewSection
                }
            }
            .padding(.horizontal, Theme.spacingLarge)
            .padding(.vertical, Theme.spacingMedium)
        }
    }
    
    private var ProjectFilterSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
            HStack {
                Text("Project Filter:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(filteredSessionsCount) sessions")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
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
    }
    
    private var DateFilterSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
            Text("Date Range:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.textPrimary)
            
            // Quick Filter Buttons
            HStack(spacing: Theme.spacingExtraSmall) {
                ForEach(SessionsDateFilter.allCases.filter { $0 != .custom }, id: \.id) { filter in
                    FilterButton(
                        title: filter.title,
                        isSelected: state.selectedDateFilter == filter,
                        action: {
                            state.selectedDateFilter = filter
                            onDateFilterChange(filter)
                            if filter == .custom {
                                state.customDateRange = DateRange(
                                    startDate: Calendar.current.startOfDay(for: Date()),
                                    endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                                )
                            }
                        }
                    )
                }
            }
            
            // Custom Date Range Picker (when custom is selected)
            if state.selectedDateFilter == .custom, let range = state.customDateRange {
                VStack(spacing: Theme.spacingExtraSmall) {
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
                            Text("From:")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            DatePicker(
                                "Start Date",
                                selection: Binding(
                                    get: { range.startDate },
                                    set: { newDate in
                                        state.customDateRange = DateRange(startDate: newDate, endDate: range.endDate)
                                        onCustomDateRangeChange(state.customDateRange)
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
                                    get: { range.endDate },
                                    set: { newDate in
                                        state.customDateRange = DateRange(startDate: range.startDate, endDate: newDate)
                                        onCustomDateRangeChange(state.customDateRange)
                                    }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }
                        
                        Spacer()
                    }
                    
                    if !range.isValid {
                        Text("Invalid date range")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.error)
                    } else {
                        Text("Range: \(range.durationDescription)")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, Theme.spacingSmall)
                .padding(.vertical, Theme.spacingExtraSmall)
                .background(Theme.Colors.background)
                .cornerRadius(Theme.Design.cornerRadius / 2)
            }
        }
    }
    
    private var ExportSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
            HStack {
                Text("Export:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                if state.isExporting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            HStack(spacing: Theme.spacingExtraSmall) {
                ForEach(ExportFormat.allCases, id: \.id) { format in
                    ExportButton(
                        title: format.title,
                        isSelected: state.exportFormat == format,
                        isDisabled: state.isExporting,
                        action: {
                            state.exportFormat = format
                            onExport(format)
                        }
                    )
                }
            }
        }
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
        HStack {
            // Left side: Text and session count (when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Filters & Export")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(filteredCount) sessions")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .foregroundColor(Theme.Colors.textPrimary)
            } else {
                // When collapsed, just show a small amount of space
                Spacer()
                    .frame(width: 20)
            }
            
            Spacer()
            
            // Right side: Circular toggle button
            Button(action: action) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .rotationEffect(.degrees(isExpanded ? 0 : 180))
                    .animation(.easeInOut(duration: 0.3), value: isExpanded)
            }
            .buttonStyle(.circularToggleIcon)
            .help(isExpanded ? "Hide controls" : "Show filters & export")
        }
        .padding(.horizontal, Theme.spacingLarge)
        .padding(.vertical, Theme.spacingSmall)
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
                onExport: { _ in }
            )
        }
        .padding()
        .background(Theme.Colors.background)
    }
}
#endif
