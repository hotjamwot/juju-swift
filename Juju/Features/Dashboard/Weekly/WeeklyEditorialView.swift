import SwiftUI

/// Narrative Strip — Compact horizontal summary bar at the top of the dashboard
/// Shows the weekly editorial content in a single-line, clean format
///
/// Design Philosophy (Scandinavian-Japanese Minimal):
/// - Acts as a subtle information scent, not a dominant UI element
/// - Minimal visual weight with generous whitespace around it
/// - Only shows when there's data — empty states produce no strip
struct WeeklyEditorialView: View {
    @StateObject var narrativeEngine: NarrativeEngine

    // MARK: - Body
    var body: some View {
        // Only show when we have a headline
        if let headline = narrativeEngine.currentHeadline {
            HStack(spacing: Theme.Spacing.sm) {
                // Left: Total hours (prominent)
                HStack(spacing: Theme.Spacing.xxs) {
                    Text("This week:")
                        .font(Theme.Fonts.narrative)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text(headline.formattedHours)
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
                HStack(spacing: 4) {
                    Text(headline.topActivity.emoji)
                        .font(.system(size: 14))
                    Text(headline.topActivity.name)
                        .font(Theme.Fonts.narrative)
                        .foregroundColor(Theme.Colors.textPrimary)
                }

                // Separator dot
                Circle()
                    .fill(Theme.Colors.divider)
                    .frame(width: 4, height: 4)

                // Right: Top project with emoji
                HStack(spacing: 4) {
                    Text(headline.topProject.emoji)
                        .font(.system(size: 14))
                    Text(headline.topProject.name)
                        .font(Theme.Fonts.narrative)
                        .foregroundColor(Theme.Colors.textPrimary)
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
        }
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