import SwiftUI
import Charts

struct HeroSectionView: View {
    @ObservedObject var chartDataPreparer: ChartDataPreparer
    let totalHours: Double
    let totalAllTimeHours: Double
    let totalSessions: Int
    
    var body: some View {
        VStack(spacing: Theme.spacingLarge) {
            // MARK: - Header & Summary Row
            HStack(alignment: .top, spacing: Theme.spacingLarge) {
                
                // MARK: Left: Headline + Weekly Bubbles
                VStack(alignment: .leading, spacing: Theme.spacingMedium) {
                    // Big friendly headline
                    HStack(spacing: 6) {
                        Text("You've spent")
                            .font(.system(size: 32, weight: .bold))
                        
                        Text(String(format: "%.1f", totalHours) + " hours")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                        
                        Text("in the Juju this week!")
                            .font(.system(size: 32, weight: .bold))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    
                    // Bubble chart for this week's projects
                    WeeklyProjectBubbleChartView(chartDataPreparer: chartDataPreparer)
                        .frame(height: 160)
                }
                
                Spacer()
                
                // MARK: Right: Summary Metrics
                VStack(alignment: .trailing, spacing: Theme.spacingSmall) {
                    SummaryMetricView(title: "Total Hours", value: String(format: "%.1f", totalAllTimeHours) + "h")
                    SummaryMetricView(title: "Total Sessions", value: "\(totalSessions)")
                }
            }
            .padding(.horizontal, Theme.spacingMedium)
            .padding(.vertical, Theme.spacingMedium)
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.Design.cornerRadius)
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
    }
}

#Preview {
    // Mock data for ChartDataPreparer - replace with a real mock if needed
    let mockChartDataPreparer = ChartDataPreparer()
    return HeroSectionView(chartDataPreparer: mockChartDataPreparer, totalHours: 12.5, totalAllTimeHours: 150.0, totalSessions: 42)
        .frame(width: 900) // adjust as necessary
        .padding()
}
