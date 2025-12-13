import SwiftUI
import Charts

/// Yearly Activity Type Pie Chart View
/// Displays a pie chart showing the distribution of time spent on different activity types
struct YearlyActivityPieChartView: View {
    let data: [ActivityTypePieSlice]
    
    @State private var selectedSlice: ActivityTypePieSlice?
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: Theme.spacingMedium) {
            if data.isEmpty {
                Text("No data available")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                GeometryReader { geometry in
                    let size = min(geometry.size.width, geometry.size.height)
                    
                    PieChartView(
                        slices: data,
                        selectedSlice: $selectedSlice,
                        rotationAngle: $rotationAngle
                    )
                    .frame(width: size, height: size)
                    .padding(.vertical, Theme.spacingMedium)
                    
                    // Legend
                    ActivityLegendView(slices: data, selectedSlice: $selectedSlice)
                }
                .frame(height: 400)
            }
        }
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
    }
}

// MARK: - Pie Chart View
struct PieChartView: View {
    let slices: [ActivityTypePieSlice]
    @Binding var selectedSlice: ActivityTypePieSlice?
    @Binding var rotationAngle: Double
    
    private let startAngle: Angle = Angle(degrees: -90) // Start at top
    private let totalHours: Double
    
    init(slices: [ActivityTypePieSlice], selectedSlice: Binding<ActivityTypePieSlice?>, rotationAngle: Binding<Double>) {
        self.slices = slices
        self._selectedSlice = selectedSlice
        self._rotationAngle = rotationAngle
        
        // Calculate total hours for percentage calculations
        self.totalHours = slices.reduce(0) { $0 + $1.totalHours }
    }
    
    var body: some View {
        ZStack {
            // Pie slices with labels inside
            ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                PieSliceWithLabelView(
                    slice: slice,
                    totalHours: totalHours,
                    startAngle: startAngle,
                    isSelected: selectedSlice?.activityName == slice.activityName,
                    sliceIndex: index
                )
                .rotationEffect(Angle(degrees: rotationAngle))
                .animation(.easeInOut(duration: 0.5), value: selectedSlice)
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedSlice = selectedSlice?.activityName == slice.activityName ? nil : slice
                    }
                }
                .help(slice.label)
            }
        }
    }
}

// MARK: - Pie Slice View
struct PieSliceView: View {
    let slice: ActivityTypePieSlice
    let totalHours: Double
    let startAngle: Angle
    let isSelected: Bool
    
    private var sliceAngle: Double {
        (slice.totalHours / totalHours) * 360
    }
    
    private var endAngle: Angle {
        Angle(degrees: startAngle.degrees + sliceAngle)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2
            
            Path { path in
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(slice.color)
            .opacity(isSelected ? 1.0 : 0.8)
            .shadow(color: isSelected ? slice.color.opacity(0.3) : .clear, radius: 8, x: 0, y: 0)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isSelected)
        }
    }
}

// MARK: - Pie Slice With Label View
struct PieSliceWithLabelView: View {
    let slice: ActivityTypePieSlice
    let totalHours: Double
    let startAngle: Angle
    let isSelected: Bool
    let sliceIndex: Int
    
    private var sliceAngle: Double {
        (slice.totalHours / totalHours) * 360
    }
    
    private var endAngle: Angle {
        Angle(degrees: startAngle.degrees + sliceAngle)
    }
    
    // Calculate the center point for the label within the slice
    private var labelPosition: CGPoint {
        let midAngle = Angle(degrees: startAngle.degrees + sliceAngle / 2)
        let radius: Double = 100 // Adjust this to position labels closer to center or edge
        return CGPoint(
            x: cos(midAngle.radians) * radius,
            y: sin(midAngle.radians) * radius
        )
    }
    
