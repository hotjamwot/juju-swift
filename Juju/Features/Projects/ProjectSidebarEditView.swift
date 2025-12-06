import SwiftUI

/// Sidebar view for editing project details with live preview and enhanced layout
struct ProjectSidebarEditView: View {
    @StateObject private var sidebarState = SidebarStateManager()
    @StateObject private var projectsViewModel = ProjectsViewModel()
    
    @State private var project: Project
    @State private var tempName: String
    @State private var tempEmoji: String
    @State private var tempColor: Color
    @State private var tempAbout: String
    @State private var tempPhases: [String]
    @State private var tempIsArchived: Bool
    
    // Form validation
    @State private var hasChanges = false
    @State private var isSaving = false
    @State private var showingEmojiPicker = false
    
    init(project: Project) {
        self._project = State(initialValue: project)
        self._tempName = State(initialValue: project.name)
        self._tempEmoji = State(initialValue: project.emoji)
        self._tempColor = State(initialValue: Color(hex: project.color))
        self._tempAbout = State(initialValue: project.about ?? "")
        self._tempPhases = State(initialValue: project.phases.map { $0.name })
        self._tempIsArchived = State(initialValue: project.archived)
    }
    
    var body: some View {
        VStack(spacing: Theme.spacingMedium) {
            // Live preview section
            livePreviewSection
            
            // Basic info section
            basicInfoSection
            
            // Color selection section
            colorSelectionSection
            
            // About section
            aboutSection
            
            // Phases section
            phasesSection
            
            // Archive toggle
            archiveSection
            
            // Action buttons
            actionButtons
        }
        .formStyle(.grouped)
        .onChange(of: tempName) { _ in validateChanges() }
        .onChange(of: tempEmoji) { _ in validateChanges() }
        .onChange(of: tempColor) { _ in validateChanges() }
        .onChange(of: tempAbout) { _ in validateChanges() }
        .onChange(of: tempPhases) { _ in validateChanges() }
        .onChange(of: tempIsArchived) { _ in validateChanges() }
    }
    
    private var livePreviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Live Preview")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                HStack {
                    // Project card preview
                    VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                        HStack {
                            Text(tempEmoji)
                                .font(.title2)
                            Text(tempName.isEmpty ? "Project Name" : tempName)
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                        
                        if !tempAbout.isEmpty {
                            Text(tempAbout)
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(3)
                        }
                        
                        // Color indicator
                        HStack {
                            Circle()
                                .fill(tempColor)
                                .frame(width: 12, height: 12)
                            Text("Project Color")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.Colors.divider, lineWidth: 1)
                            )
                    )
                    
                    Spacer()
                }
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var basicInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Basic Info")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                VStack(spacing: Theme.spacingMedium) {
                    // Name field
                    VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                        Text("Project Name")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        TextField("Enter project name", text: $tempName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Emoji selection
                    HStack {
                        Text("Emoji")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Button(action: {
                            showingEmojiPicker.toggle()
                        }) {
                            HStack {
                                Text(tempEmoji)
                                    .font(.title2)
                                Text("Change Emoji")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var colorSelectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Color")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                ColorPicker("Select project color", selection: $tempColor)
                    .labelsHidden()
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var aboutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("About")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                TextEditor(text: $tempAbout)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Theme.Colors.background)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var phasesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Phases")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                VStack(spacing: Theme.spacingSmall) {
                    ForEach(Array(tempPhases.enumerated()), id: \.offset) { index, phase in
                        HStack {
                            TextField("Phase \(index + 1)", text: Binding(
                                get: { phase },
                                set: { newValue in
                                    tempPhases[index] = newValue
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button(action: {
                                tempPhases.remove(at: index)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Button(action: {
                        tempPhases.append("New Phase")
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
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
    }
    
    private var archiveSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text("Archive Project")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                HStack {
                    Toggle("Archive this project", isOn: $tempIsArchived)
                    Spacer()
                    Text(tempIsArchived ? "Archived" : "Active")
                        .font(.caption)
                        .foregroundColor(tempIsArchived ? .red : .green)
                }
            }
            .padding()
        }
        .background(Theme.Colors.surface)
        .cornerRadius(8)
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
        .padding(.horizontal)
    }
    
    private func validateChanges() {
        let projectColor = Color(hex: project.color)
        let projectAbout = project.about ?? ""
        let projectPhases = project.phases.map { $0.name }
        
        hasChanges = (
            tempName != project.name ||
            tempEmoji != project.emoji ||
            tempColor != projectColor ||
            tempAbout != projectAbout ||
            tempPhases != projectPhases ||
            tempIsArchived != project.archived
        )
    }
    
    private func saveProject() {
        isSaving = true
        
        // Convert Color to hex string
        let colorHex = tempColor.toHex ?? project.color
        
        // Convert phases strings to Phase objects
        let phases = tempPhases.map { phaseName in
            // Check if this phase already exists in the project
            if let existingPhase = project.phases.first(where: { $0.name == phaseName }) {
                // Update existing phase
                return Phase(id: existingPhase.id, name: phaseName, archived: existingPhase.archived)
            } else {
                // Create new phase
                return Phase(name: phaseName, archived: false)
            }
        }
        
        // Create updated project
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
        
        // Save using ProjectsViewModel
        if project.id.isEmpty {
            // Creating new project
            projectsViewModel.addProject(
                name: tempName,
                color: colorHex,
                about: tempAbout.isEmpty ? nil : tempAbout
            )
            
            // If the new project is archived, we need to archive it after creation
            if tempIsArchived {
                // Find the newly created project by name and archive it
                if let newProject = projectsViewModel.projects.first(where: { $0.name == tempName && $0.color == colorHex }) {
                    Task {
                        await projectsViewModel.archiveProject(newProject)
                    }
                }
            }
        } else {
            // Updating existing project
            projectsViewModel.updateProject(updatedProject)
        }
        
        // Update local project copy
        project = updatedProject
        hasChanges = false
        
        // Close sidebar after successful save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            sidebarState.hide()
        }
        
        isSaving = false
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
                phases: ["Planning", "Development", "Testing"].map { Phase(name: $0, archived: false) }
            )
            
            return ProjectSidebarEditView(project: sampleProject)
                .environmentObject(SidebarStateManager())
                .environmentObject(ProjectsViewModel())
                .frame(width: 420)
                .padding()
        }
    }
    #endif
