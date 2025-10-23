import SwiftUI
import Charts

// MARK: - Stacked Bar Chart View
struct StackedBarChartView: View {
    let data: [DailyChartEntry]
    // State used to drive a native-feeling hover tooltip over bars
    @State private var selectedEntry: DailyChartEntry?
    @State private var tooltipLocation: CGPoint?
    // Allow caller to tune x-axis tick density
    var desiredTickCount: Int = 7
    
    var body: some View {
        Chart(data) { entry in
            BarMark(
                x: .value("Date", entry.date),
                y: .value("Duration", entry.durationHours)
            )
            .foregroundStyle(entry.colorSwiftUI)
            .cornerRadius(4)
            .opacity(0.8)
            // NOTE: Explicit bar width control isn't available on this Charts version.
            // Rely on automatic sizing; spacing is handled by x-domain/tick density.
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: desiredTickCount + 2)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)))
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                    }
                }
        // Subtle plot background for dark mode
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.white.opacity(0.02))
                .cornerRadius(8)
        }
        // Tooltip overlay using ChartProxy + hover tracking (no click needed)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    // Track hover and pointer location continuously
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            tooltipLocation = loc
                            if let date: Date = proxy.value(atX: loc.x) {
                                if let nearest = data.min(by: { abs($0.date.timeIntervalSince1970 - date.timeIntervalSince1970) < abs($1.date.timeIntervalSince1970 - date.timeIntervalSince1970) }) {
                                    selectedEntry = nearest
                                }
                            }
                        case .ended:
                            selectedEntry = nil
                            tooltipLocation = nil
                        }
                    }
                // Draw tooltip at the pointer location for a native feel
                if let entry = selectedEntry, let loc = tooltipLocation {
                    let title = entry.projectName
                    let value = String(format: "%.1fh — %@", entry.durationHours, entry.date.formatted(.dateTime.day().month(.abbreviated)))
                    ChartTooltip(title: title, value: value, color: entry.colorSwiftUI)
                        .position(x: min(max(loc.x + 12, 80), geo.size.width - 80), y: max(loc.y - 24, 24))
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.12), value: selectedEntry?.id)
                }
            }
        }
    }
}

// MARK: - Stacked Area Chart View
struct StackedAreaChartView: View {
    let data: [StackedChartEntry]
    // Control axis density externally based on selected filter
    var desiredTickCount: Int = 6
    @State private var selectedEntry: StackedChartEntry?
    @State private var tooltipLocation: CGPoint?
    
    var body: some View {
        Chart(data) { entry in
            // Use foregroundStyle(by:) to create stacked layers by project
            AreaMark(
                x: .value("Period", entry.period),
                y: .value("Hours", entry.value)
            )
            .interpolationMethod(.linear) // reduce visual wobble
            .foregroundStyle(by: .value("Project", entry.projectName))
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: desiredTickCount)) { _ in
                AxisValueLabel()
            }
        }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)))
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                    }
                }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.white.opacity(0.02))
                .cornerRadius(8)
        }
        // Tooltip overlay for stacked area showing period + project + duration
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            tooltipLocation = loc
                            if let period: String = proxy.value(atX: loc.x) {
                                if let match = data.first(where: { $0.period == period }) {
                                    selectedEntry = match
                                } else {
                                    let nearest = data.min { a, b in
                                        let ax = proxy.position(forX: a.period) ?? 0
                                        let bx = proxy.position(forX: b.period) ?? 0
                                        return abs(ax - loc.x) < abs(bx - loc.x)
                                    }
                                    selectedEntry = nearest
                                }
                            }
                        case .ended:
                            selectedEntry = nil
                            tooltipLocation = nil
                        }
                    }
                if let entry = selectedEntry, let loc = tooltipLocation {
                    let title = entry.projectName
                    let value = String(format: "%.1fh — %@", entry.value, entry.period)
                    ChartTooltip(title: title, value: value, color: entry.colorSwiftUI)
                        .position(x: min(max(loc.x + 12, 80), geo.size.width - 80), y: max(loc.y - 24, 24))
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.12), value: selectedEntry?.id)
                }
            }
        }
    }
}

// MARK: - Pie Chart View
struct PieChartView: View {
    let data: [PieChartEntry]
    @State private var selectedEntry: PieChartEntry?
    @State private var tooltipLocation: CGPoint?
    
