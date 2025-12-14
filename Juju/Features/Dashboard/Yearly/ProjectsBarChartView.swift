import SwiftUI
import Charts

/// Project Distribution Bar Chart View
/// Displays a horizontal bar chart showing the projects that have been worked on
struct ProjectDistributionBarChartView: View {
    let data: [ProjectBarChartData]
    
    @State private var selectedProject: ProjectBarChartData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            HStack {
                Spacer()
                
                if let selected = selectedProject {
                    Text("\(selected.emoji) \(selected.projectName)")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }
            
            if data.isEmpty {
                Text("No data available")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                chartView
            }
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        let totalHours = data.reduce(0, { $0 + $1.totalHours })
        
        VStack(spacing: Theme.spacingMedium) {
            ForEach(data) { project in
                ProjectBarRowView(
                    project: project,
                    totalHours: totalHours,
                    isSelected: selectedProject?.id == project.id,
                    onSelect: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedProject = selectedProject?.id == project.id ? nil : project
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Project Bar Row View
struct ProjectBarRowView: View {
    let project: ProjectBarChartData
    let totalHours: Double
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var barWidth: CGFloat {
        guard totalHours > 0 else { return 0 }
        let percentage = project.totalHours / totalHours
        return CGFloat(percentage) * 100 // Scale to 100% width
    }
    
    var body: some View {
        HStack(spacing: Theme.spacingMedium) {
            // Project info
            HStack(spacing: Theme.spacingSmall) {
                Text(project.emoji)
                    .font(.system(size: 16, weight: .medium))
                
                Text(project.projectName)
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: 150, alignment: .leading)
            
            // Progress bar
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Colors.divider.opacity(0.3))
                    .frame(height: 16)
                
                // Progress bar
                RoundedRectangle(cornerRadius: 8)
                    .fill(project.colorSwiftUI)
                    .frame(width: barWidth, height: 16)
                    .scaleEffect(x: isSelected ? 1.05 : 1.0, y: 1.0, anchor: .leading)
                    .animation(.easeInOut(duration: 0.3), value: isSelected)
                    .shadow(color: isSelected ? project.colorSwiftUI.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity)
            
            // Hours and percentage
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", project.totalHours))h")
                    .font(Theme.Fonts.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text("\(String(format: "%.1f", project.percentage))%")
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, Theme.spacingSmall)
        .padding(.vertical, Theme.spacingExtraSmall)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Theme.Colors.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .animation(.easeInOut(duration: 0.3), value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    let mockData: [ProjectBarChartData] = [
        ProjectBarChartData(
            projectName: "Film",
            emoji: "🎬",
            totalHours: 120,
            percentage: 45.0,
            color: Color(hex: "#FFA500")
        ),
        ProjectBarChartData(
            projectName: "Writing",
            emoji: "✍️",
            totalHours: 80,
            percentage: 30.0,
            color: Color(hex: "#800080")
        ),
        ProjectBarChartData(
            projectName: "Design",
            emoji: "🎨",
            totalHours: 40,
            percentage: 15.0,
            color: Color(hex: "#0000FF")
        ),
        ProjectBarChartData(
            projectName: "Learning",
            emoji: "📚",
            totalHours: 20,
            percentage: 7.5,
            color: Color(hex: "#00FF00")
        ),
        ProjectBarChartData(
            projectName: "Other",
            emoji: "📁",
            totalHours: 10,
            percentage: 2.5,
            color: Color(hex: "#999999")
        )
    ]
    
    return ProjectDistributionBarChartView(data: mockData)
        .frame(width: 800, height: 400)
        .background(Theme.Colors.background)
}
