import SwiftUI

/// Narrative Strip — Compact horizontal summary bar at the top of the dashboard
/// Shows the weekly editorial content in a single-line, clean format
struct WeeklyEditorialView: View {
    @StateObject var narrativeEngine: NarrativeEngine

    // MARK: - Body
    var body: some View {
        HStack(spacing: Theme.spacingMedium) {
            // Left: Total hours (prominent)
            HStack(spacing: Theme.spacingExtraSmall) {
                Text("This week:")
                    .font(Theme.Fonts.narrative)
                    .foregroundColor(Theme.Colors.textSecondary)
                Text(narrativeEngine.currentHeadline?.formattedHours ?? "0h 0m")
                    .font(Theme.Fonts.narrativeAccent)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.Colors.accentColor, Theme.Colors.accentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            // Separator dot
            Circle()
                .fill(Theme.Colors.divider)
                .frame(width: 4, height: 4)

            // Center: Top activity
            if let topActivity = narrativeEngine.currentHeadline?.topActivity {
                HStack(spacing: 4) {
                    Text(topActivity.emoji)
                        .font(.system(size: 14))
                    Text(topActivity.name)
                        .font(Theme.Fonts.narrative)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }

            // Separator dot
            Circle()
                .fill(Theme.Colors.divider)
                .frame(width: 4, height: 4)

            // Right: Top project with emoji
            if let topProject = narrativeEngine.currentHeadline?.topProject {
                HStack(spacing: 4) {
                    Text(topProject.emoji)
                        .font(.system(size: 14))
                    Text(topProject.name)
                        .font(Theme.Fonts.narrative)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }

            Spacer()

            // Milestone count badge (if any)
            if !narrativeEngine.currentWeekMilestones.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.accentColor)
                    Text("\(narrativeEngine.currentWeekMilestones.count) milestone\(narrativeEngine.currentWeekMilestones.count == 1 ? "" : "s")")
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.accentColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, Theme.DashboardLayout.chartPadding)
        .padding(.vertical, 10)
        .background(Theme.Colors.cardSurface)
        .cornerRadius(Theme.Design.cornerRadius)
        .onAppear {
            narrativeEngine.generateWeeklyHeadline()
        }
        .onChange(of: narrativeEngine.currentHeadline) { _ in }
    }
}

// MARK: Preview
#Preview {
    return WeeklyEditorialView_PreviewsContent()
        .frame(width: 700, height: 50)
        .background(Theme.Colors.background)
        .padding()
}

struct WeeklyEditorialView_PreviewsContent: View {
    @StateObject var narrativeEngine = NarrativeEngine()

    var body: some View {
        WeeklyEditorialView(
            narrativeEngine: narrativeEngine
        )
        .onAppear {
            narrativeEngine.generateWeeklyHeadline()
        }
    }
}