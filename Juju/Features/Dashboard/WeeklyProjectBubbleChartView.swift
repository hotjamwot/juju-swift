import SwiftUI
import Charts

struct WeeklyProjectBubbleChartView: View {
    let data: [ProjectChartData]
    @State private var selectedProject: ProjectChartData?
    @State private var hoverLocation: CGPoint?

    var body: some View {
        Chart(data) { entry in
            PointMark(
                x: .value("Project Index", data.firstIndex(where: { $0.id == entry.id }) ?? 0),
                y: .value("Y", 1) // flatten y so bubbles are side by side
            )
            .symbolSize(size(for: entry))
            .foregroundStyle(entry.colorSwiftUI)
            .annotation(position: .overlay, alignment: .center) {
                Text(entry.projectName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(radius: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(6)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.clear)
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            hoverLocation = loc
                            if let projectIndex: Int = proxy.value(atX: loc.x) {
                                let safeIndex = max(0, min(Int(projectIndex), data.count - 1))
                                selectedProject = data[safeIndex]
                            }
                        case .ended:
                            selectedProject = nil
                            hoverLocation = nil
                        }
                    }

                if let project = selectedProject, let loc = hoverLocation {
                    ChartTooltip(
                        title: project.projectName,
                        value: String(format: "%.1f hours", project.totalHours),
                        color: project.colorSwiftUI
                    )
                    .position(
                        x: min(max(loc.x, 80), geo.size.width - 80),
                        y: max(loc.y - 30, 20)
                    )
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.15), value: selectedProject?.id)
                }
            }
        }
    }

    // MARK: - Helpers

    private func size(for entry: ProjectChartData) -> CGFloat {
        // Scale bubble sizes between 100 and 1600 pts² based on total hours
        let maxHours = data.map(\.totalHours).max() ?? 1
        let minHours = data.map(\.totalHours).min() ?? 0
        let norm = (entry.totalHours - minHours) / (maxHours - minHours + 0.0001)
        return 100 + (norm * 1500)
    }
}