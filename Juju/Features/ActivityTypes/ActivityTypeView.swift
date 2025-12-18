import SwiftUI

struct ActivityTypeView: View {
    @StateObject private var viewModel = ActivityTypesViewModel.shared
    @EnvironmentObject var sidebarState: SidebarStateManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Theme.spacingMedium) {
                HStack {
                    Text("Activity Types")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer()
                }
            }
            .padding(.vertical, Theme.spacingLarge)
            .padding(.horizontal, Theme.spacingLarge)
            .background(Theme.Colors.background)

            // Activity Types List
            ScrollView {
                let shouldShowArchived = viewModel.showArchivedActivityTypes && !viewModel.archivedActivityTypes.isEmpty
                let hasAnyActivityTypes = !viewModel.activeActivityTypes.isEmpty || shouldShowArchived
                
                if !hasAnyActivityTypes {
                    Text("No Activity Types Yet")
                        .foregroundColor(Theme.Colors.surface)
                        .padding(40)
                } else {
                    LazyVStack(spacing: Theme.spacingSmall) {
                        // Active Activity Types
                        if !viewModel.activeActivityTypes.isEmpty {
                            ForEach(viewModel.activeActivityTypes) { activityType in
                                Button(action: {
                                    sidebarState.show(.activityType(activityType))
                                }) {
                                    ActivityTypeRowView(activityType: activityType, isArchived: false)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Archived Activity Types (only show if toggle is enabled)
                        if shouldShowArchived {
                            ForEach(viewModel.archivedActivityTypes) { activityType in
                                Button(action: {
                                    sidebarState.show(.activityType(activityType))
                                }) {
                                    ActivityTypeRowView(activityType: activityType, isArchived: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .overlay(
            HStack(spacing: Theme.spacingSmall) {
                // Add Activity Type button with accent color
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
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(Theme.Fonts.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.accentColor)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .pointingHandOnHover()
                .accessibilityLabel("Add Activity Type")
                .accessibilityHint("Creates a new activity type")
                
                // Archive toggle button
                Button(action: {
                    viewModel.showArchivedActivityTypes.toggle()
                }) {
                    Image(systemName: viewModel.showArchivedActivityTypes ? "archivebox.fill" : "archivebox")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Theme.Colors.divider.opacity(0.3))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .pointingHandOnHover()
                .accessibilityLabel(viewModel.showArchivedActivityTypes ? "Hide Archived Activity Types" : "Show Archived Activity Types")
                .accessibilityHint(viewModel.showArchivedActivityTypes ? "Hides archived activity types" : "Shows archived activity types")
            }
            .padding(.bottom, Theme.spacingLarge)
            .padding(.leading, Theme.spacingLarge),
            alignment: .bottomLeading
        )
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
                    .font(.system(size: 12))
                    .frame(width: 20, alignment: .leading)
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
                            .frame(minWidth: 180, maxWidth: 380, alignment: .leading)
                    } else {
                        // Empty space when no description
                        Spacer().frame(minWidth: 180, maxWidth: 380)
                    }
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
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(width: 28, height: 28)
                                .background(Theme.Colors.divider.opacity(0.3))
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
                            Image(systemName: "archivebox")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(width: 28, height: 28)
                                .background(Theme.Colors.divider.opacity(0.3))
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
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.Colors.divider.opacity(0.3))
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
                                Image(systemName: "archivebox")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.Colors.divider.opacity(0.3))
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
struct ActivityTypeView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityTypeView()
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
