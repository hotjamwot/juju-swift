import SwiftUI

/// Displays a bubble-style chart showing activity totals for the current week.
struct WeeklyActivityBubbleChartView: View {
    let data: [ActivityChartData]
    @State private var hoveredIndex: Int? = nil
    @State private var packedBubbles: [BubblePosition] = []
    @State private var lastSize: CGSize = .zero

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
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .background(Theme.Colors.surface.opacity(0.5))
                    .cornerRadius(Theme.Design.cornerRadius)
                    .shadow(radius: 2)
                    .padding(.horizontal)
            } else {
                GeometryReader { geometry in
                    let minSide = min(geometry.size.width, geometry.size.height)
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    let maxDiameter = minSide * 0.45

                    // Calculate diameters
                    let diameters = data.map { CGFloat($0.totalHours) / CGFloat(maxHours) * maxDiameter }
                    let bubbles = zip(data.indices, diameters).map { BubblePosition(index: $0.0, radius: $0.1 / 2) }

                    ZStack {
                        ForEach(Array(packedBubbles.enumerated()), id: \.offset) { idx, bubble in
                            let bubbleData = data[bubble.index]
                            let diameter = bubble.radius * 2

                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.accentColor.opacity(0.7))
                                    .frame(width: diameter, height: diameter)
                                    .scaleEffect(hoveredIndex == idx ? 1.05 : 1)
                                    .animation(.easeInOut(duration: Theme.Design.animationDuration),
                                               value: hoveredIndex)
                                    .onHover { hovering in
                                        hoveredIndex = hovering ? idx : nil
                                    }

                                VStack(spacing: 1) {
                                    Text(bubbleData.emoji)
                                        .font(.system(size: max(10, diameter * 0.18), design: .rounded))
                                    
                                    Text(bubbleData.activityName)
                                        .font(.system(size: max(12, diameter * 0.20),
                                                  weight: .medium,
                                                  design: .rounded))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(1)
                                    
                                    Text("\(bubbleData.totalHours, specifier: "%.1f") h")
                                        .font(.system(size: max(10, diameter * 0.12),
                                                  weight: .semibold,
                                                  design: .rounded))
                                        .foregroundColor(Theme.Colors.textPrimary.opacity(0.9))
                                }
                                .help("""
                                    Activity: \(bubbleData.activityName)
                                    Total: \(bubbleData.totalHours) h (\(bubbleData.percentage, specifier: "%.1f") %)
                                    """)
                            }
                            .position(
                                x: geometry.size.width / 2 + bubble.x,
                                y: geometry.size.height / 2 + bubble.y
                            )                        }
                    }
                    .onAppear {
                        computePackedLayout(in: geometry.size, bubbles: bubbles)
                    }
                    .onChange(of: geometry.size) { newSize in
                        if newSize != lastSize {
                            computePackedLayout(in: newSize, bubbles: bubbles)
                        }
                    }
                }
            }
        }
        .padding(.vertical, Theme.spacingExtraSmall)
    }

    // MARK: - Layout computation

    private func computePackedLayout(in size: CGSize, bubbles: [BubblePosition]) {
        lastSize = size
        // Run off-main thread to keep UI snappy
        DispatchQueue.global(qos: .userInitiated).async {
            // Find the index of the largest bubble (highest radius)
            let largestIndex = bubbles.indices.max { bubbles[$0].radius < bubbles[$1].radius } ?? 0
            
            // Create a copy of bubbles to modify
            var mutableBubbles = bubbles
            
            // Move the largest bubble to the front so it gets positioned in the center
            if largestIndex != 0 {
                let largestBubble = mutableBubbles[largestIndex]
                mutableBubbles.remove(at: largestIndex)
                mutableBubbles.insert(largestBubble, at: 0)
            }
            
            let packed = PackedCircleLayout.pack(bubbles: mutableBubbles,
                                                 in: size,
                                                 padding: Theme.spacingExtraSmall)
            DispatchQueue.main.async {
                self.packedBubbles = packed
            }
        }
    }
}


// MARK: - Bubble position model

fileprivate struct BubblePosition {
    var index: Int
    var radius: CGFloat
    var x: CGFloat = 0
    var y: CGFloat = 0
}

// MARK: - Packed circle layout solver

fileprivate struct PackedCircleLayout {
    static func pack(bubbles: [BubblePosition], in size: CGSize, padding: CGFloat) -> [BubblePosition] {
        var result = bubbles
        let maxIterations = 200
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)

        // Set first bubble (largest) to be at the center
        if !result.isEmpty {
            result[0].x = 0
            result[0].y = 0
        }
        
        // Set random start positions for other bubbles near the center
        for i in 1..<result.count {
            result[i].x = CGFloat.random(in: -size.width/12...size.width/12)
            result[i].y = CGFloat.random(in: -size.height/12...size.height/12)
        }

        // Iteratively push apart overlapping bubbles
        for _ in 0..<maxIterations {
            var moved = false
            for i in 0..<result.count {
                for j in i+1..<result.count {
                    let dx = result[j].x - result[i].x
                    let dy = result[j].y - result[i].y
                    let dist = sqrt(dx*dx + dy*dy)
                    let minDist = result[i].radius + result[j].radius + padding

                    if dist < minDist && dist > 0 {
                        let overlap = (minDist - dist) / 2
                        let nx = dx / dist
                        let ny = dy / dist
                        result[i].x -= nx * overlap
                        result[i].y -= ny * overlap
                        result[j].x += nx * overlap
                        result[j].y += ny * overlap
                        moved = true
                    }
                }
            }
            if !moved { break }
        }

        return result
    }
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
