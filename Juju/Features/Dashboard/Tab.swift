import SwiftUI

public enum Tab: CaseIterable, Identifiable {
    case charts, sessions, projects
    public var id: Self { self }
}
