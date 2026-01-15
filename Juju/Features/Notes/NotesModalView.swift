import SwiftUI

struct NotesModalView: View {
    @StateObject private var viewModel: NotesViewModel
    @FocusState private var isActionTextFieldFocused: Bool
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
        .frame(minWidth: 900, minHeight: 700) // Adjusted minHeight
        .padding(Theme.spacingExtraLarge)
        .background(Theme.Colors.background)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isActionTextFieldFocused = true // Focus the Action field
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
                    .frame(width: 32, height: 32)
                    .shadow(radius: 1)

                Text("Ooh yeah, nice work on the \(viewModel.currentProjectName ?? "Project") Juju session!")
            }
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(Theme.Colors.textPrimary)

        
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.spacingExtraLarge)
        .padding(.vertical, Theme.spacingExtraLarge)
    }

    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            VStack(spacing: Theme.spacingLarge) {
                // 1. Activity Type and Phase dropdowns (on same row)
                HStack(spacing: Theme.spacingMedium) {
                    // Activity Type dropdown
                    HStack(spacing: Theme.spacingSmall) {
                        Picker(selection: $viewModel.selectedActivityTypeID) {
                            Text("Select").tag(nil as String?)
                            ForEach(viewModel.mostUsedActivityTypes) { activityType in
                                Text("\(activityType.emoji) \(activityType.name)").tag(activityType.id as String?)
                            }
                        } label: {
                            Text("Activity Type")
                        }
                        .pickerStyle(.menu)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Phase dropdown
                    HStack(spacing: Theme.spacingSmall) {
                        Picker(selection: $viewModel.selectedProjectPhaseID) {
                            Text("Select").tag(nil as String?)
                            if viewModel.availablePhases.isEmpty {
                                Text("No phases available").tag("no-phases" as String?)
                            } else {
                                ForEach(viewModel.availablePhases) { phase in
                                    Text(phase.name).tag(phase.id as String?)
                                }
                            }
                            Divider()
                            Text("Add New Phase").tag("add-phase" as String?)
                        } label: {
                            Text("Phase")
                        }
                        .pickerStyle(.menu)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .onChange(of: viewModel.selectedProjectPhaseID) { newValue in
                            if newValue == "add-phase" {
                                showingAddPhaseDialog = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    viewModel.selectedProjectPhaseID = nil
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // 2. Notes (full width and large)
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
                        .frame(minHeight: 200)
                        .padding(Theme.spacingSmall)
                }
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.Design.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
                
                // 3. Mood slider (compact layout)
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("Mood")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    HStack(spacing: Theme.spacingMedium) {
                        VStack(spacing: 8) {
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
                        
                        Spacer()
                        
                        if let mood = viewModel.mood {
                            Text("\(mood)")
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.accentColor)
                                .frame(width: 40, alignment: .trailing)
                        } else {
                            Text("-")
                                .font(Theme.Fonts.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, Theme.spacingLarge)
                    .padding(.vertical, Theme.spacingMedium)
                }
                
                // 4. Action and Milestone (new compact layout)
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    HStack(alignment: .top, spacing: Theme.spacingMedium) {
                        // Action Text Field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Action")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            TextField("e.g., Finished Act I", text: $viewModel.action) // Bind to viewModel.action
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
                                .focused($isActionTextFieldFocused) // Focus this field
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Milestone Toggle
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Milestone")
                                .font(Theme.Fonts.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            Toggle("", isOn: $viewModel.isMilestone) // Bind to viewModel.isMilestone
                                .labelsHidden()
                                .padding(.horizontal, Theme.spacingMedium)
                                .padding(.vertical, Theme.spacingSmall)
                                .background(Theme.Colors.surface)
                                .cornerRadius(Theme.Design.cornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                        .stroke(Theme.Colors.divider, lineWidth: 1)
                                )
                                .disabled(viewModel.action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, Theme.spacingExtraLarge)
            .padding(.vertical, Theme.spacingLarge)
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
                    viewModel.saveNotes() // ViewModel now has the correct action and isMilestone
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
