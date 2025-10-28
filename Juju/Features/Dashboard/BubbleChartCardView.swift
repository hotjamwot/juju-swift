import SwiftUI
import Charts

struct BubbleChartCardView: View {
    let data: [ProjectChartData]
    
    static let sampleData: [ProjectChartData] = [
        ProjectChartData(projectName: "Work", color: "#4E79A7", totalHours: 120, percentage: 45.0),
        ProjectChartData(projectName: "Personal", color: "#F28E2C", totalHours: 80, percentage: 30.0),
        ProjectChartData(projectName: "Learning", color: "#E15759", totalHours: 40, percentage: 15.0)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            Text("The Big Picture")
                .font(Theme.Fonts.header)
                .foregroundColor(Theme.Colors.textPrimary)
            
            if data.isEmpty {
                Text("No data for this year")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 250)
            } else {
                GeometryReader { geometry in
                    let maxSize = min(geometry.size.width - 40, geometry.size.height)
                    let maxHours = data.map { $0.totalHours }.max() ?? 1
                    let bubbleSpacing: CGFloat = Theme.spacingExtraLarge
                    let maxDiameter = maxSize * 0.85
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
                                .help("Project: \(bubble.projectName)\nTotal: \(bubble.totalHours)h (\(bubble.percentage, specifier: "%.1f")%)")
                                .animation(.easeInOut(duration: Theme.Design.animationDuration), value: diameter)
                        }
                    }
                    .frame(width: geometry.size.width, height: maxSize, alignment: .center)
                }
                .frame(height: 250)
            }
        }
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
        .shadow(radius: 2)
    }
}

#Preview {
    BubbleChartCardView(data: BubbleChartCardView.sampleData)
        .frame(width: 800, height: 300)
        .padding()
}
