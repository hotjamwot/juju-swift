import SwiftUI

/// Reusable filter button for session filtering
public struct SessionFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    public init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.caption)
                .lineLimit(1)
                .padding(.horizontal, Theme.spacingSmall)
                .padding(.vertical, Theme.spacingExtraSmall)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .fill(isSelected ? Theme.Colors.accent : Theme.Colors.surface)
                        if isSelected {
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .fill(Theme.Colors.accent.opacity(0.9))
                                .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 6, x: 0, y: 2)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                )
                .foregroundColor(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: Theme.Design.animationDuration), value: isSelected)
    }
}

// MARK: - Date Filter Options
/// Enum for date filtering options
public enum DateFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case clear = "Clear"
    
    public var id: String { rawValue }
    public var title: String { rawValue }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct SessionFilterButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Normal state
            SessionFilterButton(
                title: "Today",
                isSelected: false,
                action: { print("Today clicked") }
            )
            .frame(width: 100)
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // Selected state
            SessionFilterButton(
                title: "This Week",
                isSelected: true,
                action: { print("This Week clicked") }
            )
            .frame(width: 120)
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // Multiple buttons with different states
            HStack(spacing: 16) {
                SessionFilterButton(
                    title: "Today",
                    isSelected: false,
                    action: { print("Today clicked") }
                )
                
                SessionFilterButton(
                    title: "This Week",
                    isSelected: true,
                    action: { print("This Week clicked") }
                )
                
                SessionFilterButton(
                    title: "This Month",
                    isSelected: false,
                    action: { print("This Month clicked") }
                )
                
                SessionFilterButton(
                    title: "Clear",
                    isSelected: false,
                    action: { print("Clear clicked") }
                )
            }
            .background(Color(.windowBackgroundColor))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
