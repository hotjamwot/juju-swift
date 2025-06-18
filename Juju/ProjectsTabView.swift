import Cocoa

class ProjectsTabView: NSView {
    private let stackView = NSStackView()
    private let projectListStack = NSStackView()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        refresh()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        refresh()
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1.0).cgColor
        translatesAutoresizingMaskIntoConstraints = false
        
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.distribution = .gravityAreas
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        let titleLabel = NSTextField(labelWithString: "📁 Project Management")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        stackView.addArrangedSubview(titleLabel)
        
        let subtitleLabel = NSTextField(labelWithString: "Manage your projects and categories")
        subtitleLabel.font = NSFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = NSColor.lightGray
        subtitleLabel.alignment = .center
        stackView.addArrangedSubview(subtitleLabel)
        
        let topSpacer = NSView()
        topSpacer.translatesAutoresizingMaskIntoConstraints = false
        topSpacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(topSpacer)
        
        // Project List Container
        let projectListContainer = NSView()
        projectListContainer.translatesAutoresizingMaskIntoConstraints = false
        projectListContainer.widthAnchor.constraint(equalToConstant: 480).isActive = true
        projectListContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        stackView.addArrangedSubview(projectListContainer)
        
        // Project List Stack
        projectListStack.orientation = .vertical
        projectListStack.alignment = .leading
        projectListStack.distribution = .fill
        projectListStack.spacing = 10
        projectListStack.translatesAutoresizingMaskIntoConstraints = false
        projectListContainer.addSubview(projectListStack)
        NSLayoutConstraint.activate([
            projectListStack.topAnchor.constraint(equalTo: projectListContainer.topAnchor),
            projectListStack.leadingAnchor.constraint(equalTo: projectListContainer.leadingAnchor),
            projectListStack.trailingAnchor.constraint(equalTo: projectListContainer.trailingAnchor),
            projectListStack.bottomAnchor.constraint(lessThanOrEqualTo: projectListContainer.bottomAnchor)
        ])
        
        let bottomSpacer = NSView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(bottomSpacer)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            projectListContainer.widthAnchor.constraint(equalToConstant: 480)
        ])
    }
    
    public func refresh() {
        projectListStack.arrangedSubviews.forEach { projectListStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        let projects = ProjectManager.shared.loadProjects()
        if projects.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No projects found.")
            emptyLabel.textColor = .lightGray
            emptyLabel.font = NSFont.systemFont(ofSize: 14)
            projectListStack.addArrangedSubview(emptyLabel)
            return
        }
        for (idx, project) in projects.enumerated() {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.alignment = .centerY
            rowStack.distribution = .fill
            rowStack.spacing = 12
            rowStack.translatesAutoresizingMaskIntoConstraints = false

            // Color Well
            let colorWell = NSColorWell()
            colorWell.color = NSColor(hex: project.color) ?? .systemBlue
            colorWell.isEnabled = true
            colorWell.translatesAutoresizingMaskIntoConstraints = false
            colorWell.widthAnchor.constraint(equalToConstant: 32).isActive = true
            colorWell.heightAnchor.constraint(equalToConstant: 20).isActive = true
            rowStack.addArrangedSubview(colorWell)

            // Project Name
            let nameLabel = NSTextField(labelWithString: project.name)
            nameLabel.textColor = .white
            nameLabel.font = NSFont.systemFont(ofSize: 16)
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            rowStack.addArrangedSubview(nameLabel)

            // Delete Button
            let deleteButton = NSButton(title: "Delete", target: nil, action: nil)
            deleteButton.bezelStyle = .rounded
            deleteButton.contentTintColor = .systemRed
            deleteButton.font = NSFont.systemFont(ofSize: 13)
            deleteButton.isEnabled = true
            deleteButton.translatesAutoresizingMaskIntoConstraints = false
            rowStack.addArrangedSubview(deleteButton)

            // Color change handler
            colorWell.target = ClosureSleeve { [weak colorWell, weak self] in
                guard let colorWell = colorWell else { return }
                var updatedProjects = ProjectManager.shared.loadProjects()
                guard idx < updatedProjects.count else { return }
                updatedProjects[idx].color = colorWell.color.hexString
                ProjectManager.shared.saveProjects(updatedProjects)
                self?.refresh()
            }
            colorWell.action = #selector(ClosureSleeve.invoke)

            // Delete handler
            deleteButton.target = ClosureSleeve { [weak self] in
                var updatedProjects = ProjectManager.shared.loadProjects()
                guard idx < updatedProjects.count else { return }
                updatedProjects.remove(at: idx)
                ProjectManager.shared.saveProjects(updatedProjects)
                self?.refresh()
            }
            deleteButton.action = #selector(ClosureSleeve.invoke)

            projectListStack.addArrangedSubview(rowStack)
        }
    }
} 