import SwiftUI

/// Displays a bubble-style chart showing project totals for the current week.
struct WeeklyProjectBubbleChartView: View {
    let data: [ProjectChartData]
    @State private var hoveredIndex: Int? = nil
    @State private var packedBubbles: [BubblePosition] = []
    @State private var lastSize: CGSize = .zero

    static let sampleData: [ProjectChartData] = [
        ProjectChartData(projectName: "Work", color: "#4E79A7", totalHours: 8.0, percentage: 40.0),
        ProjectChartData(projectName: "Personal", color: "#F28E2C", totalHours: 4.0, percentage: 20.0),
        ProjectChartData(projectName: "Learning", color: "#E15759", totalHours: 6.0, percentage: 30.0),
        ProjectChartData(projectName: "Other", color: "#76B7B2", totalHours: 2.0, percentage: 10.0)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            if data.isEmpty {
                Text("No sessions this week")
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .shadow(radius: 2)
                    .padding(.horizontal)
            } else {
                GeometryReader { geometry in
                    let minSide = min(geometry.size.width, geometry.size.height)
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    let maxDiameter = minSide * 0.5

                    // Calculate diameters
                    let diameters = data.map { CGFloat($0.totalHours) / CGFloat(maxHours) * maxDiameter }
                    let bubbles = zip(data.indices, diameters).map { BubblePosition(index: $0.0, radius: $0.1 / 2) }

                    ZStack {
                        ForEach(Array(packedBubbles.enumerated()), id: \.offset) { idx, bubble in
                            let bubbleData = data[bubble.index]
                            let diameter = bubble.radius * 2

                            ZStack {
                                Circle()
                                    .fill(Color(hex: bubbleData.color))
                                    .frame(width: diameter, height: diameter)
                                    .scaleEffect(hoveredIndex == idx ? 1.05 : 1)
                                    .animation(.easeInOut(duration: Theme.Design.animationDuration),
                                               value: hoveredIndex)
                                    .onHover { hovering in
                                        hoveredIndex = hovering ? idx : nil
                                    }

                                VStack(spacing: 1) {
                                    Text(bubbleData.projectName)
                                        .font(.system(size: max(12, diameter * 0.22),
                                                      weight: .medium,
                                                      design: .rounded))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .padding(.horizontal, 4)

                                    Text("\(bubbleData.totalHours, specifier: "%.1f") h")
                                        .font(.system(size: max(10, diameter * 0.12),
                                                      weight: .semibold,
                                                      design: .rounded))
                                        .foregroundColor(Theme.Colors.textPrimary.opacity(0.9))
                                }
                                .help("""
                                    Project: \(bubbleData.projectName)
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
                .frame(height: 200)
            }
        }
        .padding(.vertical, Theme.spacingExtraSmall)
    }

    // MARK: - Layout computation

    private func computePackedLayout(in size: CGSize, bubbles: [BubblePosition]) {
        lastSize = size
        // Run off-main thread to keep UI snappy
        DispatchQueue.global(qos: .userInitiated).async {
            let packed = PackedCircleLayout.pack(bubbles: bubbles,
                                                 in: size,
                                                 padding: Theme.spacingExtraSmall)
            DispatchQueue.main.async {
                self.packedBubbles = packed
            }
        }
    }
}

// MARK: - Local model for this view (renamed to avoid conflicts)

struct BubbleProjectData {
    var projectName: String
    var color: String
    var totalHours: Double
    var percentage: Double
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

        // Random start positions near centre
        for i in 0..<result.count {
            result[i].x = CGFloat.random(in: -size.width/8...size.width/8)
            result[i].y = CGFloat.random(in: -size.height/8...size.height/8)
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
    WeeklyProjectBubbleChartView(data: WeeklyProjectBubbleChartView.sampleData)
        .frame(width: 400, height: 300)
        .padding()
}
