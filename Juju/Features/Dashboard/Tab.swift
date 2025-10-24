import SwiftUI

public enum Tab: CaseIterable, Identifiable {
    case charts, sessions, projects
    
    public var id: Self { self }
    
    var displayName: String {
        switch self {
        case .charts: return "Charts"
        case .sessions: return "Sessions"
        case .projects: return "Projects"
        }
    }
}
