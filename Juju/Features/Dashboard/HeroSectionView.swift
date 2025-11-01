import SwiftUI
import Charts

struct HeroSectionView: View {
    // MARK: - Properties
    @ObservedObject var chartDataPreparer: ChartDataPreparer
    
    // Data that you already calculate in the Presenter/Controller
    let totalHours: Double              // Hours spent *this week*
    let totalAllTimeHours: Double       // Total hours ever
    let totalSessions: Int              // Total sessions ever
    
    // MARK: - Body
    var body: some View {
        // ---------- Outer card ----------
        VStack(spacing: Theme.spacingMedium) {
            
            // ---------- Top (headline) ----------
            HStack {
                Spacer()
                Text("You've spent")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(String(format: "%.1f", totalHours) + " hours")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("in the Juju this week!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.spacingLarge * 1.2)
            .padding(.bottom, Theme.spacingSmall)
            
            // ---------- Week‑bubble chart ----------
            WeeklyProjectBubbleChartView(data: chartDataPreparer.weeklyProjectTotals())
                .frame(height: 200)
                .padding(.bottom, Theme.spacingSmall)
            
            // --------- 3️⃣ Summary metrics with Logo ----------
            HStack {
                Spacer() // Pushes content away from the left edge
                
                // Left metric
                SummaryMetricView(
                    title: "Total Hours",
                    value: String(format: "%.1f", totalAllTimeHours) + "h"
                )
                
                Spacer() // Creates space between the metric and the logo
                
                // Juju Logo in the center
                Image("juju_logo") // Assumes "juju_logo" is in your Assets.xcassets
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .opacity(0.8) // Makes it slightly less prominent than the data
                
                Spacer() 
                
                // Right metric
                SummaryMetricView(
                    title: "Total Sessions",
                    value: "\(totalSessions)"
                )
                
                Spacer()
            }
            .padding(.top, Theme.spacingSmall)
            .padding(.bottom, Theme.spacingLarge)
        }
        .padding(.horizontal, Theme.spacingLarge)
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
