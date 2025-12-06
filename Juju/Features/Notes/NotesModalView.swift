import SwiftUI

struct NotesModalView: View {
    @StateObject private var viewModel: NotesViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingAddPhaseDialog = false
    @State private var newPhaseName = ""
    
    init(viewModel: NotesViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            contentView
            footerView
        }
        .frame(minWidth: 900, minHeight: 700)
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
        .addPhaseDialog(
            isPresented: $showingAddPhaseDialog,
            phaseName: $newPhaseName,
            onAdd: {
                viewModel.addPhase(name: newPhaseName)
                newPhaseName = ""
                showingAddPhaseDialog = false
            },
            onCancel: {
                newPhaseName = ""
                showingAddPhaseDialog = false
            },
            projectName: viewModel.currentProjectName
        )
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

                Text("Ooh yeah, nice work on the \(viewModel.currentProjectName ?? "Project") Juju session!")
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
                // 1. Activity Type and Phase dropdowns (on same row)
                HStack(spacing: Theme.spacingMedium) {
                    // Activity Type dropdown
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
                    .frame(maxWidth: .infinity)
                    
                    // Phase dropdown
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
                                    showingAddPhaseDialog = true
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
                    .frame(maxWidth: .infinity)
                }
                
                // 2. Notes (full width and large)
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
                            .frame(minHeight: 200)
                            .padding(Theme.spacingSmall)
                    }
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
                }
                
                // 3. Mood slider
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
            }
            .padding(.horizontal, Theme.spacingExtraLarge)
            .padding(.vertical, Theme.spacingMedium)
        }
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        HStack(alignment: .bottom, spacing: Theme.spacingExtraLarge) {
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
        SimplePreviewHelpers.notesModal {
            NotesModalView(viewModel: NotesViewModel.preview)
        }
    }
}

// MARK: - Add Phase Dialog Extension
private extension View {
    func addPhaseDialog(
        isPresented: Binding<Bool>,
        phaseName: Binding<String>,
        onAdd: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        projectName: String?
    ) -> some View {
        self.modifier(AddPhaseDialogModifier(
            isPresented: isPresented,
            phaseName: phaseName,
            onAdd: onAdd,
            onCancel: onCancel,
            projectName: projectName
        ))
    }
}

private struct AddPhaseDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var phaseName: String
    let onAdd: () -> Void
    let onCancel: () -> Void
    let projectName: String?
    
    @FocusState private var isTextFieldFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isPresented {
                        GeometryReader { geometry in
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    onCancel()
                                }
                            
                            VStack(spacing: Theme.spacingMedium) {
                                Text("Add New Phase")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                
                                Text("Create a new phase for \(projectName ?? "this project")")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                
                                TextField("Phase name", text: $phaseName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .focused($isTextFieldFocused)
                                    .padding(.horizontal, Theme.spacingMedium)
                                    .padding(.vertical, Theme.spacingSmall)
                                    .background(Theme.Colors.surface)
                                    .cornerRadius(Theme.Design.cornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                            .stroke(Theme.Colors.divider, lineWidth: 1)
                                    )
                                
                                HStack(spacing: Theme.spacingMedium) {
                                    Button("Cancel") {
                                        onCancel()
                                    }
                                    .buttonStyle(.secondary)
                                    
                                    Button("Add Phase") {
                                        if !phaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            onAdd()
                                        }
                                    }
                                    .buttonStyle(.primary)
                                    .disabled(phaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }
                            .padding(.horizontal, Theme.spacingExtraLarge)
                            .padding(.vertical, Theme.spacingLarge)
                            .background(Theme.Colors.background)
                            .cornerRadius(Theme.Design.cornerRadius)
                            .shadow(radius: 10)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isTextFieldFocused = true
                                }
                            }
                        }
                    }
                }
            )
    }
}
