/// ProjectStoryContainerView.swift
/// Purpose: Switch between Projects list and a selected project's story.
/// AI Notes: Keeps editing in the sidebar overlay; story is main-content only.

import SwiftUI

struct ProjectStoryContainerView: View {
    @State private var selectedProjectID: String? = nil

    var body: some View {
        ZStack {
            if let projectID = selectedProjectID {
                ProjectStoryView(projectID: projectID) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedProjectID = nil
                    }
                }
                .transition(.opacity)
            } else {
                ProjectsView(onOpenProjectStory: { project in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedProjectID = project.id
                    }
                })
                .transition(.opacity)
            }
        }
    }
}

