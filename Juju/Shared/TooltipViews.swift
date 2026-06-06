import SwiftUI

// MARK: - Reusable Tooltip Components

/// Styled tooltip container matching the 90-day chart tooltip appearance.
/// Reused by calendar and yearly charts for visual consistency.
struct TooltipContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.Colors.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.Colors.divider.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Theme.Colors.divider.opacity(0.25), radius: 6, x: 0, y: 3)
    }
}

/// Tooltip row: colour dot + identifier + hours.
struct TooltipRow: View {
    let color: Color
    let emoji: String?
    let name: String
    let hours: Double
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            if let emoji = emoji {
                Text(emoji)
                    .font(.system(size: 10))
            }
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(String(format: "%.1fh", hours))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

/// Tooltip divider matching the 90-day chart style.
struct TooltipDivider: View {
    var body: some View {
        Divider()
            .background(Theme.Colors.divider.opacity(0.4))
            .padding(.vertical, 1)
    }
}