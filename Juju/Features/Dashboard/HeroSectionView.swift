import SwiftUI
import Charts

struct HeroSectionView: View {
    // MARK: - Properties
    @ObservedObject var chartDataPreparer: ChartDataPreparer

    let totalHours: Double

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
                            colors: [Theme.Colors.accentColor, Theme.Colors.accentColor.opacity(0.7)],
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
                let leftWidth  = totalWidth * 0.30
                let rightWidth = totalWidth * 0.70

                HStack(spacing: Theme.spacingSmall) {
                    // Bubble chart
                    WeeklyProjectBubbleChartView(
                        data: chartDataPreparer.weeklyProjectTotals()
                    )
                    .frame(width: leftWidth, height: 300)

                    // Calendar chart
                    SessionCalendarChartView(
                        sessions: chartDataPreparer.currentWeekSessionsForCalendar()
                    )
                    .padding(Theme.spacingLarge)
                    .frame(width: rightWidth, height: 280)
                    .border (.clear, width: 0)
                }
                .frame(width: totalWidth, height: 280)
            }
            .frame(height: 280)
            .padding(.bottom, Theme.spacingSmall)

        }
        .padding(.horizontal, Theme.spacingLarge)
        .padding(.vertical, Theme.spacingExtraLarge)
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: Preview
#Preview {

    let mockChartDataPreparer = ChartDataPreparer()
    return HeroSectionView(chartDataPreparer: mockChartDataPreparer, totalHours: 12.5)
        .frame(width: 900)
        .padding()
}
