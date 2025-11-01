import SwiftUI

/// Displays a bubble-style chart showing project totals for the current week.
struct WeeklyProjectBubbleChartView: View {
    let data: [ProjectChartData]
    @State private var hoveredIndex: Int? = nil

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
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Design.cornerRadius)
                    .shadow(radius: 2)
                    .padding(.horizontal)
            } else {
                GeometryReader { geometry in
                    let maxSize = min(geometry.size.width, geometry.size.height)
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    let maxDiameter = maxSize * 0.8
                    let bubbleDiameters = data.map { CGFloat($0.totalHours) / CGFloat(maxHours) * maxDiameter }
                    let totalBubbleWidth = bubbleDiameters.reduce(0, +)
                    let numberOfBubbles = data.count
                    let spacing: CGFloat = numberOfBubbles > 0 ? (geometry.size.width - totalBubbleWidth) / CGFloat(numberOfBubbles + 1) : 0
                    
                    HStack(spacing: max(0, spacing)) {
                        ForEach(Array(data.enumerated()), id: \.offset) { index, bubble in
                            let diameter = bubbleDiameters[index]
                            
                            Circle()
                                .fill(Color(hex: bubble.color))
                                .frame(width: diameter, height: diameter)
                                .scaleEffect(hoveredIndex == index ? 1.10 : 1)
                                .animation(.easeInOut(duration: Theme.Design.animationDuration),
                                           value: hoveredIndex)
                                .onHover { hovering in
                                    hoveredIndex = hovering ? index : nil
                                }
                            // ---- Text overlay ------------------------------------
                            .overlay(
                                VStack(spacing: 1) {
                                    Text(bubble.projectName)
                                        .font(.system(size:
                                                      max(10,
                                                          diameter * 0.15),
                                                  weight: .medium,
                                                  design: .rounded))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .padding(.horizontal, 4)
                                    Text("\(bubble.totalHours, specifier: "%.1f") h")
                                        .font(.system(size:
                                                      max(8,
                                                          diameter * 0.08),
                                                  weight: .semibold,
                                                  design: .rounded))
                                        .foregroundColor(Theme.Colors.textPrimary.opacity(0.9))
                                }
                            )
                            .help("""
                                Project: \(bubble.projectName)
                                Total: \(bubble.totalHours) h (\(bubble.percentage, specifier: "%.1f") %)
                                """)
                    }
                }                    .frame(width: geometry.size.width, height: maxSize, alignment: .center)
                }
                .frame(height: 160)
            }
        }
        .padding(.vertical, Theme.spacingExtraSmall)

    }
}

#Preview {
    WeeklyProjectBubbleChartView(data: WeeklyProjectBubbleChartView.sampleData)
        .frame(width: 400, height: 200)
        .padding()
}
