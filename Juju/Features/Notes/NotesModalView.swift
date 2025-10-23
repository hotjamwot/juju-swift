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
                Text("What did you work on?")
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, Theme.spacingLarge)
            .padding(.top, Theme.spacingLarge)
            .padding(.bottom, Theme.spacingMedium)
            
            Divider()
                .background(Theme.Colors.divider)
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
            
            // Mood Selector (optional - can be expanded later)
            moodSelectorView
        }
        .padding(.horizontal, Theme.spacingLarge)
        .padding(.vertical, Theme.spacingMedium)
    }
    
    // MARK: - Mood Selector View
    
    private var moodSelectorView: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            Text("How did you feel about this session?")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            
            HStack(spacing: Theme.spacingSmall) {
                ForEach(1...5, id: \.self) { moodValue in
                    Button(action: {
                        viewModel.mood = viewModel.mood == moodValue ? nil : moodValue
                    }) {
                        Text(moodEmoji(for: moodValue))
                            .font(Theme.Fonts.icon)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(
                        Circle()
                        .fill(viewModel.mood == moodValue ? 
                              Theme.Colors.accent.opacity(0.3) : Color.clear)
                            .frame(width: 32, height: 32)
                    )
                    .cornerRadius(Theme.Design.cornerRadius)
                    .onHover { isHovered in
                        if isHovered {
                            NSCursor.pointingHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                }
                
                Spacer()
                
                if viewModel.mood != nil {
                    Button("Clear") {
                        viewModel.mood = nil
                    }
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        VStack(spacing: Theme.spacingSmall) {
            Divider()
                .background(Theme.Colors.divider)
            
            HStack {
                Text("Press ⌘+Enter to save, or Esc to cancel")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                
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
    
    // MARK: - Helper Methods
    
    private func moodEmoji(for mood: Int) -> String {
        switch mood {
        case 1: return "😔"
        case 2: return "😐"
        case 3: return "🙂"
        case 4: return "😊"
        case 5: return "🤩"
        default: return "🙂"
        }
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
            .background(backgroundColor)
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

// MARK: - Preview

struct NotesModalView_Previews: PreviewProvider {
    static var previews: some View {
        NotesModalView(viewModel: NotesViewModel.preview)
            .previewDisplayName("Notes Modal")
    }
}
