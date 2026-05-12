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

    /// Comparative data for this week vs last week
    private var comparativeData: ComparativeAnalytics? {
        narrativeEngine.getComparativeData(for: .week)
    }

    /// Format a delta value as a string with arrow
    private func deltaText(current: Double, previous: Double) -> String {
        let diff = current - previous
        let sign = diff >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", diff))h"
    }

    /// Color for delta text based on whether hours increased or decreased
    private func deltaColor(current: Double, previous: Double) -> Color {
        current >= previous ? Theme.Colors.accentColor : Color.red.opacity(0.8)
    }

    /// Format hours as "Xh Ym" string
    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    /// Last week comparison view
    @ViewBuilder
    private func lastWeekComparisonView(comparative: ComparativeAnalytics) -> some View {
        let delta = deltaText(
            current: comparative.current.totalHours,
            previous: comparative.previous.totalHours
        )

        HStack(spacing: 4) {
            Image(systemName: "arrow.2.circlepath")
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textSecondary)
            Text("Last week:")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            Text(formatHours(comparative.previous.totalHours))
                .font(Theme.Fonts.caption.weight(.semibold))
                .foregroundColor(Theme.Colors.textSecondary)
            Text(delta)
                .font(Theme.Fonts.caption.weight(.bold))
                .foregroundColor(deltaColor(
                    current: comparative.current.totalHours,
                    previous: comparative.previous.totalHours
                ))
                .contentShape(Rectangle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.Colors.cardSurface.opacity(0.5))
        .cornerRadius(6)
    }

    /// Milestone badge view
    @ViewBuilder
    private func milestoneBadgeView(milestones: [Milestone]) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.accentColor)
            Text("\(milestones.count) milestone\(milestones.count == 1 ? "" : "s")")
                .font(Theme.Fonts.caption)
                .foregroundColor(Theme.Colors.accentColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.Colors.accentColor.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Body
    var body: some View {
        if let headline = narrativeEngine.currentHeadline {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
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

                // Last week comparison
                if let comparative = comparativeData {
                    lastWeekComparisonView(comparative: comparative)
                }

                // Milestone count badge (if any)
                if !narrativeEngine.currentWeekMilestones.isEmpty {
                    milestoneBadgeView(milestones: narrativeEngine.currentWeekMilestones)
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