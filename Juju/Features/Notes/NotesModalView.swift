import SwiftUI

// Import simple preview helpers
import Juju

struct NotesModalView: View {
    @StateObject private var viewModel: NotesViewModel
    @FocusState private var isTextFieldFocused: Bool
    
    init(viewModel: NotesViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            contentView
            footerView
        }
        .frame(minWidth: 750, minHeight: 600)
        .background(Theme.Colors.background)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
        .onKeyPress { keyPress in
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
        VStack(spacing: Theme.spacingMedium) {
            HStack(spacing: Theme.spacingMedium) {
                Image("juju_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .shadow(radius: 1)

                Text("Ooh yeah, get in the Juju!")
            }
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(Theme.Colors.textPrimary)

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
        ScrollView {
            VStack(spacing: Theme.spacingMedium) {
                // 1. Project (locked) - pre-filled from session start
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("Project")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    HStack {
                        Text(viewModel.currentProjectName ?? "Unknown Project")
                            .font(Theme.Fonts.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, Theme.spacingMedium)
                    .padding(.vertical, Theme.spacingSmall)
                    .background(Theme.Colors.surface.opacity(0.5))
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
                }
                
                // 2. Activity Type dropdown - with last used default for this project
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("Activity Type")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Picker("Activity Type", selection: $viewModel.selectedActivityTypeID) {
                        Text("Select Activity Type").tag(nil as String?)
                        ForEach(viewModel.activityTypes) { activityType in
                            HStack {
                                Text(activityType.emoji)
                                Text(activityType.name)
                            }
                            .tag(activityType.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.spacingMedium)
                    .padding(.vertical, Theme.spacingSmall)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
                }
                
                // 3. Phase dropdown - with last used default for this project
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("Phase")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    if viewModel.availablePhases.isEmpty {
                        HStack {
                            Text("No phases available")
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                            Button("Add Phase") {
                                // TODO: Implement add phase functionality
                            }
                            .font(Theme.Fonts.caption)
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Theme.spacingMedium)
                        .padding(.vertical, Theme.spacingSmall)
                        .background(Theme.Colors.surface.opacity(0.5))
                        .cornerRadius(Theme.Design.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                    } else {
                        Picker("Phase", selection: $viewModel.selectedProjectPhaseID) {
                            Text("Select Phase").tag(nil as String?)
                            ForEach(viewModel.availablePhases) { phase in
                                Text(phase.name).tag(phase.id as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.horizontal, Theme.spacingMedium)
                        .padding(.vertical, Theme.spacingSmall)
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.Design.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                    }
                }
                
                // 4. Milestone
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("Milestone (Optional)")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    TextField("e.g., Finished Act I", text: $viewModel.milestoneText)
                        .textFieldStyle(.plain)
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.horizontal, Theme.spacingMedium)
                        .padding(.vertical, Theme.spacingSmall)
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.Design.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                }
                
                // 5. Notes
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("Notes")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    ZStack(alignment: .topLeading) {
                        if viewModel.notesText.isEmpty {
                            Text("Enter your session notes here...")
                                .font(Theme.Fonts.body)
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
                            .frame(minHeight: 100)
                            .padding(Theme.spacingSmall)
                    }
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, Theme.spacingExtraLarge)
            .padding(.vertical, Theme.spacingMedium)
        }
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        HStack(alignment: .bottom, spacing: Theme.spacingExtraLarge) {
            // --- Left Column: Mood Slider (takes up remaining space) ---
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("How do you feel about the session?")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)

                VStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { viewModel.mood.map { Double($0) } ?? 0 },
                            set: { value in
                                viewModel.mood = Int(value.rounded())
                            }
                        ),
                        in: 0...10
                    )
                    .labelsHidden()
                    .tint(Theme.Colors.accentColor)

                    HStack {
                        Text("0").font(Theme.Fonts.caption).foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text("10").font(Theme.Fonts.caption).foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                if let mood = viewModel.mood {
                    Text("Selected: \(mood)")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.accentColor)
                } else {
                    Text("No rating")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // --- Right Column: Buttons ---
            HStack(spacing: Theme.spacingMedium) {
                Button("Cancel") {
                    viewModel.cancelNotes()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.secondary)
                
                Button("Save") {
                    viewModel.saveNotes()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.primary)
                .disabled(!viewModel.canSave)
            }
        }
        .padding(.horizontal, Theme.spacingExtraLarge)
        .padding(.vertical, Theme.spacingMedium)
    }
}
    
// MARK: - Preview
struct NotesModalView_Previews: PreviewProvider {
    static var previews: some View {
        SimplePreviewHelpers.modal {
            NotesModalView(viewModel: NotesViewModel.preview)
        }
    }
}
