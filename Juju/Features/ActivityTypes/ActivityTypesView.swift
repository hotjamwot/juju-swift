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
    @EnvironmentObject var sidebarState: SidebarStateManager
    
    // Hover state for interactive feedback
    @State private var isHovering = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row content - compact design
            HStack(spacing: Theme.Row.compactSpacing) {
                // Activity type emoji
                Text(activityType.emoji)
                    .font(.system(size: Theme.Row.emojiSize))
                    .frame(width: 24, alignment: .leading)
                    .padding(.leading, Theme.Row.contentPadding)
                
                // Activity type details (horizontal layout with flexible spacing)
                HStack(spacing: Theme.Row.compactSpacing) {
                    // Activity type name (flexible width with minimum)
                    Text(activityType.name)
                        .font(Theme.Fonts.body.weight(.semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .frame(minWidth: 140, maxWidth: 220)
                    
                    // Activity type description (flexible width)
                    if !activityType.description.isEmpty {
                        Text(activityType.description)
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                            .frame(minWidth: 180, maxWidth: 260, alignment: .leading)
                    } else {
                        // Empty space when no description
                        Spacer().frame(minWidth: 180, maxWidth: 260)
                    }
                    
                    // Activity type ID (fixed width)
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(activityType.id.prefix(8))
                            .font(Theme.Fonts.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.divider.opacity(0.2))
                    .clipShape(Capsule())
                    .frame(width: 120)
                }
                
                Spacer()
                
                // Archived status or actions (moved to far right)
                if isArchived {
                    HStack(spacing: 8) {
                        Text("Archived")
                            .font(Theme.Fonts.caption.weight(.semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.divider.opacity(0.3))
                            .clipShape(Capsule())
                        
                        Button(action: {
                            // Restore activity type
                            Task {
                                await ActivityTypesViewModel.shared.unarchiveActivityType(activityType)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 10))
                                Text("Restore")
                                    .font(Theme.Fonts.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.divider.opacity(0.3))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .pointingHandOnHover()
                    }
                    .frame(maxWidth: 160)
                } else {
                    HStack(spacing: 8) {
                        Button(action: {
                            sidebarState.show(.activityType(activityType))
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10))
                                Text("Edit")
                                    .font(Theme.Fonts.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.divider.opacity(0.3))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .pointingHandOnHover()
                        .accessibilityLabel("Edit Activity Type")
                        .accessibilityHint("Opens the activity type editor")
                        
                        Button(action: {
                            Task {
                                await ActivityTypesViewModel.shared.archiveActivityType(activityType)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "archivebox")
                                    .font(.system(size: 10))
                                Text("Archive")
                                    .font(Theme.Fonts.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.divider.opacity(0.3))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .pointingHandOnHover()
                        .accessibilityLabel("Archive Activity Type")
                        .accessibilityHint("Archives this activity type")
                    }
                    .frame(maxWidth: 160)
                }
            }
            .frame(height: Theme.Row.height)
            .background(
                isHovering ? Theme.Colors.surface.opacity(0.9) : Theme.Colors.surface.opacity(0.7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Row.cornerRadius)
                    .stroke(Theme.Colors.divider, lineWidth: 1)
            )
            .cornerRadius(Theme.Row.cornerRadius)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                if !isArchived {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }
            
            // Expanded state - activity type details (only show when expanded for active activity types)
            if isExpanded && !isArchived {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .background(Theme.Colors.divider)
                    
                    // Create a two-column layout: 80% details, 20% actions
                    HStack(alignment: .top, spacing: 0) {
                        // Details Column (80%)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Activity Type Details")
                                    .font(Theme.Fonts.caption.weight(.semibold))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                
                                Spacer()
                            }
                            
                            // Activity type description
                            if !activityType.description.isEmpty {
                                Text(activityType.description)
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("No description provided")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Activity type ID
                            HStack {
                                Text("ID:")
                                    .font(Theme.Fonts.caption.weight(.semibold))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text(activityType.id)
                                    .font(Theme.Fonts.caption)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, Theme.Row.contentPadding)
                        .padding(.vertical, Theme.Row.contentPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Actions Column (20%)
                        VStack(alignment: .trailing, spacing: Theme.spacingSmall) {
                            // Edit Button
                            Button(action: {
                                sidebarState.show(.activityType(activityType))
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12))
                                    Text("Edit")
                                        .font(Theme.Fonts.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.Colors.divider.opacity(0.3))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandOnHover()
                            .accessibilityLabel("Edit Activity Type")
                            .accessibilityHint("Opens the activity type editor")
                            
                            // Archive Button
                            Button(action: {
                                Task {
                                    await ActivityTypesViewModel.shared.archiveActivityType(activityType)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "archivebox")
                                        .font(.system(size: 12))
                                    Text("Archive")
                                        .font(Theme.Fonts.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.Colors.divider.opacity(0.3))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandOnHover()
                            .accessibilityLabel("Archive Activity Type")
                            .accessibilityHint("Archives this activity type")
                        }
                        .padding(.trailing, Theme.Row.contentPadding)
                        .padding(.top, Theme.Row.contentPadding)
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 12.0, *)
struct ActivityTypesView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityTypesView()
            .frame(width: 800, height: 800)
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
