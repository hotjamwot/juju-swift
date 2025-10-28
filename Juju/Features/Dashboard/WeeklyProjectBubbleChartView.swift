import SwiftUI

/// Displays a bubble-style chart showing project totals for the current week.
struct WeeklyProjectBubbleChartView: View {
    @ObservedObject var chartDataPreparer: ChartDataPreparer

    var body: some View {
        let data = chartDataPreparer.weeklyProjectTotals()

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
                    let maxSize = min(geometry.size.width - 40, geometry.size.height)
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    let bubbleSpacing: CGFloat = Theme.spacingSmall
                    let maxDiameter = maxSize * 0.8
                    let bubbleDiameters = data.map { CGFloat($0.totalHours) / CGFloat(maxHours) * maxDiameter }
                    
                    HStack(spacing: bubbleSpacing) {
                        ForEach(Array(data.enumerated()), id: \.offset) { index, bubble in
                            let diameter = bubbleDiameters[index]
                            
                            Circle()
                                .fill(Color(hex: bubble.color))
                                .frame(width: diameter, height: diameter)
                                .overlay(
                                    Text(bubble.projectName)
                                        .font(.system(size: max(10, diameter * 0.15), weight: .medium))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .padding(.horizontal, 4)
                                )
                                .help("Project: \(bubble.projectName)\nTotal: \(bubble.totalHours)h")
                                .animation(.easeInOut(duration: Theme.Design.animationDuration), value: diameter)
                        }
                    }
                    .frame(width: geometry.size.width, height: maxSize, alignment: .center)
                }
                .frame(height: 160)
            }
        }
        .padding(.vertical, Theme.spacingExtraSmall)
        .onAppear {
            print("[WeeklyProjectBubbleChartView] Data count: \(data.count)")
            if !data.isEmpty {
                let sampleData = data.prefix(2).map { "\($0.projectName): \($0.totalHours)h" }
                print("[WeeklyProjectBubbleChartView] Sample data: \(sampleData)")
            }
        }
    }
}
