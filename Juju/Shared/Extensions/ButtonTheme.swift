import SwiftUI

/// Button theme extensions to provide consistent styling across the app
public extension Theme {
    
    // MARK: Button Styles
    
    /// Primary button style
    struct ButtonStyle {
        public let font: Font
        public let height: CGFloat
        public let padding: CGFloat
        public let cornerRadius: CGFloat
        public let animationDuration: Double
        
        public init(
            font: Font = Theme.Fonts.body.weight(.semibold),
            height: CGFloat = 36,
            padding: CGFloat = 16,
            cornerRadius: CGFloat = Theme.Design.cornerRadius,
            animationDuration: Double = Theme.Design.animationDuration
        ) {
            self.font = font
            self.height = height
            self.padding = padding
            self.cornerRadius = cornerRadius
            self.animationDuration = animationDuration
        }
        
        /// Creates a button with consistent styling
        func makeButton<Content: View>(
            label: @escaping () -> Content,
            action: @escaping () -> Void,
            isDisabled: Bool = false,
            backgroundColor: Color? = nil
        ) -> some View {
            Button(action: action) {
                label()
            }
            .font(font)
            .frame(height: height)
            .padding(.horizontal, padding)
            .background(isDisabled ? Theme.Colors.surface.opacity(0.5) : (backgroundColor ?? Theme.Colors.accent))
            .cornerRadius(cornerRadius)
            .disabled(isDisabled)
            .animation(.easeInOut(duration: animationDuration), value: isDisabled)
        }
    }
    
    /// Secondary button style
    struct SecondaryButtonStyle {
        public let font: Font
        public let height: CGFloat
        public let padding: CGFloat
        public let cornerRadius: CGFloat
        public let animationDuration: Double
        
        public init(
            font: Font = Theme.Fonts.body.weight(.semibold),
            height: CGFloat = 36,
            padding: CGFloat = 16,
            cornerRadius: CGFloat = Theme.Design.cornerRadius,
            animationDuration: Double = Theme.Design.animationDuration
        ) {
            self.font = font
            self.height = height
            self.padding = padding
            self.cornerRadius = cornerRadius
            self.animationDuration = animationDuration
        }
        
        /// Creates a secondary button with consistent styling
        func makeButton<Content: View>(
            label: @escaping () -> Content,
            action: @escaping () -> Void,
            isDisabled: Bool = false
        ) -> some View {
            Button(action: action) {
                label()
            }
            .font(font)
            .frame(height: height)
            .padding(.horizontal, padding)
            .background(isDisabled ? Theme.Colors.surface.opacity(0.5) : Theme.Colors.surface)
            .cornerRadius(cornerRadius)
            .disabled(isDisabled)
            .animation(.easeInOut(duration: animationDuration), value: isDisabled)
        }
    }
    
    /// IconButton style for buttons with just icons
    struct IconButtonStyle {
        public let size: CGFloat
        public let iconSize: CGFloat
        public let cornerRadius: CGFloat
        public let animationDuration: Double
        
        public init(
            size: CGFloat = 36,
            iconSize: CGFloat = 12,
            cornerRadius: CGFloat = Theme.Design.cornerRadius,
            animationDuration: Double = Theme.Design.animationDuration
        ) {
            self.size = size
            self.iconSize = iconSize
            self.cornerRadius = cornerRadius
            self.animationDuration = animationDuration
        }
        
        /// Creates an icon button with consistent styling
        func makeIconButton<Content: View>(
            label: @escaping () -> Content,
            action: @escaping () -> Void,
            isDisabled: Bool = false
        ) -> some View {
            Button(action: action) {
                label()
            }
            .font(.system(size: iconSize))
            .frame(width: size, height: size)
            .background(isDisabled ? Theme.Colors.surface : Theme.Colors.surface)
            .cornerRadius(cornerRadius)
            .disabled(isDisabled)
            .animation(.easeInOut(duration: animationDuration), value: isDisabled)
        }
    }
    
    /// Simple Icon Button style for icon-only buttons without background
    struct SimpleIconButtonStyle {
        public let iconSize: CGFloat
        public let animationDuration: Double
        
        public init(
            iconSize: CGFloat = 16,
            animationDuration: Double = Theme.Design.animationDuration
        ) {
            self.iconSize = iconSize
            self.animationDuration = animationDuration
        }
        
        /// Creates a simple icon button without background or outline
        func makeSimpleIconButton<Content: View>(
            label: @escaping () -> Content,
            action: @escaping () -> Void,
            isDisabled: Bool = false
        ) -> some View {
            Button(action: action) {
                label()
            }
            .font(.system(size: iconSize))
            .foregroundColor(isDisabled ? Theme.Colors.textSecondary.opacity(0.3) : Theme.Colors.textPrimary.opacity(0.6))
            .disabled(isDisabled)
            .animation(.easeInOut(duration: animationDuration), value: isDisabled)
        }
    }
}
