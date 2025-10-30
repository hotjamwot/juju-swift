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
        .frame(width: 650, height: 450)
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
        VStack{

            Text("What did you work on?")
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.spacingLarge)
        .padding(.top, Theme.spacingExtraLarge)
        .padding(.bottom, Theme.spacingLarge)
    }

    
    // MARK: - Content View
    
    private var contentView: some View {
        VStack(spacing: 20) {
            // Notes Text Editor
            ZStack(alignment: .topLeading) {
                if viewModel.notesText.isEmpty {
                    Text("Enter your session notes here...")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.spacingLarge)
                        .padding(.vertical, Theme.spacingMedium)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $viewModel.notesText)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .focused($isTextFieldFocused)
                    .padding(Theme.spacingMedium)
            }
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.Design.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                    .stroke(Theme.Colors.divider, lineWidth: 0.5)
            )
            
            // Mood Slider View
            moodSliderView
        }
        .padding(.horizontal, Theme.spacingExtraLarge)
        .padding(.vertical, Theme.spacingMedium)
    }
    
    
    // MARK: - Mood Slider View
    private var moodSliderView: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {

            Text("How do you feel about the session?")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)

            VStack(spacing: 12) {

                Slider(
                    value: Binding(
                        get: { viewModel.mood.map { Double($0) } ?? 0 },
                        set: { value in
                            let intVal = Int(value.rounded())
                            viewModel.mood = intVal
                        }
                    ),
                    in: 0...10
                )
                .labelsHidden()
                .tint(Theme.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 0)

                HStack {
                    Text("0")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    Text("10")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            HStack {
                if let mood = viewModel.mood {
                    Text("Selected: \(mood)")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.accent)
                } else {
                    Text("No rating")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                Spacer()
            }
        }
        .padding(.top, Theme.spacingSmall)
        .padding(.bottom, Theme.spacingSmall)
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        VStack(spacing: Theme.spacingSmall) {
            
            HStack {
                Spacer()
                
                HStack(spacing: Theme.spacingMedium) {
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
