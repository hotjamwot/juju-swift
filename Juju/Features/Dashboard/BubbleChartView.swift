import SwiftUI

struct BubbleChartView: View {
    let sessions: [ChartEntry]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background
                Color.black.opacity(0.95)
                    .frame(height: 300)
                
                // Month dividers
                ForEach(1..<12, id: \.self) { month in
                    let monthWidth = geometry.size.width / 12
                    let x = CGFloat(month) * monthWidth
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1)
                        .position(x: x, y: 0)
                        .frame(maxHeight: .infinity)
                }
                
                // Bubbles
                ForEach(prepareBubbles(for: sessions, in: geometry.size), id: \.x) { bubble in
                    Circle()
                        .fill(bubble.color.opacity(bubble.opacity))
                        .frame(width: bubble.diameter, height: bubble.diameter)
                        .position(x: bubble.x + bubble.diameter/2, y: bubble.y + bubble.diameter/2)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.25), lineWidth: 1)
                                .opacity(bubble.shadow ? 1 : 0)
                        )
                }
            }
        }
    }
    
    private func prepareBubbles(for sessions: [ChartEntry], in size: CGSize) -> [BubbleData] {
        guard !sessions.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let currentDate = Date()
        let year = calendar.component(.year, from: currentDate)
        
        let startDate = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!
        
        // Calculate total days in the year
        let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        
        var bubbles: [BubbleData] = []
        
        for session in sessions {
            // X Position: mapped linearly from 1 Jan → 31 Dec
            let sessionDate = session.date
            let daysFromStart = calendar.dateComponents([.day], from: startDate, to: sessionDate).day ?? 0
            let x = CGFloat(daysFromStart) / CGFloat(totalDays) * size.width
            
            // Y Position: jittered vertical placement
            let y = yJitter(for: session.projectName, totalHeight: size.height)
            
            // Size: scaled by duration
            let diameter = bubbleSize(for: session.durationMinutes)
            
            // Color: from project
            let projectColor = Color(hex: session.projectColor)
            
            // Opacity: based on mood tag
            let opacity = session.mood != nil ? 0.6 : 0.8
            
            // Shadow: based on mood
            let shadow = session.mood != nil
            
            bubbles.append(BubbleData(
                x: x - diameter/2,
                y: y - diameter/2,
                diameter: diameter,
                color: projectColor,
                opacity: opacity,
                shadow: shadow
            ))
        }
        
        return bubbles
    }
    
    private func yJitter(for projectName: String, totalHeight: CGFloat) -> CGFloat {
        // Create a consistent jitter per project to maintain some structure
        let hash = projectName.hashValue
        let randomValue = Double(hash) / Double(Int.max)
        return 50 + CGFloat(randomValue * (totalHeight - 100))
    }
    
    private func bubbleSize(for durationMinutes: Int) -> CGFloat {
        // Scale bubble size to preserve visibility of small sessions while keeping large sessions proportionate
        let baseSize: CGFloat = 4
        let maxSize: CGFloat = 20
        let durationHours = Double(durationMinutes) / 60.0
        
        // Use logarithmic scaling to better handle large differences
        let scaledSize = baseSize + log10(max(durationHours, 1)) * 3
        return min(scaledSize, maxSize)
    }
}

// MARK: - Bubble Data Model
private struct BubbleData {
    let x: CGFloat
    let y: CGFloat
    let diameter: CGFloat
    let color: Color
    let opacity: Double
    let shadow: Bool
}

#Preview {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    let sampleSessions = [
        ChartEntry(
            date: dateFormatter.date(from: "2024-01-15") ?? Date(),
            projectName: "Work",
            projectColor: "#4E79A7",
            durationMinutes: 120,
            startTime: "09:00",
            endTime: "11:00",
            notes: "",
            mood: 1
        ),
        ChartEntry(
            date: dateFormatter.date(from: "2024-03-22") ?? Date(),
            projectName: "Personal",
            projectColor: "#F28E2C",
            durationMinutes: 60,
            startTime: "14:00",
            endTime: "15:00",
            notes: "",
            mood: nil
        )
    ]
    
    return BubbleChartView(sessions: sampleSessions)
        .frame(width: 1000, height: 300)
        .padding()
}
