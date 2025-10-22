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
        .background(Color(Theme.Colors.background))
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.97, alpha: 1).swiftUIColor) // #F5F5F7
                
                Spacer()
            }
            .padding(.horizontal, Theme.spacingLarge)
            .padding(.top, Theme.spacingLarge)
            .padding(.bottom, Theme.spacingMedium)
            
            Divider()
                .background(Color(Theme.Colors.background))
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        VStack(spacing: 16) {
            // Notes Text Editor
            ZStack(alignment: .topLeading) {
                if viewModel.notesText.isEmpty {
                    Text("Enter your session notes here...")
                        .font(.system(size: 14))
                        .foregroundColor(NSColor(calibratedRed: 0.63, green: 0.63, blue: 0.63, alpha: 1).swiftUIColor) // #A0A0A0
                        .padding(.horizontal, Theme.spacingMedium)
                        .padding(.vertical, Theme.spacingSmall)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $viewModel.notesText)
                    .font(.system(size: 14))
                    .foregroundColor(NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.97, alpha: 1).swiftUIColor) // #F5F5F7
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .focused($isTextFieldFocused)
                    .padding(Theme.spacingSmall)
            }
            .background(NSColor(calibratedRed: 0.086, green: 0.086, blue: 0.086, alpha: 1).swiftUIColor) // Slightly darker
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(NSColor(calibratedRed: 0.173, green: 0.173, blue: 0.173, alpha: 1).swiftUIColor, lineWidth: 1) // #2C2C2C
            )
            
            // Mood Selector (optional - can be expanded later)
            moodSelectorView
        }
        .padding(.horizontal, Theme.spacingLarge)
        .padding(.vertical, Theme.spacingMedium)
    }
    
    // MARK: - Mood Selector View
    
    private var moodSelectorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How did you feel about this session?")
                .font(.system(size: 12))
                .foregroundColor(NSColor(calibratedRed: 0.63, green: 0.63, blue: 0.63, alpha: 1).swiftUIColor) // #A0A0A0
            
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { moodValue in
                    Button(action: {
                        viewModel.mood = viewModel.mood == moodValue ? nil : moodValue
                    }) {
                        Text(moodEmoji(for: moodValue))
                            .font(.system(size: 20))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(
                        Circle()
                        .fill(viewModel.mood == moodValue ? 
                              NSColor(calibratedRed: 0.56, green: 0.35, blue: 1.0, alpha: 0.3).swiftUIColor : Color.clear)
                            .frame(width: 32, height: 32)
                    )
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
                    .font(.system(size: 11))
                    .foregroundColor(NSColor(calibratedRed: 0.63, green: 0.63, blue: 0.63, alpha: 1).swiftUIColor)
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        VStack(spacing: 8) {
            Divider()
                .background(NSColor(calibratedRed: 0.173, green: 0.173, blue: 0.173, alpha: 1).swiftUIColor) // #2C2C2C
            
            HStack {
                Text("Press ⌘+Enter to save, or Esc to cancel")
                    .font(.system(size: 11))
                    .foregroundColor(NSColor(calibratedRed: 0.63, green: 0.63, blue: 0.63, alpha: 1).swiftUIColor) // #A0A0A0
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Cancel Button
                    Button("Cancel") {
                        viewModel.cancelNotes()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(NotesButtonStyle(
                        backgroundColor: NSColor(calibratedRed: 0.106, green: 0.106, blue: 0.106, alpha: 1).swiftUIColor,
                        foregroundColor: NSColor(calibratedRed: 0.63, green: 0.63, blue: 0.63, alpha: 1).swiftUIColor
                    ))
                    
                    // Save Button
                    Button("Save") {
                        viewModel.saveNotes()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!viewModel.canSave)
                    .buttonStyle(NotesButtonStyle(
                        backgroundColor: viewModel.canSave ? 
                            NSColor(calibratedRed: 0.56, green: 0.35, blue: 1.0, alpha: 1).swiftUIColor : 
                            NSColor(calibratedRed: 0.56, green: 0.35, blue: 1.0, alpha: 0.3).swiftUIColor,
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
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(foregroundColor)
            .frame(width: 90, height: 32)
            .background(backgroundColor)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
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
