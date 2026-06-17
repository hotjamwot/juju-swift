import SwiftUI

private struct PhaseRemovalConfirmation: Identifiable {
    let phaseID: String
    let name: String
    let sessionCount: Int
    var id: String { phaseID }
}

private struct PhaseRemovalAlertModifier: ViewModifier {
    @Binding var confirmation: PhaseRemovalConfirmation?
    @Binding var phases: [Phase]
    let onPhasesChanged: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                "Remove phase?",
                isPresented: Binding(
                    get: { confirmation != nil },
                    set: { if !$0 { confirmation = nil } }
                ),
                presenting: confirmation
            ) { detail in
                Button("Remove", role: .destructive) {
                    if let index = phases.firstIndex(where: { $0.id == detail.phaseID }) {
                        phases.remove(at: index)
                        onPhasesChanged()
                    }
                    confirmation = nil
                }
                Button("Cancel", role: .cancel) {
                    confirmation = nil
                }
            } message: { detail in
                Text(Self.message(for: detail))
            }
    }

    private static func message(for confirmation: PhaseRemovalConfirmation) -> String {
        "\"\(confirmation.name)\" will be removed when you save this project. \(confirmation.sessionCount) session(s) currently use this phase; saving will clear their phase tag (nil) for this project."
    }
}

/// Sidebar view for editing project details with live preview and enhanced layout
struct ProjectSidebarEditView: View {
    @EnvironmentObject var sidebarState: SidebarStateManager
    @EnvironmentObject var projectsViewModel: ProjectsViewModel

    @State private var project: Project
    @State private var tempName: String
    @State private var tempEmoji: String
    @State private var tempColor: Color
    @State private var tempAbout: String
    @State private var tempPhases: [Phase]
    @State private var tempIsArchived: Bool

    /// Confirms removing a phase that still has sessions (clears phase on save).
    @State private var phaseRemovalConfirmation: PhaseRemovalConfirmation?

    // Form validation
    @State private var hasChanges = false
    @State private var isSaving = false

    init(project: Project) {
        self._project = State(initialValue: project)
        self._tempName = State(initialValue: project.name)
        self._tempEmoji = State(initialValue: project.emoji)
        self._tempColor = State(initialValue: Color(hex: project.color))
        self._tempAbout = State(initialValue: project.about ?? "")
        self._tempPhases = State(initialValue: project.phases.sorted { $0.order < $1.order })
        self._tempIsArchived = State(initialValue: project.archived)
    }

    var body: some View {
        editorRoot
            .padding(Theme.spacingLarge)
            .onChange(of: tempName) { _ in validateChanges() }
            .onChange(of: tempEmoji) { _ in validateChanges() }
            .onChange(of: tempColor) { _ in validateChanges() }
            .onChange(of: tempAbout) { _ in validateChanges() }
            .onChange(of: tempPhases) { _ in validateChanges() }
            .onChange(of: tempIsArchived) { _ in validateChanges() }
            .modifier(PhaseRemovalAlertModifier(
                confirmation: $phaseRemovalConfirmation,
                phases: $tempPhases,
                onPhasesChanged: { self.renumberPhaseOrders() }
            ))
    }

    @ViewBuilder
    private var editorRoot: some View {
        VStack(spacing: Theme.spacingLarge) {
            // Basic Info card
            basicInfoCard

            // Phases card
            phasesCard

            // Archive card
            archiveCard

            Spacer()

            // Action buttons
            actionButtons
                .padding(.bottom, Theme.spacingMedium)
        }
    }