    // Determine if label should be white or black based on slice color brightness
    private var labelColor: Color {
        // Simple brightness check - if percentage is less than 40%, use white text
        return slice.percentage < 40 ? .white : .black
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2
            
            // Pie slice
            Path { path in
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(slice.color)
            .opacity(isSelected ? 1.0 : 0.8)
            .shadow(color: isSelected ? slice.color.opacity(0.3) : .clear, radius: 8, x: 0, y: 0)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isSelected)
            
            // Label inside the slice (only show if slice is large enough)
            if sliceAngle > 25 { // Only show label if slice angle is greater than 25 degrees
                VStack(spacing: 2) {
                    Text(slice.emoji)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(slice.activityName)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .foregroundColor(labelColor)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                .position(
                    x: center.x + labelPosition.x,
                    y: center.y + labelPosition.y
                )
                .opacity(isSelected ? 1.0 : 0.9)
                .animation(.easeInOut(duration: 0.3), value: isSelected)
            }
        }
    }
}

// MARK: - Activity Legend View
struct ActivityLegendView: View {
    let slices: [ActivityTypePieSlice]
    @Binding var selectedSlice: ActivityTypePieSlice?
    
    var body: some View {
        VStack(spacing: Theme.spacingSmall) {
            ForEach(slices) { slice in
                HStack(spacing: Theme.spacingMedium) {
                    // Color indicator
                    Circle()
                        .fill(slice.color)
                        .frame(width: 12, height: 12)
                        .opacity(selectedSlice == nil || selectedSlice?.activityName == slice.activityName ? 1.0 : 0.3)
                    
                    // Activity info
                    HStack(spacing: Theme.spacingSmall) {
                        Text(slice.emoji)
                            .font(.system(size: 14))
                        
                        Text(slice.activityName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .opacity(selectedSlice == nil || selectedSlice?.activityName == slice.activityName ? 1.0 : 0.6)
                    }
                    
                    Spacer()
                    
                    // Hours and percentage
                    Text("\(String(format: "%.1f", slice.totalHours))h")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .opacity(selectedSlice == nil || selectedSlice?.activityName == slice.activityName ? 1.0 : 0.6)
                    
                    Text("\(String(format: "%.1f", slice.percentage))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .opacity(selectedSlice == nil || selectedSlice?.activityName == slice.activityName ? 1.0 : 0.6)
                }
                .padding(.horizontal, Theme.spacingSmall)
                .padding(.vertical, Theme.spacingExtraSmall)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedSlice?.activityName == slice.activityName ? 
                              Theme.Colors.accentColor.opacity(0.1) : 
                              Color.clear)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedSlice = selectedSlice?.activityName == slice.activityName ? nil : slice
                    }
                }
            }
        }
        .padding(.horizontal, Theme.spacingMedium)
    }
}

// MARK: - Preview
#Preview {
    return YearlyActivityPieChartView_PreviewsContent()
        .frame(width: 600, height: 500)
        .background(Theme.Colors.background)
        .padding()
}

struct YearlyActivityPieChartView_PreviewsContent: View {
    @StateObject var chartDataPreparer = ChartDataPreparer()
    @StateObject var sessionManager = SessionManager.shared
    @StateObject var projectsViewModel = ProjectsViewModel.shared
    
    var body: some View {
        YearlyActivityPieChartView(
            data: chartDataPreparer.yearlyActivityTotals()
        )
        .onAppear {
            // Load data just like DashboardNativeSwiftChartsView does
            Task {
                await projectsViewModel.loadProjects()
                await sessionManager.loadAllSessions()
                chartDataPreparer.prepareYearlyData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: sessionManager.allSessions.count) { _ in
            // Update chart data when session data changes
            Task {
                chartDataPreparer.prepareYearlyData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
        .onChange(of: projectsViewModel.projects.count) { _ in
            // Update chart data when project data changes
            Task {
                chartDataPreparer.prepareYearlyData(
                    sessions: sessionManager.allSessions,
                    projects: projectsViewModel.projects
                )
            }
        }
    }
}
