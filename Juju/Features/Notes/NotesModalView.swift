import SwiftUI

struct NotesModalView: View {
    @StateObject private var viewModel: NotesViewModel
    @FocusState private var isTextFieldFocused: Bool
    
    init(viewModel: NotesViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            contentView
            
            // Footer
            footerView
        }
        .frame(width: 600, height: 400)
        .background(Theme.Colors.surface)
        .onAppear {
            // Focus the text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
        .onKeyPress { keyPress in
            // Handle keyboard shortcuts
            if keyPress.modifiers.contains(.command) && keyPress.key == .return {
                if viewModel.canSave {
                    viewModel.saveNotes()
                }
                return .handled
            }
            
            if keyPress.key == .escape {
                viewModel.cancelNotes()
                return .handled
            }
            
            return .ignored
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Nice work getting into the Juju! What did you work on?")
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, Theme.spacingLarge)
            .padding(.top, Theme.spacingLarge)
            .padding(.bottom, Theme.spacingMedium)
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        VStack(spacing: 16) {
            // Notes Text Editor
            ZStack(alignment: .topLeading) {
                if viewModel.notesText.isEmpty {
                    Text("Enter your session notes here...")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.spacingMedium)
                        .padding(.vertical, Theme.spacingSmall)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $viewModel.notesText)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .focused($isTextFieldFocused)
                    .padding(Theme.spacingSmall)
            }
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.Design.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                    .stroke(Theme.Colors.divider, lineWidth: 1)
            )
            
            // Mood Slider View
            moodSliderView
        }
        .padding(.horizontal, Theme.spacingLarge)
        .padding(.vertical, Theme.spacingMedium)
    }
    
    // MARK: - Mood Slider View
    
    private var moodSliderView: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            Text("How do you feel about the session?")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            
            HStack(spacing: 16) {
                // Left label
                Text("0")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
                // Slider track
                GeometryReader(content: { geometry in
                    ZStack {
                        // Track background
                        Rectangle()
                            .fill(Theme.Colors.divider.opacity(0.3))
                            .frame(height: 4)
                        
                        // Active track
                        Rectangle()
                            .fill(Theme.Colors.accent)
                            .frame(width: CGFloat(viewModel.mood ?? 0) / 10 * geometry.size.width)
                        
                        // Slider
                        Slider(value: Binding(
                            get: { viewModel.mood.map { Double($0) } ?? 0 },
                            set: { value in
                                let intValue = Int(value.rounded())
                                viewModel.mood = intValue
                            }
                        ), in: 0...10)
                        .labelsHidden()  // Without this, it might expand too much
                        .tint(Theme.Colors.accent)
                        .frame(width: geometry.size.width)
                    }
                })
                
                // Right label
                Text("10")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            // Current mood value display
            HStack {
                if let mood = viewModel.mood {
                    Text("Selected: \(mood)")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.accent)
                } else {
                    Text("No rating")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        VStack(spacing: Theme.spacingSmall) {
            HStack {
                Spacer()
                
                HStack(spacing: Theme.spacingSmall) {
                    // Cancel Button
                    Button("Cancel") {
                        viewModel.cancelNotes()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(NotesButtonStyle(
                        backgroundColor: Theme.Colors.surface,
                        foregroundColor: Theme.Colors.textSecondary
                    ))
                    
                    // Save Button
                    Button("Save") {
                        viewModel.saveNotes()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!viewModel.canSave)
                    .buttonStyle(NotesButtonStyle(
                        backgroundColor: viewModel.canSave ?
                            Theme.Colors.accent :
                            Theme.Colors.accent.opacity(0.5),
                        foregroundColor: .white
                    ))
                }
            }
            .padding(.horizontal, Theme.spacingLarge)
            .padding(.vertical, Theme.spacingMedium)
        }
    }
    
    // MARK: - Custom Button Style
    
    struct NotesButtonStyle: ButtonStyle {
        let backgroundColor: Color
        let foregroundColor: Color
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(Theme.Fonts.body.weight(.semibold))
                .foregroundColor(foregroundColor)
                .frame(width: 90, height: 32)
                .background(
                    Group {
                        if backgroundColor == Theme.Colors.surface {
                            backgroundColor
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                        .stroke(Theme.Colors.divider, lineWidth: 1)
                                )
                        } else {
                            backgroundColor
                        }
                    }
                )
                .cornerRadius(Theme.Design.cornerRadius)
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: Theme.Design.animationDuration), value: configuration.isPressed)
                .onHover { isHovered in
                    if isHovered {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
        }
    }
}
    
// MARK: - Preview
    
struct NotesModalView_Previews: PreviewProvider {
    static var previews: some View {
        NotesModalView(viewModel: NotesViewModel.preview)
            .previewDisplayName("Notes Modal")
    }
}

// Helper extension
private extension Int {
    func toDouble() -> Double {
        Double(self)
    }
}
