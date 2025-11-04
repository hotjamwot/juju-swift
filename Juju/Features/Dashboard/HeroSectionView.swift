import SwiftUI
import Charts

struct HeroSectionView: View {
    // MARK: - Properties
    @ObservedObject var chartDataPreparer: ChartDataPreparer

    let totalHours: Double
    let totalAllTimeHours: Double
    let totalSessions: Int

    var body: some View {
        VStack(spacing: Theme.spacingMedium) {
            // Header
            HStack(spacing: Theme.spacingSmall) {
                Spacer()
                Image("juju_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .shadow(radius: 1)

                Text("    You've spent")
                Text(String(format: "%.1f", totalHours) + " hours")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("in the Juju this week!")
                Spacer()
            }
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.spacingLarge)

            // Two‑column charts
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let leftWidth  = totalWidth * 0.25
                let rightWidth = totalWidth * 0.75

                HStack(spacing: Theme.spacingSmall) {
                    // Bubble chart – 35 %
                    WeeklyProjectBubbleChartView(
                        data: chartDataPreparer.weeklyProjectTotals()
                    )
                    .frame(width: leftWidth, height: 200)

                    // Calendar chart
                    SessionCalendarChartView(
                        sessions: chartDataPreparer.currentWeekSessionsForCalendar()
                    )
                    .frame(width: rightWidth, height: 200)
                    .border (.clear, width: 0)
                }
                .frame(width: totalWidth, height: 200)
            }
            .frame(height: 200)
            .padding(.bottom, Theme.spacingSmall)

        }
        .padding(.horizontal, Theme.spacingExtraSmall)
        .padding(.vertical, Theme.spacingLarge)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Design.cornerRadius)
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}


#Preview {
    // Mock data for ChartDataPreparer - replace with a real mock if needed
    let mockChartDataPreparer = ChartDataPreparer()
    return HeroSectionView(chartDataPreparer: mockChartDataPreparer, totalHours: 12.5, totalAllTimeHours: 150.0, totalSessions: 42)
        .frame(width: 900) // adjust as necessary
        .padding()
}