    // MARK: - Cards

    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLarge) {
            sectionHeader("Basic Information")

            // Project Name
            HStack {
                Text("Name")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 80, alignment: .leading)
                TextField("", text: $tempName)
                    .textFieldStyle(.plain)
                    .font(Theme.Fonts.body)
                    .padding(Theme.spacingSmall)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .frame(maxWidth: .infinity)
            }

            // Emoji and Color
            HStack(spacing: Theme.spacingLarge) {
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("Emoji")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                    TextField("", text: $tempEmoji)
                        .textFieldStyle(.plain)
                        .font(.title2)
                        .frame(width: 32, height: 32)
                        .multilineTextAlignment(.center)
                        .background(Theme.Colors.background)
                        .cornerRadius(Theme.Design.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                }

                Spacer()

                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("Color")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                    ColorPicker("", selection: $tempColor)
                        .labelsHidden()
                        .frame(width: 24, height: 24)
                }
            }

            // Description
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Description")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextEditor(text: $tempAbout)
                    .frame(minHeight: 100)
                    .textFieldStyle(.plain)
                    .font(Theme.Fonts.body)
                    .padding(Theme.spacingSmall)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(Theme.spacingLarge)
        .cardStyle()
    }

    private var phasesCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLarge) {
            sectionHeader("Phases")

            ForEach(tempPhases.indices, id: \.self) { index in
                HStack(spacing: Theme.spacingSmall) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .frame(width: 24)

                    TextField("", text: Binding(
                        get: { tempPhases[index].name },
                        set: { newValue in
                            tempPhases[index].name = newValue
                        }
                    ))
                    .textFieldStyle(.plain)
                    .font(Theme.Fonts.body)
                    .padding(Theme.spacingSmall)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .frame(maxWidth: .infinity)
                    .opacity(tempPhases[index].archived ? 0.65 : 1)

                    Toggle(isOn: Binding(
                        get: { tempPhases[index].archived },
                        set: { newValue in
                            tempPhases[index].archived = newValue
                        }
                    )) {
                        Text("Retired")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .toggleStyle(.checkbox)
                    .help("Archived phases stay visible on past sessions but are hidden when picking a phase for new work.")

                    Button(action: {
                        self.requestRemovePhase(at: index)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Remove this phase from the project")
                }
                .onDrag {
                    let itemProvider = NSItemProvider()
                    itemProvider.registerDataRepresentation(forTypeIdentifier: "public.text", visibility: .all) { completion in
                        let data = String(index).data(using: .utf8) ?? Data()
                        completion(data, nil)
                        return nil
                    }
                    return itemProvider
                }
                .onDrop(of: ["public.text"], delegate: PhaseDropDelegate(
                    index: index,
                    phases: $tempPhases
                ))
            }

            Button(action: {
                let newPhase = Phase(name: "New Phase", order: tempPhases.count)
                tempPhases.append(newPhase)
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Theme.Colors.accentColor)
                    Text("Add Phase")
                        .foregroundColor(Theme.Colors.accentColor)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(Theme.spacingLarge)
        .cardStyle()
    }

    private var archiveCard: some View {
        HStack {
            Toggle("", isOn: $tempIsArchived)
            Spacer()
            Text(tempIsArchived ? "Archived" : "Active")
                .font(Theme.Fonts.caption)
                .foregroundColor(tempIsArchived ? Theme.Colors.error : Color.green.opacity(0.8))
        }
        .padding(Theme.spacingLarge)
        .cardStyle()
    }

    /// Styled section header matching the theme's caption hierarchy
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Theme.Fonts.caption.weight(.semibold))
            .foregroundColor(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func requestRemovePhase(at index: Int) {
        let phase = tempPhases[index]
        if project.id.isEmpty {
            tempPhases.remove(at: index)
            renumberPhaseOrders()
            return
        }
        let sessionCount = SessionManager.shared.allSessions.filter {
            $0.projectID == project.id && $0.projectPhaseID == phase.id
        }.count
        if sessionCount == 0 {
            tempPhases.remove(at: index)
            renumberPhaseOrders()
            return
        }
        phaseRemovalConfirmation = PhaseRemovalConfirmation(
            phaseID: phase.id,
            name: phase.name,
            sessionCount: sessionCount
        )
    }

    func renumberPhaseOrders() {
        for i in tempPhases.indices {
            tempPhases[i].order = i
        }
    }

    private var actionButtons: some View {
        HStack {
            Button("Cancel") {
                sidebarState.hide()
            }
            .buttonStyle(SecondaryButtonStyle())

            Spacer()

            Button(project.id.isEmpty ? "Create" : "Save") {
                saveProject()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!hasChanges || isSaving || tempName.isEmpty)
            .opacity((hasChanges && !tempName.isEmpty) ? 1.0 : 0.5)
        }
        .padding(Theme.spacingMedium)
        .padding(.bottom, Theme.spacingLarge)
    }

    private func validateChanges() {
        let projectColor = Color(hex: project.color)
        let projectAbout = project.about ?? ""

        // Compare phases by checking if any phase has changed (name, order, or archived status)
        let phasesChanged = tempPhases.count != project.phases.count ||
            !zip(tempPhases, project.phases.sorted { $0.order < $1.order }).allSatisfy { tempPhase, projectPhase in
                tempPhase.id == projectPhase.id &&
                tempPhase.name == projectPhase.name &&
                tempPhase.order == projectPhase.order &&
                tempPhase.archived == projectPhase.archived
            }

        hasChanges = (
            tempName != project.name ||
            tempEmoji != project.emoji ||
            tempColor != projectColor ||
            tempAbout != projectAbout ||
            phasesChanged ||
            tempIsArchived != project.archived
        )
    }

    private func saveProject() {
        isSaving = true

        // Convert Color to hex string
        let colorHex = tempColor.toHex ?? project.color

        let phases = tempPhases.map { phase in
            Phase(id: phase.id, name: phase.name, order: phase.order, archived: phase.archived)
        }

        if !project.id.isEmpty {
            let removedPhaseIDs = Set(project.phases.map(\.id)).subtracting(Set(phases.map(\.id)))
            if !removedPhaseIDs.isEmpty {
                _ = SessionManager.shared.clearProjectPhaseForSessions(projectID: project.id, phaseIDs: removedPhaseIDs)
            }
        }

        if project.id.isEmpty {
            // Creating new project with all details
            let newProject = projectsViewModel.addProject(
                name: tempName,
                color: colorHex,
                about: tempAbout.isEmpty ? nil : tempAbout,
                phases: phases,
                archived: tempIsArchived
            )

            // Update local project copy
            project = newProject
        } else {
            // Updating existing project
            var updatedProject = Project(
                id: project.id,
                name: tempName,
                color: colorHex,
                about: tempAbout.isEmpty ? nil : tempAbout,
                order: project.order,
                emoji: tempEmoji,
                phases: phases
            )
            updatedProject.archived = tempIsArchived

            projectsViewModel.updateProject(updatedProject)

            // Update local project copy
            project = updatedProject
        }

        hasChanges = false

        // Close sidebar after successful save
        sidebarState.hide()

        isSaving = false
    }
}

// MARK: - View Extension for Card Styling
private extension View {
    /// Applies a consistent card-style container: surface background, rounded corners, subtle shadow
    func cardStyle() -> some View {
        self
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.Design.cornerRadius)
            .shadow(color: Theme.Colors.divider.opacity(0.15), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Drag and Drop Delegate
struct PhaseDropDelegate: DropDelegate {
    let index: Int
    @Binding var phases: [Phase]

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: ["public.text"]).first else {
            return false
        }

        itemProvider.loadDataRepresentation(forTypeIdentifier: "public.text") { data, error in
            DispatchQueue.main.async {
                if let data = data, let sourceIndexString = String(data: data, encoding: .utf8), let sourceIndex = Int(sourceIndexString) {
                    movePhase(from: sourceIndex, to: index)
                }
            }
        }

        return true
    }

    private func movePhase(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex < phases.count,
              destinationIndex < phases.count else { return }

        let phase = phases.remove(at: sourceIndex)
        phases.insert(phase, at: destinationIndex)

        // Update order values
        for (index, phase) in phases.enumerated() {
            var updatedPhase = phase
            updatedPhase.order = index
            phases[index] = updatedPhase
        }
    }
}

    // MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct ProjectSidebarEditView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProject = Project(
            id: UUID().uuidString,
            name: "Sample Project",
            color: "#8E44AD",
            about: "This is a sample project for preview purposes.",
            order: 0,
            emoji: "🎨",
            phases: [
                Phase(name: "Planning", order: 0, archived: false),
                Phase(name: "Development", order: 1, archived: false),
                Phase(name: "Testing", order: 2, archived: false)
            ]
        )

        return ProjectSidebarEditView(project: sampleProject)
            .environmentObject(SidebarStateManager())
            .environmentObject(ProjectsViewModel())
            .frame(width: 420, height: 900)
            .padding()
    }
}
#endif