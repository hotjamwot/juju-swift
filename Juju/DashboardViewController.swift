import Cocoa

class DashboardViewController: NSViewController {
    
    var tabView: NSTabView!
    
    // Session table properties
    private var sessionTableView: NSTableView?
    private var sessionDataSource: SessionTableDataSource?
    private var prevButton: NSButton?
    private var nextButton: NSButton?
    private var pageLabel: NSTextField?
    
    override func loadView() {
        print("🔍 Dashboard: loadView called")
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1.0).cgColor
        
        // Create tab view
        tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.wantsLayer = true
        tabView.layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1.0).cgColor
        view.addSubview(tabView)
        
        // Create tabs
        print("🔍 Dashboard: Creating tabs...")
        let graphsTab = createGraphsTab()
        let sessionsTab = createSessionsTab()
        let projectsTab = createProjectsTab()
        
        // Add tabs to tab view
        tabView.addTabViewItem(graphsTab)
        tabView.addTabViewItem(sessionsTab)
        tabView.addTabViewItem(projectsTab)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        print("🔍 Dashboard: loadView completed")
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // No longer need to make this first responder since we have proper window controls
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔍 Dashboard: viewDidLoad called")
        // UI is already set up in loadView()
        // Sessions will be loaded when the sessions tab is created
    }
    
    func createGraphsTab() -> NSTabViewItem {
        let tabItem = NSTabViewItem()
        tabItem.label = "Graphs"
        
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1.0).cgColor
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.distribution = .fill
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        let titleLabel = NSTextField(labelWithString: "📊 Charts & Analytics")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        stackView.addArrangedSubview(titleLabel)
        
        let subtitleLabel = NSTextField(labelWithString: "Visualize your productivity data")
        subtitleLabel.font = NSFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = NSColor.lightGray
        subtitleLabel.alignment = .center
        stackView.addArrangedSubview(subtitleLabel)
        
        let placeholderLabel = NSTextField(labelWithString: "Charts and analytics will be displayed here")
        placeholderLabel.font = NSFont.systemFont(ofSize: 16)
        placeholderLabel.textColor = NSColor.lightGray
        placeholderLabel.alignment = .center
        stackView.addArrangedSubview(placeholderLabel)
        
        // Placeholder grid
        let gridView = NSGridView(views: [
            [createPlaceholderBox(title: "Chart 1", color: .systemBlue), createPlaceholderBox(title: "Chart 2", color: .systemGreen)],
            [createPlaceholderBox(title: "Chart 3", color: .systemOrange), createPlaceholderBox(title: "Chart 4", color: .systemPurple)]
        ])
        gridView.rowSpacing = 20
        gridView.columnSpacing = 20
        gridView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(gridView)
        
        // Constrain grid height
        gridView.heightAnchor.constraint(equalToConstant: 400).isActive = true
        
        // Layout constraints
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20)
        ])
        
        tabItem.view = container
        return tabItem
    }
    
    private func createSessionsTab() -> NSTabViewItem {
        print("🔍 Dashboard: Creating sessions tab...")
        let tabViewItem = NSTabViewItem()
        tabViewItem.label = "Sessions"
        
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1.0).cgColor
        
        // Create table view
        let tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = 28
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1.0)
        tableView.gridStyleMask = []
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.focusRingType = .none
        tableView.selectionHighlightStyle = .regular
        
        // Create columns
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Date"))
        dateColumn.title = "Date"
        dateColumn.width = 100
        tableView.addTableColumn(dateColumn)
        
        let projectColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Project"))
        projectColumn.title = "Project"
        projectColumn.width = 150
        tableView.addTableColumn(projectColumn)
        
        let durationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Duration"))
        durationColumn.title = "Duration"
        durationColumn.width = 80
        tableView.addTableColumn(durationColumn)
        
        let notesColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Notes"))
        notesColumn.title = "Notes"
        notesColumn.width = 200
        tableView.addTableColumn(notesColumn)
        
        // Create scroll view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = tableView
        scrollView.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1.0)
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        
        // Create pagination controls
        let paginationStack = NSStackView()
        paginationStack.orientation = .horizontal
        paginationStack.alignment = .centerY
        paginationStack.distribution = .equalCentering
        paginationStack.spacing = 16
        paginationStack.translatesAutoresizingMaskIntoConstraints = false
        
        let prevButton = NSButton(title: "Previous", target: nil, action: nil)
        prevButton.bezelStyle = .texturedRounded
        prevButton.contentTintColor = .white
        prevButton.translatesAutoresizingMaskIntoConstraints = false
        
        let pageLabel = NSTextField(labelWithString: "Page 1")
        pageLabel.alignment = .center
        pageLabel.textColor = .white
        pageLabel.backgroundColor = .clear
        pageLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let nextButton = NSButton(title: "Next", target: nil, action: nil)
        nextButton.bezelStyle = .texturedRounded
        nextButton.contentTintColor = .white
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        
        paginationStack.addArrangedSubview(prevButton)
        paginationStack.addArrangedSubview(pageLabel)
        paginationStack.addArrangedSubview(nextButton)
        
        // Add to container
        containerView.addSubview(scrollView)
        containerView.addSubview(paginationStack)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: paginationStack.topAnchor, constant: -20),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            
            paginationStack.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            paginationStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            paginationStack.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Ensure table header is visible
        tableView.headerView = NSTableHeaderView(frame: NSRect(x: 0, y: 0, width: 0, height: 28))
        
        // Load session data asynchronously to prevent freezing
        DispatchQueue.global(qos: .userInitiated).async {
            print("🔍 Dashboard: Loading sessions in background...")
            let allSessionRecords = SessionManager.shared.loadAllSessions()
            print("🔍 Dashboard: Loaded \(allSessionRecords.count) sessions in background")
            
            DispatchQueue.main.async {
                print("🔍 Dashboard: Setting up table data source...")
                let sortedSessions = allSessionRecords.sorted { $0.date > $1.date }
                let dataSource = SessionTableDataSource(sessions: sortedSessions, pageSize: 20)
                
                // Store references
                self.sessionTableView = tableView
                self.sessionDataSource = dataSource
                self.prevButton = prevButton
                self.nextButton = nextButton
                self.pageLabel = pageLabel
                
                // Set up table
                tableView.dataSource = dataSource
                tableView.delegate = dataSource
                tableView.reloadData()
                
                // Set up pagination
                prevButton.target = dataSource
                prevButton.action = #selector(dataSource.previousPage)
                nextButton.target = dataSource
                nextButton.action = #selector(dataSource.nextPage)
                
                // Update pagination state
                dataSource.pageInfoLabel = pageLabel
                dataSource.prevButton = prevButton
                dataSource.nextButton = nextButton
                dataSource.tableView = tableView
                dataSource.updatePaginationControls()
                
                print("🔍 Dashboard: Table setup complete")
            }
        }
        
        tabViewItem.view = containerView
        return tabViewItem
    }
    
    func createProjectsTab() -> NSTabViewItem {
        let tabItem = NSTabViewItem()
        tabItem.label = "Projects"
        
        let projectsTabView = ProjectsTabView()
        tabItem.view = projectsTabView
        return tabItem
    }
    
    func createPlaceholderChart(title: String, color: NSColor) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = color.withAlphaComponent(0.1).cgColor
        container.layer?.borderColor = color.cgColor
        container.layer?.borderWidth = 2
        container.layer?.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = color
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let placeholderLabel = NSTextField(labelWithString: "Chart placeholder")
        placeholderLabel.font = NSFont.systemFont(ofSize: 12)
        placeholderLabel.textColor = NSColor.secondaryLabelColor
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(placeholderLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 15),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            placeholderLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }
    
    func createPlaceholderBox(title: String, color: NSColor) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = color.withAlphaComponent(0.1).cgColor
        container.layer?.borderColor = color.cgColor
        container.layer?.borderWidth = 2
        container.layer?.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = color
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let placeholderLabel = NSTextField(labelWithString: "Content placeholder")
        placeholderLabel.font = NSFont.systemFont(ofSize: 12)
        placeholderLabel.textColor = NSColor.secondaryLabelColor
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(placeholderLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 15),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            placeholderLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }
}

