import SwiftUI

/// A single cell in the heat map, representing one day's total tracked time
struct HeatMapCell: Identifiable {
    let date: Date
    let totalHours: Double
    /// Day-of-week index (0=Monday … 6=Sunday)
    let dayOfWeek: Int
    /// Week offset — 0 = oldest week, increasing toward today
    let weekOffset: Int
    var id: Date { date }
}

/// GitHub-style heat map showing daily total hours over the last 5 calendar weeks.
///
/// Layout (matches GitHub contribution graph):
/// - **Columns** = days of the week (Mon … Sun) — 7 columns
/// - **Rows** = calendar weeks (oldest top, current week at the bottom)
/// - **Today** is always in the bottom row, in its correct day-of-week column
/// - The grid is aligned to calendar week boundaries (Mon-Sun)
/// - No title, no legend — pure data with a rich tooltip on hover
struct SessionHeatMapView: View {
    /// Pre-computed daily totals — one entry per day, missing days are zero
    let dailyTotals: [Date: Double]
    
    /// Number of trailing days to show (typically 35)
    let dayCount: Int
    
    /// Color intensity thresholds (in hours)
    private let thresholds: [Double] = [0.5, 2.0, 4.0, 6.0]
    
    private let calendar = Calendar.current
    
    /// Currently hovered cell
    @State private var hoveredCell: HeatMapCell? = nil
    /// Whether the hover timer has fired (slight delay before showing tooltip)
    @State private var showTooltip: Bool = false
    
    init(
        dailyTotals: [Date: Double],
        dayCount: Int = 35
    ) {
        self.dailyTotals = dailyTotals
        self.dayCount = dayCount
    }
    
    // MARK: - Data Processing
    
    /// Generate cells aligned to calendar week boundaries (Mon-Sun).
    private var cells: [HeatMapCell] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        
        let daysSinceMonday = (weekday + 5) % 7
        let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
        let numberOfWeeks = max(1, (dayCount + 6) / 7)
        let startMonday = calendar.date(byAdding: .day, value: -(numberOfWeeks - 1) * 7, to: thisMonday) ?? thisMonday
        
        let totalDays = numberOfWeeks * 7
        
        var result: [HeatMapCell] = []
        for dayOffset in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startMonday) else { continue }
            
            let weekOffset = dayOffset / 7
            let dayOfWeek = dayOffset % 7
            let hours = dailyTotals[date] ?? 0.0
            
            result.append(HeatMapCell(
                date: date,
                totalHours: hours,
                dayOfWeek: dayOfWeek,
                weekOffset: weekOffset
            ))
        }
        
        return result
    }
    
    private var weekCount: Int {
        max(1, (dayCount + 6) / 7)
    }
    
    private func intensityLevel(for hours: Double) -> Int {
        if hours <= 0 { return 0 }
        if hours < thresholds[0] { return 1 }
        if hours < thresholds[1] { return 2 }
        if hours < thresholds[2] { return 3 }
        return 4
    }
    
    private func heatColor(level: Int) -> Color {
        switch level {
        case 0: return Theme.Colors.cardSurface.opacity(0.5)
        case 1: return Theme.Colors.accentColor.opacity(0.12)
        case 2: return Theme.Colors.accentColor.opacity(0.30)
        case 3: return Theme.Colors.accentColor.opacity(0.55)
        case 4: return Theme.Colors.accentColor.opacity(0.85)
        default: return Theme.Colors.cardSurface
        }
    }
    
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if dailyTotals.isEmpty {
                Spacer()
                Text("No data yet")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                GeometryReader { geo in
                    let availableW = geo.size.width
                    let availableH = geo.size.height
                    
                    let rows = weekCount
                    let topLabelsH: CGFloat = 10
                    let minGap: CGFloat = 6
                    let maxGap: CGFloat = 16
                    
                    let widthBasedCell = (availableW - 6 * minGap) / 7
                    let heightBasedCell = (availableH - topLabelsH - CGFloat(rows - 1) * minGap) / CGFloat(rows)
                    let cellSize = max(6, min(widthBasedCell, heightBasedCell))
                    
                    let gap = min(maxGap, max(minGap, (availableW - 7 * cellSize) / 6))
                    
                    VStack(alignment: .center, spacing: 0) {
                        // Top axis labels
                        HStack(spacing: gap) {
                            Spacer()
                            ForEach(0..<7, id: \.self) { col in
                                Text(dayLabels[col])
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.4))
                                    .frame(width: cellSize)
                            }
                            Spacer()
                        }
                        .frame(height: topLabelsH)
                        
                        // Week rows
                        VStack(spacing: gap) {
                            ForEach(0..<rows, id: \.self) { row in
                                HStack(spacing: gap) {
                                    Spacer()
                                    ForEach(0..<7, id: \.self) { dayIdx in
                                        cellView(day: dayIdx, week: row, size: cellSize, rowIndex: row, totalRows: rows)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onHover { hovering in
                        if !hovering {
                            hoveredCell = nil
                            showTooltip = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Cell Builder
    
    /// Builds a single heat map cell with smart tooltip positioning.
    @ViewBuilder
    private func cellView(day dayIdx: Int, week row: Int, size: CGFloat, rowIndex: Int, totalRows: Int) -> some View {
        let cell = cells.first(where: { $0.dayOfWeek == dayIdx && $0.weekOffset == row })
        let isFuture = (cell?.date ?? Date()) > Date()
        
        RoundedRectangle(cornerRadius: 4)
            .fill(
                isFuture
                    ? Color.clear
                    : heatColor(level: intensityLevel(for: cell?.totalHours ?? 0))
            )
            .frame(width: size, height: size)
            .overlay(alignment: rowIndex == 0 ? .bottom : .top) {
                if showTooltip, let currentCell = cell, let hovered = hoveredCell, currentCell.id == hovered.id {
                    VStack(spacing: 2) {
                        Text(currentCell.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11, weight: .medium))
                        Text("\(String(format: "%.1f", currentCell.totalHours))h")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.Colors.accentColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.surface)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.Colors.divider, lineWidth: 1)
                    )
                    .fixedSize()
                    .offset(y: rowIndex == 0 ? 12 : -12)
                    .transition(.opacity)
                }
            }
            .onHover { hovering in
                if hovering, let cell = cell {
                    hoveredCell = cell
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [cell] in
                        if hoveredCell?.id == cell.id {
                            withAnimation(.easeOut(duration: 0.1)) {
                                showTooltip = true
                            }
                        }
                    }
                } else if !hovering, hoveredCell?.id == cell?.id {
                    showTooltip = false
                    hoveredCell = nil
                }
            }
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var mock: [Date: Double] = [:]
    for i in 0..<35 {
        guard let d = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
        mock[d] = Double.random(in: 0...10)
    }
    
    return SessionHeatMapView(dailyTotals: mock)
        .padding()
        .frame(width: 500, height: 280)
        .background(Theme.Colors.background)
}