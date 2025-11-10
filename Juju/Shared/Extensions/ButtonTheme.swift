import SwiftUI

// MARK: - ButtonStyle Protocol Implementations

/// Primary button style with a prominent background color.
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var backgroundColor: Color = Theme.Colors.accentColor
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.body.weight(.semibold))
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(isEnabled ? backgroundColor : Theme.Colors.surface.opacity(0.9))
            .foregroundColor(Theme.Colors.textPrimary)
            .cornerRadius(Theme.Design.cornerRadius)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: Theme.Design.animationDuration), value: isEnabled)
    }
}

/// Secondary button style with a subtle background and clear emphasis.
public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.body)
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(isEnabled ? Theme.Colors.surface : Theme.Colors.surface.opacity(0.5))
            .foregroundColor(isEnabled ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
            .cornerRadius(Theme.Design.cornerRadius)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: Theme.Design.animationDuration), value: isEnabled)
    }
}

/// Style for icon-only buttons with a background.
public struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .frame(width: 36, height: 36)
            .background(Theme.Colors.surface)
            .foregroundColor(isEnabled ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
            .cornerRadius(Theme.Design.cornerRadius)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: Theme.Design.animationDuration), value: isEnabled)
    }
}

/// Style for icon-only buttons with no background (e.g., for inline editing).
public struct SimpleIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var iconSize: CGFloat
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: iconSize))
            .foregroundColor(
                isEnabled ?
                (configuration.isPressed ? Theme.Colors.accentColor : Theme.Colors.textPrimary.opacity(0.6))
                : Theme.Colors.textSecondary.opacity(0.3)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: Theme.Design.animationDuration), value: isEnabled)
    }
}

/// Style for filter or tab-like buttons that can be selected.
public struct FilterButtonStyle: ButtonStyle {
    var isSelected: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.caption.weight(.medium))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                isSelected ? Theme.Colors.accentColor :
                    (configuration.isPressed ? Theme.Colors.surface.opacity(0.8) : Theme.Colors.surface)
            )
            .foregroundColor(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
            .cornerRadius(Theme.Design.cornerRadius)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}



// MARK: - Theme Extension for Easy Access

public extension ButtonStyle where Self == PrimaryButtonStyle {
    /// The primary button style for the app. Use for the most important action.
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }

    /// A primary button style with a destructive/danger appearance.
    static var destructive: PrimaryButtonStyle {
        PrimaryButtonStyle(backgroundColor: .red)
    }
}

public extension ButtonStyle where Self == SecondaryButtonStyle {
    /// The secondary button style for the app. Use for less prominent actions.
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

public extension ButtonStyle where Self == IconButtonStyle {
    /// A style for icon-only buttons with a background, like toolbar actions.
    static var icon: IconButtonStyle { IconButtonStyle() }
}

public extension ButtonStyle where Self == SimpleIconButtonStyle {
    /// A style for icon-only buttons without a background, using the default size (16pt).
    static var simpleIcon: SimpleIconButtonStyle {
        SimpleIconButtonStyle(iconSize: 16) // Pass the default size
    }
    /// A style for icon-only buttons without a background, with a custom icon size.
    /// - Parameter size: The desired font size for the icon.
    static func simpleIcon(size: CGFloat) -> SimpleIconButtonStyle { 
        SimpleIconButtonStyle(iconSize: size)
    }
}


struct PointingHandOnHover: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onHover { isHovered in
                if isHovered {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
    }
}
public extension View {
    /// Applies a modifier that changes the cursor to a pointing hand on hover.
    func pointingHandOnHover() -> some View {
        self.modifier(PointingHandOnHover())
    }
}

// MARK: - Previews
#if DEBUG
struct ButtonTheme_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // --- Light Mode ---
            VStack(spacing: 30) {
                // Primary
                VStack(alignment: .leading) {
                    Text("Primary Buttons").font(.headline)
                    HStack {
                        Button("Primary Action") {}.buttonStyle(.primary)
                        Button("Disabled") {}.buttonStyle(.primary).disabled(true)
                        Button("Destructive") {}.buttonStyle(.destructive)
                    }
                }
                
                // Secondary
                VStack(alignment: .leading) {
                    Text("Secondary Buttons").font(.headline)
                    HStack {
                        Button("Secondary Action") {}.buttonStyle(.secondary)
                        Button("Disabled") {}.buttonStyle(.secondary).disabled(true)
                    }
                }
                
                // Icon Buttons
                VStack(alignment: .leading) {
                    Text("Icon Buttons").font(.headline)
                    HStack {
                        Button { } label: { Image(systemName: "plus") }.buttonStyle(.icon)
                        Button { } label: { Image(systemName: "trash") }.buttonStyle(.icon).disabled(true)
                        Text("—").padding(.horizontal)
                        Button { } label: { Image(systemName: "pencil") }.buttonStyle(.simpleIcon)
                        Button { } label: { Image(systemName: "paperplane") }.buttonStyle(.simpleIcon).disabled(true)
                    }
                }
            }
            .padding(40)
            .frame(width: 500)
            .background(Color(NSColor.windowBackgroundColor))
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
            
            // --- Dark Mode ---
            VStack(spacing: 30) {
                // Primary
                VStack(alignment: .leading) {
                    Text("Primary Buttons").font(.headline)
                    HStack {
                        Button("Primary Action") {}.buttonStyle(.primary)
                        Button("Disabled") {}.buttonStyle(.primary).disabled(true)
                        Button("Destructive") {}.buttonStyle(.destructive)
                    }
                }
                
                // Secondary
                VStack(alignment: .leading) {
                    Text("Secondary Buttons").font(.headline)
                    HStack {
                        Button("Secondary Action") {}.buttonStyle(.secondary)
                        // ✅ CORRECTED THIS LINE
                        Button("Disabled") {}.buttonStyle(.secondary).disabled(true)
                    }
                }
                
                // Icon Buttons
                VStack(alignment: .leading) {
                    Text("Icon Buttons").font(.headline)
                    HStack {
                        Button { } label: { Image(systemName: "plus") }.buttonStyle(.icon)
                        Button { } label: { Image(systemName: "trash") }.buttonStyle(.icon).disabled(true)
                        Text("—").padding(.horizontal)
                        Button { } label: { Image(systemName: "pencil") }.buttonStyle(.simpleIcon)
                        Button { } label: { Image(systemName: "paperplane") }.buttonStyle(.simpleIcon).disabled(true)
                    }
                }
            }
            .padding(40)
            .frame(width: 500)
            .background(Theme.Colors.surface)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
