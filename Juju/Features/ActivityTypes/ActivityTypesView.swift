import SwiftUI

struct ActivityTypesView: View {
    @StateObject private var viewModel = ActivityTypesViewModel.shared
    @EnvironmentObject var sidebarState: SidebarStateManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Activity Types")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                
                Button {
                    // Create a new activity type instance with proper ID
                    let newActivityType = ActivityType(
                        id: UUID().uuidString,
                        name: "",
                        emoji: "⚡",
                        description: "",
                        archived: false
                    )
                    sidebarState.show(.newActivityType(newActivityType))
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Activity Type")
                    }
                }
                .buttonStyle(.primary)
            }
            .padding(.vertical, Theme.spacingLarge)
            .padding(.horizontal, Theme.spacingLarge)
            .background(Theme.Colors.background)

            // Activity Types List
            ScrollView {
                if viewModel.activeActivityTypes.isEmpty && viewModel.archivedActivityTypes.isEmpty {
                    Text("No Activity Types Yet")
                        .foregroundColor(Theme.Colors.surface)
                        .padding(40)
                } else {
                    LazyVStack(spacing: Theme.spacingMedium) {
                        // Active Activity Types Section
                        if !viewModel.activeActivityTypes.isEmpty {
                            Section {
                                ForEach(viewModel.activeActivityTypes) { activityType in
                                    Button(action: {
                                        sidebarState.show(.activityType(activityType))
                                    }) {
                                        ActivityTypeRowView(activityType: activityType, isArchived: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                Text("Active Activity Types")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.leading)
                            }
                        }
                        
                        // Archived Activity Types Section
                        if !viewModel.archivedActivityTypes.isEmpty {
                            Section {
                                ForEach(viewModel.archivedActivityTypes) { activityType in
                                    Button(action: {
                                        sidebarState.show(.activityType(activityType))
                                    }) {
                                        ActivityTypeRowView(activityType: activityType, isArchived: true)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                Text("Archived Activity Types")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.leading)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Theme.Colors.background)
    }
}

struct ActivityTypeRowView: View {
    let activityType: ActivityType
    var isArchived: Bool = false
    
    var body: some View {
        HStack(spacing: Theme.spacingMedium) {
            // Emoji display
            Text(activityType.emoji)
                .font(Theme.Fonts.header)
                .frame(width: 32, height: 32)
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.Design.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
                // Activity type name
                Text(activityType.name)
                    .font(Theme.Fonts.header)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if !activityType.description.isEmpty {
                    Text(activityType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Archived status indicator
            if isArchived {
                Text("Archived")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, Theme.spacingSmall)
                    .padding(.vertical, Theme.spacingExtraSmall)
                    .background(Theme.Colors.divider)
                    .cornerRadius(Theme.Design.cornerRadius)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
        .opacity(isArchived ? 0.7 : 1.0)
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 12.0, *)
struct ActivityTypesView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityTypesView()
            .frame(width: 650, height: 600)
            .previewDisplayName("Live Data (from file)")

        // Preview with mock data
        let mockActivityTypes = [
            ActivityType(id: "writing", name: "Writing", emoji: "✍️", description: "Drafting and creating new content", archived: false),
            ActivityType(id: "editing", name: "Editing", emoji: "✂️", description: "Refining and improving existing content", archived: false),
            ActivityType(id: "coding", name: "Coding", emoji: "💻", description: "Writing and debugging code", archived: true)
        ]

        List(mockActivityTypes) { activityType in
            ActivityTypeRowView(activityType: activityType)
        }
        .frame(width: 650, height: 600)
        .previewDisplayName("Mock Data (for UI testing)")
        
        List {
             Text("No Activity Types Yet")
                .foregroundColor(.secondary)
                .padding(40)
        }
        .frame(width: 650, height: 600)
        .previewDisplayName("Empty State")
    }
}
#endif
