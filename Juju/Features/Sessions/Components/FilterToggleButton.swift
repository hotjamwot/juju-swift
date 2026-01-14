import SwiftUI

// MARK: - Filter Toggle Button
struct FilterToggleButton: View {
    @ObservedObject var filterState: FilterExportState
    let filteredSessionsCount: Int
    let onToggle: () -> Void

    @State private var isButtonHovering = false

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button(action: onToggle) {
                    HStack(spacing: Theme.spacingSmall) {
                        // Session count text
                        Text("\(filteredSessionsCount) sessions")
                            .font(.caption.weight(.medium))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.spacingSmall)
                            .padding(.vertical, Theme.spacingExtraSmall)
                        // Removed background fill for consistency

                        // Upward chevron with hover effect
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isButtonHovering ? Theme.Colors.accentColor : Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, Theme.spacingMedium)
                    .padding(.vertical, Theme.spacingSmall)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Row.cornerRadius)
                            .fill(Theme.Colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Row.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: isButtonHovering ? 1.5 : 1) // Thicker border on hover
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 1)
                    .scaleEffect(isButtonHovering ? 1.02 : 1.0) // Subtle scale on hover
                    .animation(.easeInOut(duration: 0.2), value: isButtonHovering)
                }
                .help("Show filter bar")
                .buttonStyle(.plain)
                .onHover { hovering in
                    isButtonHovering = hovering
                }
            }
        }
    }
}

// MARK: - Hover Detection Helper
struct BottomHoverDetector: View {
    let onHoverBottom: (Bool) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onHover { hovering in
                    let bottomAreaHeight = geometry.size.height * 0.2
                    let isHoveringBottom = geometry.frame(in: .global).minY < bottomAreaHeight
                    
                    if hovering && isHoveringBottom {
                        onHoverBottom(true)
                    } else if !hovering {
                        onHoverBottom(false)
                    }
                }
        }
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct FilterToggleButton_Previews: PreviewProvider {
    static var previews: some View {
        let filterState = FilterExportState()
        
        VStack {
            Spacer()
            FilterToggleButton(
                filterState: filterState,
                filteredSessionsCount: 42,
                onToggle: { }
            )
        }
        .padding()
        .background(Theme.Colors.background)
    }
}
#endif
