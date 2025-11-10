import SwiftUI
import Charts

struct BubbleChartCardView: View {
    let data: [ProjectChartData]
    @State private var hoveredIndex: Int? = nil
    @State private var packedBubbles: [BubblePosition] = []
    @State private var lastSize: CGSize = .zero

    static let sampleData: [ProjectChartData] = [
        ProjectChartData(projectName: "Work", color: "#4E79A7", totalHours: 120, percentage: 45.0),
        ProjectChartData(projectName: "Personal", color: "#F28E2C", totalHours: 80, percentage: 30.0),
        ProjectChartData(projectName: "Learning", color: "#E15759", totalHours: 40, percentage: 15.0)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            Text("This Year")
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textSecondary)
            
            if data.isEmpty {
                Text("No data for this year")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 300)
            } else {
                GeometryReader { geometry in
                    let minSide = min(geometry.size.width, geometry.size.height)
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    let maxDiameter = minSide * 0.7

                    // Calculate diameters
                    let diameters = data.map { CGFloat($0.totalHours) / CGFloat(maxHours) * maxDiameter }
                    let bubbles = zip(data.indices, diameters).map { BubblePosition(index: $0.0, radius: $0.1 / 2) }

                    ZStack {
                        ForEach(Array(packedBubbles.enumerated()), id: \.offset) { idx, bubble in
                            let bubbleData = data[bubble.index]
                            let diameter = bubble.radius * 2

                            ZStack {
                                Circle()
                                    .fill( Color(hex: bubbleData.color))
                                    .frame(width: diameter, height: diameter)
                                    .scaleEffect(hoveredIndex == idx ? 1.10 : 1)
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

                                    Text("\(bubbleData.totalHours, specifier: "%.1f") h")
                                        .font(.system(size: max(10, diameter * 0.12),
                                                      weight: .semibold,
                                                      design: .rounded))
                                        .foregroundColor(Theme.Colors.textPrimary.opacity(0.9))
                                }
                                .help("""
                                    Project: \(bubbleData.projectName)
                                    Total: \(bubbleData.totalHours) h (\(bubbleData.percentage, specifier: "%.1f") %)
                                    """)
                            }
                            .position(
                                x: geometry.size.width / 2 + bubble.x,
                                y: geometry.size.height / 2 + bubble.y
                            )
                        }
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
        .padding(Theme.spacingMedium)
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

// MARK: - Local model for this view (renamed to avoid conflicts)

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

#Preview {
    BubbleChartCardView(data: [
        ProjectChartData(projectName: "Work", color: "#4E79A7", totalHours: 120, percentage: 45.0),
        ProjectChartData(projectName: "Personal", color: "#F28E2C", totalHours: 80, percentage: 30.0),
        ProjectChartData(projectName: "Learning", color: "#E15759", totalHours: 40, percentage: 15.0),
        ProjectChartData(projectName: "Other", color: "#76B7B2", totalHours: 20, percentage: 7.5),
        ProjectChartData(projectName: "Hobby", color: "#59A14F", totalHours: 60, percentage: 22.5)
    ])
    .frame(width: 800, height: 350)
    .padding()
}
