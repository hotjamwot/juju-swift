import SwiftUI
import Charts

struct BubbleChartCardView: View {
    let data: [ProjectChartData]
    @State private var hoveredIndex: Int? = nil
    
    static let sampleData: [ProjectChartData] = [
        ProjectChartData(projectName: "Work", color: "#4E79A7", totalHours: 120, percentage: 45.0),
        ProjectChartData(projectName: "Personal", color: "#F28E2C", totalHours: 80, percentage: 30.0),
        ProjectChartData(projectName: "Learning", color: "#E15759", totalHours: 40, percentage: 15.0)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            Text("This Year in Bubbles")
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textSecondary)
            
            if data.isEmpty {
                Text("No data for this year")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 240)
            } else {
                GeometryReader { geometry in
                    let size = min(geometry.size.width, geometry.size.height)
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    let maxDiameter = size * 0.45
                    let diameters = data.map { CGFloat($0.totalHours) / CGFloat(maxHours) * maxDiameter }
                    let circleRadius = (size / 2) - (maxDiameter / 2)
                    
                    ZStack {
                        ForEach(Array(data.enumerated()), id: \.offset) { idx, bubble in
                            let diameter = diameters[idx]
                            let angle = Double(idx) / Double(data.count) * 2 * .pi
                            let xOffset = CGFloat(cos(angle)) * circleRadius
                            let yOffset = CGFloat(sin(angle)) * circleRadius
                            
                            ZStack {
                                Circle()
                                    .fill(Color(hex: bubble.color))
                                    .frame(width: diameter, height: diameter)
                                    .scaleEffect(hoveredIndex == idx ? 1.10 : 1)
                                    .animation(.easeInOut(duration: Theme.Design.animationDuration),
                                               value: hoveredIndex)
                                    .onHover { hovering in
                                        hoveredIndex = hovering ? idx : nil
                                    }
                                VStack(spacing: 1) {
                                    Text(bubble.projectName)
                                        .font(.system(size: max(10, diameter * 0.15),
                                                      weight: .medium,
                                                      design: .rounded))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .padding(.horizontal, 4)
                                    Text("\(bubble.totalHours, specifier: "%.1f") h")
                                        .font(.system(size: max(8, diameter * 0.08),
                                                      weight: .semibold,
                                                      design: .rounded))
                                        .foregroundColor(Theme.Colors.textPrimary.opacity(0.9))
                                }
                            }
                            .offset(x: xOffset, y: yOffset)
                            .help("""
                                Project: \(bubble.projectName)
                                Total: \(bubble.totalHours) h (\(bubble.percentage, specifier: "%.1f") %)
                                """)
                        }
                    }
                    .frame(width: geometry.size.width,
                           height: geometry.size.height,
                           alignment: .center)
                }
                .frame(height: 240)
            }
        }
        .padding(Theme.spacingMedium)
    }
}

#Preview {
    BubbleChartCardView(data: BubbleChartCardView.sampleData)
        .frame(width: 800, height: 300)
        .padding()
}
