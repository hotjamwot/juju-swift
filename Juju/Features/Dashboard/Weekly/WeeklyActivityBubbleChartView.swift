import SwiftUI

/// Displays a bubble-style chart showing activity totals for the current week.
struct WeeklyActivityBubbleChartView: View {
    let data: [ActivityChartData]
    @State private var hoveredIndex: Int? = nil

    static let sampleData: [ActivityChartData] = [
        ActivityChartData(activityName: "Writing", emoji: "✍️", totalHours: 8.0, percentage: 40.0),
        ActivityChartData(activityName: "Editing", emoji: "✂️", totalHours: 4.0, percentage: 20.0),
        ActivityChartData(activityName: "Planning", emoji: "🧠", totalHours: 6.0, percentage: 30.0),
        ActivityChartData(activityName: "Admin", emoji: "🗂️", totalHours: 2.0, percentage: 10.0)
    ]

    var body: some View {
        VStack(alignment: .center, spacing: Theme.spacingSmall) {
            if data.isEmpty {
                Text("No sessions this week")
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding(.horizontal)
            } else {
                GeometryReader { geometry in
                    // Calculate available height for bubbles (subtract padding and label area)
                    let bubbleAreaHeight = geometry.size.height - Theme.spacingLarge * 2 - 80 // Padding + label area
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    let maxDiameter = min(bubbleAreaHeight * 0.7, 140) // Use 70% of bubble area height, max 140px
                    
                    // Calculate diameters based on total hours
                    let diameters = data.map { CGFloat($0.totalHours) / CGFloat(maxHours) * maxDiameter }
                    
                    // Calculate total width needed for all bubbles with generous spacing
                    let totalSpacing = CGFloat(data.count - 1) * Theme.spacingExtraLarge
                    let totalWidth = diameters.reduce(0, +) + totalSpacing
                    
                    // Calculate starting X position to center the layout
                    let startX = max(0, (geometry.size.width - totalWidth) / 2)
                    
                    // Create horizontal layout positions with proper vertical centering
                    let bubblePositions = computeHorizontalLayout(
                        diameters: diameters,
                        startX: startX,
                        centerY: geometry.size.height / 2 - 20 // Slightly lower for better visual balance
                    )
                    
                    ZStack {
                        // Bubbles
                        ForEach(Array(bubblePositions.enumerated()), id: \.offset) { idx, position in
                            let bubbleData = data[position.index]
                            let diameter = position.diameter
                            
                            Circle()
                                .fill(Theme.Colors.accentColor.opacity(0.7))
                                .frame(width: diameter, height: diameter)
                                .overlay(
                                    Text(bubbleData.emoji)
                                        .font(.system(size: max(18, diameter * 0.60), design: .rounded))
                                )
                                .scaleEffect(hoveredIndex == idx ? 1.05 : 1)
                                .animation(.easeInOut(duration: Theme.Design.animationDuration),
                                           value: hoveredIndex)
                                .onHover { hovering in
                                    hoveredIndex = hovering ? idx : nil
                                }
                                .help("""
                                    Activity: \(bubbleData.activityName)
                                    Total: \(bubbleData.totalHours) h (\(bubbleData.percentage, specifier: "%.1f") %)
                                    """)
                                .position(x: position.x, y: position.y)
                        }
                        
                        // Labels aligned at the bottom with better spacing
                        VStack {
                            Spacer() // Push labels to bottom
                            
                            HStack(spacing: Theme.spacingExtraLarge) {
                                ForEach(Array(bubblePositions.enumerated()), id: \.offset) { _, position in
                                    let bubbleData = data[position.index]
                                    
                                    VStack(spacing: 6) {
                                        Text(bubbleData.activityName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                        
                                        Text("\(bubbleData.totalHours, specifier: "%.1f") h")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Theme.Colors.textPrimary.opacity(0.9))
                                    }
                                    .frame(width: position.diameter)
                                }
                            }
                            .padding(.bottom, Theme.spacingSmall)
                        }
                    }
                }
                .frame(maxHeight: .infinity) // Allow flexible height to adapt to available space
            }
        }
        .padding(Theme.spacingLarge) // Increased padding inside the pane
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    // MARK: - Layout computation

    /// Computes horizontal layout positions for bubbles in a line
    private func computeHorizontalLayout(diameters: [CGFloat], startX: CGFloat, centerY: CGFloat) -> [BubblePositionData] {
        var positions: [BubblePositionData] = []
        var currentX = startX
        
        for (index, diameter) in diameters.enumerated() {
            positions.append(BubblePositionData(
                index: index,
                diameter: diameter,
                x: currentX + diameter / 2,
                y: centerY
            ))
            currentX += diameter + Theme.spacingExtraLarge
        }
        
        return positions
    }
}

// MARK: - Bubble position model for horizontal layout

fileprivate struct BubblePositionData {
    var index: Int
    var diameter: CGFloat
    var x: CGFloat
    var y: CGFloat
}

// MARK: - Preview
#Preview {
    return WeeklyActivityBubbleChartView_PreviewsContent()
        .frame(width: 600, height: 300)
        .background(Color(NSColor.windowBackgroundColor))
        .padding()
}

struct WeeklyActivityBubbleChartView_PreviewsContent: View {
    @StateObject var chartDataPreparer = ChartDataPreparer()
    @StateObject var sessionManager = SessionManager.shared
    @StateObject var projectsViewModel = ProjectsViewModel.shared
    
    var body: some View {
        WeeklyActivityBubbleChartView(
            data: chartDataPreparer.weeklyActivityTotals()
        )
        .onAppear {
            // Load data just like DashboardNativeSwiftChartsView does
            Task {
                await projectsViewModel.loadProjects()
                await sessionManager.loadAllSessions()
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: sessionManager.allSessions.count) { _ in
            // Update chart data when session data changes
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: projectsViewModel.projects.count) { _ in
            // Update chart data when project data changes
            Task {
                chartDataPreparer.prepareAllTimeData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
    }
}
