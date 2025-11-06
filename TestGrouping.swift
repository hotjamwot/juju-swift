import Foundation

// Test the date grouping logic
struct TestSessionRecord {
    let id: String
    let date: String
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    let projectName: String
    let notes: String
    let mood: Int?
    
    var startDateTime: Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: date) else { return nil }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let paddedStartTime = startTime.count == 5 ? startTime + ":00" : startTime
        guard let time = timeFormatter.date(from: paddedStartTime) else { return nil }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second ?? 0

        return Calendar.current.date(from: components)
    }
}

func testDateGrouping() {
    let sessions = [
        TestSessionRecord(
            id: "1",
            date: "2024-01-15",
            startTime: "09:00:00",
            endTime: "10:30:00",
            durationMinutes: 90,
            projectName: "Project Alpha",
            notes: "Meeting",
            mood: 7
        ),
        TestSessionRecord(
            id: "2",
            date: "2024-01-15",
            startTime: "14:00:00",
            endTime: "16:00:00",
            durationMinutes: 120,
            projectName: "Project Beta",
            notes: "Work",
            mood: 9
        ),
        TestSessionRecord(
            id: "3",
            date: "2024-01-16",
            startTime: "10:00:00",
            endTime: "11:00:00",
            durationMinutes: 60,
            projectName: "Project Alpha",
            notes: "Review",
            mood: 8
        )
    ]
    
    // Group by date
    let grouped = Dictionary(grouping: sessions) { session -> String in
        guard let date = session.startDateTime else {
            return "Unknown Date"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    print("Grouped sessions:")
    for (date, sessionList) in grouped.sorted(by: { $0.key > $1.key }) {
        print("Date: \(date)")
        for session in sessionList {
            print("  - \(session.projectName) at \(session.startTime)")
        }
    }
}

testDateGrouping()
