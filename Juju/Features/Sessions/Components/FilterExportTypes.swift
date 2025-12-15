import SwiftUI

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

// MARK: - Export Format Enum
public enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case txt = "Text"
    case md = "Markdown"
    
    public var id: String { rawValue }
    public var title: String { rawValue }
    public var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .txt: return "txt"
        case .md: return "md"
        }
    }
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

// MARK: - Filter State Management
public class FilterExportState: ObservableObject {
    @Published var isExpanded: Bool = false
    
    // Filter state
    @Published var projectFilter: String = "All"
    @Published var activityTypeFilter: String = "All"
    @Published var selectedDateFilter: SessionsDateFilter = .thisWeek
    @Published var customDateRange: DateRange? = nil
    
    // Export state
    @Published var exportFormat: ExportFormat = .csv
    @Published var isExporting: Bool = false
    
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
