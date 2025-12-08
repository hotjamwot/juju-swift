import SwiftUI

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
    
    // Form validation
    @State private var hasChanges = false
    @State private var isSaving = false
    @State private var showingEmojiPicker = false
    @State private var showingColorPicker = false
    
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
        VStack(spacing: Theme.spacingExtraLarge) {
            // Top section - name, emoji, color, description, and phases
            VStack(spacing: Theme.spacingExtraLarge) {
                // Combined basic info section (name, emoji, color, description)
                basicInfoSection
                
                // Phases section
                phasesSection
            }
            
            Spacer()
            
            // Bottom section - archive toggle and action buttons
            VStack(spacing: Theme.spacingExtraLarge) {
                // Archive toggle (standalone)
                archiveSection
                
                // Sticky action buttons at bottom
                actionButtons
            }
        }
        .padding(Theme.spacingLarge)
        .onChange(of: tempName) { _ in validateChanges() }
        .onChange(of: tempEmoji) { _ in validateChanges() }
        .onChange(of: tempColor) { _ in validateChanges() }
        .onChange(of: tempAbout) { _ in validateChanges() }
        .onChange(of: tempPhases) { _ in validateChanges() }
        .onChange(of: tempIsArchived) { _ in validateChanges() }
    }
    
    private var basicInfoSection: some View {
        VStack(spacing: Theme.spacingLarge) {
            // Project Name - label on left, field on right
            HStack {
                Text("Name")
                    .font(.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 80, alignment: .leading)
                TextField("", text: $tempName)
                    .textFieldStyle(.plain)
                    .padding(Theme.spacingSmall)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .frame(maxWidth: .infinity)
            }
            
            // Emoji and Color on same row
            HStack(spacing: Theme.spacingLarge) {
                // Emoji selection
                Button(action: {
                    showingEmojiPicker = true
                }) {
                    Text(tempEmoji)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingEmojiPicker) {
                    EmojiPickerView(selectedEmoji: $tempEmoji)
                }
                
                Spacer()
                
                // Color selection
                Button(action: {
                    showingColorPicker = true
                }) {
                    Circle()
                        .fill(tempColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Theme.Colors.divider, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingColorPicker) {
                    ColorPicker("Choose Color", selection: $tempColor)
                        .padding()
                }
            }
            
            // Description
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Description")
                    .font(.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                TextEditor(text: $tempAbout)
                    .frame(minHeight: 100)
                    .textFieldStyle(.plain)
                    .padding(Theme.spacingSmall)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
    }
    
    private var phasesSection: some View {
        VStack(spacing: Theme.spacingLarge) {
            ForEach(tempPhases.indices, id: \.self) { index in
                HStack(spacing: Theme.spacingSmall) {
                    // Drag handle
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
                    .padding(Theme.spacingSmall)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .frame(maxWidth: .infinity)
                    
                    Button(action: {
                        tempPhases.remove(at: index)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
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
        .padding(Theme.spacingMedium)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
    }
    
    private var archiveSection: some View {
        HStack {
            Toggle("", isOn: $tempIsArchived)
            Spacer()
            Text(tempIsArchived ? "Archived" : "Active")
                .font(.caption)
                .foregroundColor(tempIsArchived ? .red : .green)
        }
        .padding(Theme.spacingMedium)
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
        
        // Use the tempPhases directly (they already have proper order values)
        let phases = tempPhases.map { phase in
            // Check if this phase already exists in the project
            if let existingPhase = project.phases.first(where: { $0.id == phase.id }) {
                // Update existing phase (keep the ID and archived status)
                return Phase(id: existingPhase.id, name: phase.name, order: phase.order, archived: existingPhase.archived)
            } else {
                // Create new phase (it already has the correct order)
                return Phase(id: phase.id, name: phase.name, order: phase.order, archived: phase.archived)
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
