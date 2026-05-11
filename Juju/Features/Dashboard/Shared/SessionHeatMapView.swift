import SwiftUI

/// A single cell in the heat map, representing one day's total tracked time
struct HeatMapCell: Identifiable {
    let id = UUID()
    let date: Date
    let totalHours: Double
    let dayOfWeek: Int  // 0=Sunday, 1=Monday, etc.
    let weekOffset: Int // How many weeks ago (0 = current/latest week)
}

/// GitHub-style heat map showing daily total hours over a configurable number of days
/// Cells are colored by intensity based on total hours tracked that day
struct SessionHeatMapView: View {
    let dailyTotals: [Date: Double]
    let title: String
    let subtitle: String
    
    // Number of days to display (default 30)
    let dayCount: Int
    
    // Color intensity thresholds (in hours)
    private let thresholds: [Double] = [0.5, 2.0, 4.0, 8.0]
    
    init(
        dailyTotals: [Date: Double],
        title: String = "Activity Heat Map",
        subtitle: String = "Last 30 days",
        dayCount: Int = 30
    ) {
        self.dailyTotals = dailyTotals
        self.title = title
        self.subtitle = subtitle
        self.dayCount = dayCount
    }
    
    // MARK: - Data Processing
    
    /// Generate heat map cells from the daily totals dictionary
    private var cells: [HeatMapCell] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let maxHours = dailyTotals.values.max() ?? 1.0
        
        // Generate cells for the last `dayCount` days
        return (0..<dayCount).compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            
            // Calculate week offset (consecutive from right)
            // We want the most recent day to be the last column
            let dayIndex = dayCount - 1 - daysAgo
            let weekOffset = dayIndex / 7
            let dayOfWeek = calendar.component(.weekday, from: date) - 1 // 0=Sunday
            
            let hours = dailyTotals[date] ?? 0.0
            
            return HeatMapCell(
                date: date,
                totalHours: hours,
                dayOfWeek: dayOfWeek,
                weekOffset: weekOffset
            )
        }
        .filter { $0.weekOffset >= 0 } // Safety check
    }
    
    /// Maximum number of weeks to display (ceil division)
    private var weekCount: Int {
        (dayCount + 6) / 7
    }
    
    /// Intensity level 0-4 based on hours
    private func intensityLevel(for hours: Double) -> Int {
        if hours <= 0 { return 0 }
        if hours < thresholds[0] { return 1 }
        if hours < thresholds[1] { return 2 }
        if hours < thresholds[2] { return 3 }
        return 4
    }
    
    /// Color for a given intensity level
    private func heatColor(level: Int) -> Color {
        switch level {
        case 0: return Theme.Colors.cardSurface.opacity(0.5) // Empty day
        case 1: return Theme.Colors.accentColor.opacity(0.15) // Very light
        case 2: return Theme.Colors.accentColor.opacity(0.35) // Light
        case 3: return Theme.Colors.accentColor.opacity(0.60) // Medium
        case 4: return Theme.Colors.accentColor.opacity(0.85) // Dense
        default: return Theme.Colors.cardSurface
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Fonts.header)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Heat map grid
            if dailyTotals.isEmpty {
                Text("No data yet")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                HStack(alignment: .top, spacing: 4) {
                    // Day labels column
                    VStack(alignment: .trailing, spacing: 4) {
                        let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                        ForEach(0..<7, id: \.self) { index in
                            Text(dayLabels[index])
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
                                .frame(height: 14)
                        }
                    }
                    .padding(.trailing, 4)
                    
                    // Week columns
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(0..<weekCount, id: \.self) { weekIndex in
                            VStack(spacing: 4) {
                                ForEach(0..<7, id: \.self) { dayIndex in
                                    if let cell = cells.first(where: {
                                        $0.weekOffset == weekIndex && $0.dayOfWeek == dayIndex
                                    }) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(heatColor(level: intensityLevel(for: cell.totalHours)))
                                            .frame(width: 14, height: 14)
                                            .help("\(cell.date, format: .dateTime.month().day()): \(String(format: "%.1f", cell.totalHours))h")
                                    } else {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.clear)
                                            .frame(width: 14, height: 14)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Legend
            HStack(spacing: 6) {
                Text("Less")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatColor(level: level))
                        .frame(width: 12, height: 12)
                }
                
                Text("More")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Generate mock daily totals for the last 30 days
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var mockTotals: [Date: Double] = [:]
    
    for i in 0..<30 {
        guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
        mockTotals[date] = Double.random(in: 0...10)
    }
    
    return VStack {
        SessionHeatMapView(dailyTotals: mockTotals)
            .padding()
    }
    .frame(width: 400, height: 250)
    .background(Theme.Colors.background)
}