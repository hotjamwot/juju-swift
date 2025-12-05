import Foundation
import SwiftUI

// MARK: - Editorial Engine Models

/// Represents a milestone detected from session data
struct Milestone: Identifiable, Hashable, Equatable {
    let id = UUID()
    let text: String
    let date: Date
    let projectName: String
    let activityType: String
    
    static func == (lhs: Milestone, rhs: Milestone) -> Bool {
        return lhs.id == rhs.id &&
               lhs.text == rhs.text &&
               lhs.date == rhs.date &&
               lhs.projectName == rhs.projectName &&
               lhs.activityType == rhs.activityType
    }
}

/// Narrative headline components for dynamic generation
struct NarrativeHeadline: Equatable {
    let totalHours: Double
    let topActivity: (name: String, emoji: String)
    let topProject: (name: String, emoji: String)
    let milestone: Milestone?
    let period: String
    
    static func == (lhs: NarrativeHeadline, rhs: NarrativeHeadline) -> Bool {
        return lhs.totalHours == rhs.totalHours &&
               lhs.topActivity.name == rhs.topActivity.name &&
               lhs.topActivity.emoji == rhs.topActivity.emoji &&
               lhs.topProject.name == rhs.topProject.name &&
               lhs.topProject.emoji == rhs.topProject.emoji &&
               lhs.milestone == rhs.milestone &&
               lhs.period == rhs.period
    }
    
    var formattedHours: String {
        let hours = Int(totalHours)
        let minutes = Int((totalHours - Double(hours)) * 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var headlineText: String {
        var text = "This \(period) you logged \(formattedHours). "
        
        if let milestone = milestone {
            text += "Your focus was **\(topActivity.emoji) \(topActivity.name)** on **\(topProject.emoji) \(topProject.name)**, where you reached a milestone: **'\(milestone.text)'**."
        } else {
            text += "Your focus was **\(topActivity.emoji) \(topActivity.name)** on **\(topProject.emoji) \(topProject.name)**."
        }
        
        return text
    }
}

// MARK: - Editorial Engine Service

/// The Editorial Engine generates compelling narrative headlines for the dashboard
/// based on session data, activity types, and project information.
@MainActor
final class EditorialEngine: ObservableObject {
    @Published var currentHeadline: NarrativeHeadline?
    
    private let sessionManager: SessionManager
    private let projectsViewModel: ProjectsViewModel
    private let activityTypeManager: ActivityTypeManager
    
    init(sessionManager: SessionManager = .shared,
         projectsViewModel: ProjectsViewModel = .shared,
         activityTypeManager: ActivityTypeManager = .shared) {
        self.sessionManager = sessionManager
        self.projectsViewModel = projectsViewModel
        self.activityTypeManager = activityTypeManager
    }
    
    // MARK: - Public Interface
    
    /// Generate narrative headline for the current week
    func generateWeeklyHeadline() {
        let headline = _generateHeadline(for: .week)
        DispatchQueue.main.async {
            self.currentHeadline = headline
        }
    }
    
    /// Generate narrative headline for the specified period
    func generateHeadline(for period: ChartTimePeriod) {
        let headline = _generateHeadline(for: period)
        DispatchQueue.main.async {
            self.currentHeadline = headline
        }
    }
    
    /// Get the current headline text for display
    func getCurrentHeadlineText() -> String {
        return currentHeadline?.headlineText ?? "Loading your creative story..."
    }
    
    // MARK: - Private Implementation
    
    private func _generateHeadline(for period: ChartTimePeriod) -> NarrativeHeadline {
        let sessions = filterSessions(for: period)
        let totalHours = calculateTotalHours(from: sessions)
        let topActivity = determineTopActivity(from: sessions)
        let topProject = determineTopProject(from: sessions)
        let milestone = detectRecentMilestone(from: sessions)
        
        return NarrativeHeadline(
            totalHours: totalHours,
            topActivity: topActivity,
            topProject: topProject,
            milestone: milestone,
            period: period.title.lowercased().replacingOccurrences(of: "this ", with: "")
        )
    }
    
    private func filterSessions(for period: ChartTimePeriod) -> [SessionRecord] {
        let calendar = Calendar.current
        let formatter = DateFormatter.yyyyMMdd
        
        switch period {
        case .week:
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), end: Date())
            return sessionManager.allSessions.filter { session in
                formatter.date(from: session.date).map { weekInterval.contains($0) } ?? false
            }
        case .month:
            let monthInterval = calendar.dateInterval(of: .month, for: Date()) ?? DateInterval(start: Date(), end: Date())
            return sessionManager.allSessions.filter { session in
                formatter.date(from: session.date).map { monthInterval.contains($0) } ?? false
            }
        case .year:
            let yearInterval = calendar.dateInterval(of: .year, for: Date()) ?? DateInterval(start: Date(), end: Date())
            return sessionManager.allSessions.filter { session in
                formatter.date(from: session.date).map { yearInterval.contains($0) } ?? false
            }
        case .allTime:
            return sessionManager.allSessions
        }
    }
    
