import Foundation

// MARK: - Core Session Data Models
public struct SessionRecord: Identifiable {
    public let id: String
    let date: String
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    let projectName: String
    let notes: String
    let mood: Int?

    // Computed startDateTime combining date and startTime
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

    // Computed endDateTime combining date and endTime
    var endDateTime: Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: date) else { return nil }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let paddedEndTime = endTime.count == 5 ? endTime + ":00" : endTime
        guard let time = timeFormatter.date(from: paddedEndTime) else { return nil }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second ?? 0

        return Calendar.current.date(from: components)
    }

    // Helper to check if session overlaps with a date interval
    func overlaps(with interval: DateInterval) -> Bool {
        guard let start = startDateTime, let end = endDateTime else { return false }
        return start < interval.end && end > interval.start
    }
}

extension SessionRecord {
    func withUpdated(field: String, value: String) -> SessionRecord {
        let newMood: Int? = field == "mood" ? (Int(value) ?? nil) : mood
        let newDate = field == "date" ? value : date
        let newStartTime = field == "start_time" ? value : startTime
        let newEndTime = field == "end_time" ? value : endTime
        let newProject = field == "project" ? value : projectName
        let newNotes = field == "notes" ? value : notes
        
        return SessionRecord(
            id: id,
            date: newDate,
            startTime: newStartTime,
            endTime: newEndTime,
            durationMinutes: durationMinutes,
            projectName: newProject,
            notes: newNotes,
            mood: newMood
        )
    }
}

// MARK: - Session Data Transfer Object
struct SessionData {
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let projectName: String
    let notes: String
}
