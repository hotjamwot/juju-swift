import SwiftUI

struct SessionCardView: View {
    let session: SessionRecord
    let projects: [Project]
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.spacingLarge) {
            // LEFT: Project > Date
            VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                Text(session.projectName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Date
                Text(formattedDate)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            
            // MIDDLE-LEFT: Duration and Start/End Time (new column)
            VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
                // Duration
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDuration(session.durationMinutes))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                
                // Start Time - End Time
                HStack(spacing: Theme.spacingExtraSmall) {
                    HStack(spacing: Theme.spacingExtraSmall) {
                        Image(systemName: "play.fill")
                            .font(.caption2)
                        Text(formattedStartTime)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                    
                    Text("—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: Theme.spacingExtraSmall) {
                        Image(systemName: "stop.fill")
                            .font(.caption2)
                        Text(formattedEndTime)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            
            // MIDDLE-RIGHT: Note (lengthened horizontally for more X axis space)
            VStack(alignment: .leading, spacing: Theme.spacingExtraSmall) {
                if !session.notes.isEmpty {
                    Text(session.notes)
                        .font(.body)
                        .lineLimit(6) // Increased from 4 to 6 for 1.5x space
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true) // Allow horizontal expansion
                } else {
                    Text("No notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .frame(maxWidth: .infinity)
            
            // RIGHT: Mood > Edit and Delete buttons
            VStack(alignment: .trailing, spacing: Theme.spacingSmall) {
                // Mood
                if let mood = session.mood {
                    HStack(spacing: Theme.spacingExtraSmall) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text("\(mood)")
                            .font(.caption)
                        .fontWeight(.medium)
                    }
                    .padding(.horizontal, Theme.spacingSmall)
                    .padding(.vertical, Theme.spacingExtraSmall)
                    .foregroundStyle(moodColor(for: mood))
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: Theme.spacingSmall) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.title3)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.title3)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
        }
        .padding(Theme.spacingLarge)
        .frame(minHeight: 100)
        .background(Color(Theme.background))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.primary.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Theme.surface.opacity(0.9), radius: 2, x: 0, y: 1)
    }
    
    private var formattedDate: String {
        let date = parseDate()
        let day = Calendar.current.component(.day, from: date)
        let month = DateFormatter().monthSymbols[Calendar.current.component(.month, from: date) - 1]
        let ordinal = ordinalSuffix(for: day)
        return "\(day)\(ordinal) \(month)"
    }
    
    private var formattedStartTime: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let components = startTimeComponents
        if let date = Calendar.current.date(from: DateComponents(hour: components.hour, minute: components.minute)) {
            return timeFormatter.string(from: date)
        }
        return ""
    }
    
    private var formattedEndTime: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let components = endTimeComponents
        if let date = Calendar.current.date(from: DateComponents(hour: components.hour, minute: components.minute)) {
            return timeFormatter.string(from: date)
        }
        return ""
    }
    
    private var startTimeComponents: (hour: Int, minute: Int) {
        let parts = session.startTime.components(separatedBy: ":")
        let hour = Int(parts[0]) ?? 0
        let minute = Int(parts[1]) ?? 0
        return (hour, minute)
    }
    
    private var endTimeComponents: (hour: Int, minute: Int) {
        let parts = session.endTime.components(separatedBy: ":")
        let hour = Int(parts[0]) ?? 0
        let minute = Int(parts[1] ?? "0") ?? 0
        return (hour, minute)
    }
    
    private func parseDate() -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: session.date) ?? Date()
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
    
    private func ordinalSuffix(for day: Int) -> String {
        let ones = day % 10
        let tens = day % 100
        if tens >= 11 && tens <= 13 {
            return "th"
        }
        switch ones {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
    
    private func moodColor(for mood: Int) -> Color {
        switch mood {
        case 7...10: return .green
        case 4...6: return .orange
        default: return .red
        }
    }
    
    private func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var hexSanitized = hex
        var rgb: UInt64 = 0
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0
        
        _ = hexSanitized.index(after: hexSanitized.startIndex)
        hexSanitized.remove(at: hexSanitized.startIndex)
        if hexSanitized.count == 3 {
            hexSanitized = String(hexSanitized.lazy.map { "\($0)\($0)" }.joined())
        }
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        if hexSanitized.count == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        }
        
        return Color(red: r, green: g, blue: b)
    }
}
