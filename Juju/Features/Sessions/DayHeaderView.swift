import SwiftUI

// MARK: - Ordinal Helper
private extension Int {
    var ordinalSuffix: String {
        switch (self % 100) {
        case 11, 12, 13: return "th"
        default:
            switch (self % 10) {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }
    }
}

// MARK: - Pretty date helper
private extension Date {
    /// "Monday, 23rd October"
    var prettyHeader: String {
        let cal = Calendar.current
        let weekday = cal.weekdaySymbols[cal.component(.weekday, from: self) - 1]
        let day     = cal.component(.day, from: self)
        let month   = cal.monthSymbols[cal.component(.month, from: self) - 1]
        return "\(weekday), \(day)\(day.ordinalSuffix) \(month)"
    }
    
    /// "Jan 15, 2024"
    var shortHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: self)
    }
    
    /// "Today", "Yesterday", or "Jan 15"
    var relativeHeader: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thisDate = calendar.startOfDay(for: self)
        
        if calendar.isDate(today, inSameDayAs: thisDate) {
            return "Today"
        } else if calendar.isDate(calendar.date(byAdding: .day, value: -1, to: today)!, inSameDayAs: thisDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        }
    }
}

/// Header view for displaying day grouping in SessionsView
/// Shows date, session count, and collapse/expand controls
struct DayHeaderView: View {
    let date: Date
    let sessionCount: Int
    @Binding var isExpanded: Bool
    
    var body: some View {
        HStack {
            // Left section: Date and session count
            HStack(spacing: 12) {
                // Expand/collapse button
                Button(action: toggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Date text
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.prettyHeader)
                        .font(Theme.Fonts.header)
                        .foregroundColor(Theme.Colors.textPrimary)
                    
                    Text(date.relativeHeader)
                        .font(Theme.Fonts.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                // Session count badge
                Text("\(sessionCount) session\(sessionCount != 1 ? "s" : "")")
                    .font(Theme.Fonts.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.divider.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
        .padding(.vertical, Theme.spacingSmall)
        .padding(.horizontal, Theme.spacingMedium)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Theme.Colors.divider),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleExpand()
        }
    }
    
    private func toggleExpand() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
        }
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 12.0, *)
struct DayHeaderView_Previews: PreviewProvider {
    @State static var isExpanded = true
    
    static var previews: some View {
        VStack(spacing: 0) {
            DayHeaderView(
                date: Date(),
                sessionCount: 5,
                isExpanded: $isExpanded
            )
            
            DayHeaderView(
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                sessionCount: 3,
                isExpanded: $isExpanded
            )
            
            DayHeaderView(
                date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
                sessionCount: 8,
                isExpanded: $isExpanded
            )
        }
        .background(Theme.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif
