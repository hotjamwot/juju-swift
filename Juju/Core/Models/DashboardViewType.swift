// DashboardViewType.swift
// Juju
//
// Created by Hayden on 12/12/2025.
//

import Foundation

/// Enum to track the current dashboard view state
/// Used for navigation between weekly and yearly dashboard views
enum DashboardViewType: CaseIterable {
    case weekly
    case yearly
    
    /// Human-readable title for the view type
    var title: String {
        switch self {
        case .weekly:
            return "Weekly"
        case .yearly:
            return "Yearly"
        }
    }
    
    /// Next view type for cycling through views
    var next: DashboardViewType {
        switch self {
        case .weekly:
            return .yearly
        case .yearly:
            return .weekly
        }
    }
}

// MARK: ──  Dashboard navigation items (sidebar)
enum DashboardView: String, CaseIterable, Identifiable {
    case charts        = "Charts"
    case sessions      = "Sessions"
    case projects      = "Projects"
    case activityTypes = "Activity Types"

    var icon: String {
        switch self {
        case .charts:        return "chart.xyaxis.line"
        case .sessions:      return "clock"
        case .projects:      return "folder"
        case .activityTypes: return "tag"
        }
    }

    var id: String { rawValue }
}