    var body: some View {
        Chart(data) { entry in
            SectorMark(
                angle: .value("Duration", entry.value),
                innerRadius: .ratio(0.4),
                angularInset: 1.5
            )
            .foregroundStyle(entry.colorSwiftUI)
            .opacity(0.9)
        }
        .frame(height: 200)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.white.opacity(0.02))
                .cornerRadius(8)
        }
        // Overlay to compute which slice is under the pointer and show tooltip
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            tooltipLocation = loc
                            if let picked = pickSlice(at: loc, in: geo.size) { selectedEntry = picked }
                        case .ended:
                            selectedEntry = nil
                            tooltipLocation = nil
                        }
                    }
                if let entry = selectedEntry, let loc = tooltipLocation {
                    let title = entry.projectName
                    let value = String(format: "%.1fh (%.0f%%)", entry.value, entry.percentage)
                    ChartTooltip(title: title, value: value, color: entry.colorSwiftUI)
                        .position(x: min(max(loc.x + 12, 80), geo.size.width - 80), y: max(loc.y - 24, 24))
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.12), value: selectedEntry?.id)
                }
            }
        }
    }

    // Picks the pie slice under a point by converting pointer to polar coords
    private func pickSlice(at location: CGPoint, in size: CGSize) -> PieChartEntry? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = center.y - location.y // invert y for standard polar orientation
        let radius = sqrt(dx*dx + dy*dy)
        // Only react near the donut area (ignore far outside)
        if radius < min(size.width, size.height) * 0.2 { return nil }
        let angle = atan2(dy, dx) // [-pi, pi]
        let angleDeg = (angle >= 0 ? angle : (2 * .pi + angle)) * 180 / .pi // [0, 360)
        let total = data.reduce(0) { $0 + $1.value }
        guard total > 0 else { return nil }
        var start: Double = 0
        for entry in data {
            let sweep = entry.value / total * 360
            let end = start + sweep
            if angleDeg >= start && angleDeg < end { return entry }
            start = end
        }
        return nil
    }
}

// MARK: - Project Bar Chart View
struct ProjectBarChartView: View {
    let data: [ProjectChartData]
    @State private var selected: ProjectChartData?
    @State private var tooltipLocation: CGPoint?
    
    var body: some View {
        Chart(data) { entry in
            BarMark(
                x: .value("Project", entry.projectName),
                y: .value("Hours", entry.totalHours)
            )
            .foregroundStyle(entry.colorSwiftUI.gradient)
            .opacity(0.8)
            // NOTE: Explicit bar width control isn't available on this Charts version.
            // Rely on automatic sizing; spacing is handled by x-domain/tick density.
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 10)) { _ in
                AxisValueLabel()
            }
        }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)))
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                    }
                }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.white.opacity(0.02))
                .cornerRadius(8)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            tooltipLocation = loc
                            if let project: String = proxy.value(atX: loc.x) {
                                selected = data.first(where: { $0.projectName == project })
                            } else {
                                selected = data.min { a, b in
                                    let ax = proxy.position(forX: a.projectName) ?? 0
                                    let bx = proxy.position(forX: b.projectName) ?? 0
                                    return abs(ax - loc.x) < abs(bx - loc.x)
                                }
                            }
                        case .ended:
                            selected = nil
                            tooltipLocation = nil
                        }
                    }
                if let entry = selected, let loc = tooltipLocation {
                    let title = entry.projectName
                    let value = String(format: "%.1fh (%.0f%%)", entry.totalHours, entry.percentage)
                    ChartTooltip(title: title, value: value, color: entry.colorSwiftUI)
                        .position(x: min(max(loc.x + 12, 80), geo.size.width - 80), y: max(loc.y - 24, 24))
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.12), value: entry.id)
                }
            }
        }
    }
}

// MARK: - Chart Legend Component
// Legend redesigned to wrap horizontally under charts and truncate long names
struct ChartLegend: View {
    let data: [PieChartEntry]
    let columns: [GridItem] = [GridItem(.adaptive(minimum: 160), spacing: 12)]
    
    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(data) { entry in
                HStack(spacing: 8) {
                    Circle()
                        .fill(entry.colorSwiftUI)
                        .frame(width: 10, height: 10)
                    Text(entry.projectName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    Text(String(format: "%.1fh", entry.value))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.top, Theme.spacingSmall)
    }
}

// MARK: - Tooltip Component
struct ChartTooltip: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            
            Text(value)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, Theme.spacingMedium)
        .padding(.vertical, Theme.spacingSmall)
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

// MARK: - Enhanced Chart Card with Legend
struct EnhancedChartCard<Content: View>: View {
    let title: String
    let legendData: [PieChartEntry]?
    @ViewBuilder let content: Content
    
    init(title: String, legendData: [PieChartEntry]? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.legendData = legendData
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            content
            // Place legend below chart to avoid header crowding and allow wrapping
            if let legendData = legendData, !legendData.isEmpty {
                ChartLegend(data: legendData)
            }
        }
        .padding(Theme.spacingLarge)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
