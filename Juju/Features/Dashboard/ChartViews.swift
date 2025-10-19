import SwiftUI
import Charts

// MARK: - Stacked Bar Chart View
struct StackedBarChartView: View {
    let data: [DailyChartEntry]
    
    var body: some View {
        Chart(data) { entry in
            BarMark(
                x: .value("Date", entry.date),
                y: .value("Duration", entry.durationHours)
            )
            .foregroundStyle(entry.colorSwiftUI)
            .opacity(0.8)
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 7)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)))
                        AxisGridLine()
                    }
                }
    }
}

// MARK: - Stacked Area Chart View
struct StackedAreaChartView: View {
    let data: [StackedChartEntry]
    
    var body: some View {
        Chart(data) { entry in
            AreaMark(
                x: .value("Week", entry.period),
                y: .value("Duration", entry.value)
            )
            .foregroundStyle(entry.colorSwiftUI)
            .interpolationMethod(.catmullRom)
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisValueLabel()
            }
        }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)))
                        AxisGridLine()
                    }
                }
    }
}

// MARK: - Pie Chart View
struct PieChartView: View {
    let data: [PieChartEntry]
    
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
    }
}

// MARK: - Project Bar Chart View
struct ProjectBarChartView: View {
    let data: [ProjectChartData]
    
    var body: some View {
        Chart(data) { entry in
            BarMark(
                x: .value("Project", entry.projectName),
                y: .value("Hours", entry.totalHours)
            )
            .foregroundStyle(entry.colorSwiftUI.gradient)
            .opacity(0.8)
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
                        AxisGridLine()
                    }
                }
    }
}

// MARK: - Chart Legend Component
struct ChartLegend: View {
    let data: [PieChartEntry]
    let maxItems: Int
    
    init(data: [PieChartEntry], maxItems: Int = 4) {
        self.data = data
        self.maxItems = maxItems
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(data.prefix(maxItems))) { entry in
                HStack(spacing: 8) {
                    Circle()
                        .fill(entry.colorSwiftUI)
                        .frame(width: 12, height: 12)
                    
                    Text(entry.projectName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1fh", entry.value))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }
            
            if data.count > maxItems {
                Text("+\(data.count - maxItems) more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
        .padding(.vertical, 8)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                
                if let legendData = legendData, !legendData.isEmpty {
                    ChartLegend(data: legendData, maxItems: 3)
                }
            }
            
            content
        }
        .padding(16)
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
