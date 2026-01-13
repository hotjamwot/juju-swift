import Foundation

// Simple test to verify CSV format consistency
func testCSVFormat() {
    print("🧪 Testing CSV format consistency...")

    // Create a test session
    let testSession = SessionRecord(
        id: "test-id",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600), // 1 hour later
        projectID: "test-project",
        activityTypeID: "test-activity",
        projectPhaseID: "test-phase",
        milestoneText: "test milestone",
        notes: "test notes",
        mood: 5
    )

    // Test CSV conversion
    let parser = SessionDataParser()
    let csv = parser.convertSessionsToCSV([testSession])

    print("Generated CSV:")
    print(csv)

    // Parse it back
    let (parsedSessions, needsRewrite) = parser.parseSessionsFromCSV(csv)

    print("Parsed sessions count: \(parsedSessions.count)")
    print("Needs rewrite: \(needsRewrite)")

    if let parsedSession = parsedSessions.first {
        print("Parsed session ID: \(parsedSession.id)")
        print("Parsed project ID: \(parsedSession.projectID)")
        print("Parsed activity type ID: \(parsedSession.activityTypeID ?? "nil")")
        print("Parsed phase ID: \(parsedSession.projectPhaseID ?? "nil")")
        print("Parsed milestone: \(parsedSession.milestoneText ?? "nil")")
        print("Parsed notes: \(parsedSession.notes)")
        print("Parsed mood: \(parsedSession.mood ?? -1)")

        // Verify data integrity
        let success = parsedSession.id == testSession.id &&
                      parsedSession.projectID == testSession.projectID &&
                      parsedSession.activityTypeID == testSession.activityTypeID &&
                      parsedSession.projectPhaseID == testSession.projectPhaseID &&
                      parsedSession.milestoneText == testSession.milestoneText &&
                      parsedSession.notes == testSession.notes &&
                      parsedSession.mood == testSession.mood

        print("✅ Data integrity check: \(success ? "PASSED" : "FAILED")")
    } else {
        print("❌ Failed to parse any sessions")
    }
}

// Run the test
testCSVFormat()