import SwiftUI
import Charts

struct HeroSectionView: View {
    @ObservedObject var chartDataPreparer: ChartDataPreparer
    let totalHours: Double
    let totalAllTimeHours: Double
    let totalSessions: Int
    
    var body: some View {
        VStack(spacing: 20) {
            // MARK: - Header & Summary Row
            HStack(alignment: .top, spacing: 24) {
                
                // MARK: Left: Headline + Weekly Bubbles
                VStack(alignment: .leading, spacing: 16) {
                    // Big friendly headline
                    HStack(spacing: 6) {
                        Text("You’ve spent")
                            .font(.system(size: 32, weight: .bold))
                        
                        Text(String(format: "%.1f", totalHours) + " hours")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                        
                        Text("in Juju this week!")
                            .font(.system(size: 32, weight: .bold))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    
                    // Bubble chart for this week’s projects
                    WeeklyProjectBubbleChartView(chartDataPreparer: chartDataPreparer)
                        .frame(height: 160)
                }
                
                Spacer()
                
                // MARK: Right: Summary Metrics
                VStack(alignment: .trailing, spacing: 12) {
                    SummaryMetricView(title: "Total Hours", value: String(format: "%.1f", totalAllTimeHours) + "h")
                    SummaryMetricView(title: "Total Sessions", value: "\(totalSessions)")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .padding(.horizontal)
    }
}