    private func calculateTotalHours(from sessions: [SessionRecord]) -> Double {
        let totalMinutes = sessions.reduce(into: 0) { result, session in
            result += session.durationMinutes
        }
        return Double(totalMinutes) / 60.0
    }
    
    private func determineTopActivity(from sessions: [SessionRecord]) -> (name: String, emoji: String) {
        var activityTotals: [String: Double] = [:]
        
        for session in sessions {
            let activityID = session.activityTypeID ?? "uncategorized"
            let hours = Double(session.durationMinutes) / 60.0
            activityTotals[activityID, default: 0] += hours
        }
        
        guard let topActivityID = activityTotals.max(by: { $0.value < $1.value })?.key else {
            return ("Uncategorized", "📝")
        }
        
        let activityType = activityTypeManager.getActivityType(id: topActivityID) ??
                          activityTypeManager.getUncategorizedActivityType()
        
        return (activityType.name, activityType.emoji)
    }
    
    private func determineTopProject(from sessions: [SessionRecord]) -> (name: String, emoji: String) {
        var projectTotals: [String: Double] = [:]
        
        for session in sessions {
            let projectName = session.projectName
            let hours = Double(session.durationMinutes) / 60.0
            projectTotals[projectName, default: 0] += hours
        }
        
        guard let topProjectName = projectTotals.max(by: { $0.value < $1.value })?.key else {
            return ("No Project", "📁")
        }
        
        let project = projectsViewModel.projects.first { $0.name == topProjectName } ??
                     Project(id: "unknown", name: topProjectName, color: "#999999", about: nil, order: 0, emoji: "📁", phases: [])
        
        return (project.name, project.emoji)
    }
    
    private func detectRecentMilestone(from sessions: [SessionRecord]) -> Milestone? {
        // Look for sessions with milestone text in the last 7 days
        let calendar = Calendar.current
        guard let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else {
            return nil
        }
        
        let recentSessions = sessions.filter { session in
            guard let sessionDate = DateFormatter.yyyyMMdd.date(from: session.date) else { return false }
            return sessionDate >= oneWeekAgo && (session.milestoneText?.isEmpty == false)
        }
        
        // Return the most recent milestone
        let sortedSessions = recentSessions.sorted { session1, session2 in
            guard let date1 = DateFormatter.yyyyMMdd.date(from: session1.date),
                  let date2 = DateFormatter.yyyyMMdd.date(from: session2.date) else { return false }
            return date1 > date2
        }
        
        guard let milestoneSession = sortedSessions.first,
              let milestoneText = milestoneSession.milestoneText,
              let sessionDate = DateFormatter.yyyyMMdd.date(from: milestoneSession.date) else {
            return nil
        }
        
        let activityType = activityTypeManager.getActivityType(id: milestoneSession.activityTypeID ?? "uncategorized") ??
                          activityTypeManager.getUncategorizedActivityType()
        
        return Milestone(
            text: milestoneText,
            date: sessionDate,
            projectName: milestoneSession.projectName,
            activityType: activityType.name
        )
    }
}
