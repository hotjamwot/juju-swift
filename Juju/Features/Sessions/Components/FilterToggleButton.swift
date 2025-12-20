import SwiftUI

// MARK: - Filter Toggle Button
struct FilterToggleButton: View {
    @ObservedObject var filterState: FilterExportState
    let filteredSessionsCount: Int
    let onToggle: () -> Void
    
    // Hover state for animation
    @State private var isHovering = false
    
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
                            .foregroundColor(isHovering ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.spacingSmall)
                            .padding(.vertical, Theme.spacingExtraSmall)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius / 2)
                                    .fill(isHovering ? Theme.Colors.accentColor.opacity(0.1) : Theme.Colors.divider.opacity(0.2))
                            )
                            .animation(.easeInOut(duration: 0.2), value: isHovering)
                        
                        // Upward chevron
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isHovering ? Theme.Colors.accentColor : Theme.Colors.textSecondary)
                            .animation(.easeInOut(duration: 0.2), value: isHovering)
                    }
                    .padding(.horizontal, Theme.spacingMedium)
                    .padding(.vertical, Theme.spacingSmall)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Row.cornerRadius)
                            .fill(Theme.Colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Row.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 1)
                    .opacity(1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovering)
                }
                .help("Show filter bar")
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHovering = hovering
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
