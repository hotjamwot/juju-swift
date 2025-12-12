import SwiftUI

/// Weekly Editorial View - Standalone component for the editorial narrative
/// Displays the weekly summary with total hours, focus activity, and milestones
struct WeeklyEditorialView: View {
    @StateObject var editorialEngine: EditorialEngine
    @State private var headlineText: String = "Loading your creative story..."

    var body: some View {
        VStack(alignment: .center, spacing: Theme.spacingMedium) {
            // Three-line editorial information with accent colors
            VStack(alignment: .center, spacing: Theme.spacingSmall) {
                // Line 1: Total logged time
                Text("This week you logged")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(editorialEngine.currentHeadline?.formattedHours ?? "0h 0m")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.Colors.accentColor, Theme.Colors.accentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Space between sections
                Spacer().frame(height: Theme.spacingMedium)
                
                // Line 2: Focus activity
                Text("You did a lot of")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                if let topActivity = editorialEngine.currentHeadline?.topActivity {
                    HStack(spacing: Theme.spacingExtraSmall) {
                        Text(topActivity.emoji)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(topActivity.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Theme.Colors.accentColor, Theme.Colors.accentColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                } else {
                    Text("Uncategorized")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.accentColor)
                }
                
                // Space between sections
                Spacer().frame(height: Theme.spacingMedium)
                
                // Line 3: Milestone (conditional)
                if let milestone = editorialEngine.currentHeadline?.milestone {
                    Text("And congrats! You")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(milestone.text)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.Colors.accentColor, Theme.Colors.accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            .padding(.horizontal, Theme.spacingLarge)
            .padding(.vertical, Theme.spacingMedium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(Theme.Design.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .onAppear {
            // Generate initial headline
            editorialEngine.generateWeeklyHeadline()
            headlineText = editorialEngine.getCurrentHeadlineText()
        }
        .onChange(of: editorialEngine.currentHeadline) { _ in
            headlineText = editorialEngine.getCurrentHeadlineText()
        }
    }
}

// MARK: Preview
#Preview {
    return WeeklyEditorialView_PreviewsContent()
        .frame(width: 400, height: 300)
        .background(Theme.Colors.background)
        .padding()
}

struct WeeklyEditorialView_PreviewsContent: View {
    @StateObject var editorialEngine = EditorialEngine()
    
    var body: some View {
        WeeklyEditorialView(
            editorialEngine: editorialEngine
        )
        .onAppear {
            // Generate initial headline for preview
            editorialEngine.generateWeeklyHeadline()
        }
    }
}