// --- Table Data Source ---
class SessionTableDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let sessions: [SessionRecord]
    let pageSize: Int
    var visibleSessions: [SessionRecord]
    var totalPages: Int
    var currentPage: Int = 1
    
    var pageInfoLabel: NSTextField?
    var prevButton: NSButton?
    var nextButton: NSButton?
    var tableView: NSTableView?
    
    init(sessions: [SessionRecord], pageSize: Int) {
        self.sessions = sessions
        self.pageSize = pageSize
        self.visibleSessions = Array(sessions.prefix(pageSize))
        self.totalPages = (sessions.count + pageSize - 1) / pageSize
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        print("🔍 Table: numberOfRows called, returning \(visibleSessions.count)")
        return visibleSessions.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        print("🔍 Table: viewFor called for row \(row), column \(tableColumn?.identifier.rawValue ?? "nil")")
        guard row < visibleSessions.count, let tableColumn = tableColumn else { 
            print("🔍 Table: Returning nil for row \(row)")
            return nil 
        }
        let session = visibleSessions[row]
        let text: String
        switch tableColumn.identifier.rawValue {
        case "Date": text = session.date
        case "Project": text = session.projectName
        case "Duration": text = formatMinutesToHoursMinutes(session.durationMinutes)
        case "Notes": text = session.notes
        default: text = ""
        }
        
        let cell = NSTextField(labelWithString: text)
        cell.lineBreakMode = .byTruncatingTail
        cell.font = NSFont.systemFont(ofSize: 13)
        cell.textColor = .white
        cell.backgroundColor = .clear
        cell.isEditable = false
        cell.isSelectable = false
        cell.isBordered = false
        cell.drawsBackground = false
        print("🔍 Table: Created cell with text: '\(text)' for row \(row)")
        return cell
    }
    
    private func formatMinutesToHoursMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%dh %02dm", h, m)
    }
    
    @objc func previousPage() {
        if currentPage > 1 {
            currentPage -= 1
            updateVisibleSessions()
        }
    }
    
    @objc func nextPage() {
        if currentPage < totalPages {
            currentPage += 1
            updateVisibleSessions()
        }
    }
    
    private func updateVisibleSessions() {
        guard let tableView = tableView else { return }
        let startIndex = (currentPage - 1) * pageSize
        let endIndex = min(startIndex + pageSize, sessions.count)
        visibleSessions = Array(sessions[startIndex..<endIndex])
        tableView.reloadData()
        
        // Update UI elements
        if let pageInfoLabel = pageInfoLabel {
            pageInfoLabel.stringValue = "Page \(currentPage) of \(totalPages)"
        }
        
        if let prevButton = prevButton {
            prevButton.isEnabled = currentPage > 1
        }
        
        if let nextButton = nextButton {
            nextButton.isEnabled = currentPage < totalPages
        }
    }
    
    func updatePaginationControls() {
        guard let pageInfoLabel = pageInfoLabel, let prevButton = prevButton, let nextButton = nextButton else { return }
        
        pageInfoLabel.stringValue = "Page \(currentPage) of \(totalPages)"
        prevButton.isEnabled = currentPage > 1
        nextButton.isEnabled = currentPage < totalPages
    }
}

// MARK: - NSColor <-> Hex helpers and ClosureSleeve for button/colorWell actions

import AppKit

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexSanitized.hasPrefix("#") { hexSanitized.removeFirst() }
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
    var hexString: String {
        guard let rgbColor = usingColorSpace(.deviceRGB) else { return "#000000" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

class ClosureSleeve: NSObject {
    let closure: () -> Void
    init(_ closure: @escaping () -> Void) { self.closure = closure }
    @objc func invoke() { closure() }
} 