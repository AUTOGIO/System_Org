import XCTest
@testable import SystemOrganizer

final class ProcessManagerTests: XCTestCase {
    func testInlineScriptSuccessUsesExitCode() {
        let result = ProcessManager().executeScript("", inlineContent: "echo ok\nexit 0")

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("ok"))
    }

    func testInlineScriptFailureUsesExitCode() {
        let result = ProcessManager().executeScript("", inlineContent: "echo nope\nexit 7")

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.exitCode, 7)
        XCTAssertTrue(result.output.contains("nope"))
    }

    func testMissingScriptPathFailsClearly() {
        let result = ProcessManager().executeScript("/tmp/system-organizer-missing-\(UUID().uuidString).sh")

        XCTAssertFalse(result.success)
        XCTAssertNil(result.exitCode)
        XCTAssertTrue(result.output.contains("Script file not found"))
    }

    func testHomeExpansion() {
        let expanded = AutomationManager.expandPath("$HOME/example")

        XCTAssertEqual(expanded, "\(NSHomeDirectory())/example")
    }

    func testTildeExpansion() {
        let expanded = AutomationManager.expandPath("~/example")

        XCTAssertEqual(expanded, "\(NSHomeDirectory())/example")
    }

    func testScriptTimeout() {
        let manager = ProcessManager()
        manager.timeoutSeconds = 1
        let result = manager.executeScript("", inlineContent: "sleep 30\necho should_not_print")

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.output.contains("Timed out"))
    }

    @MainActor
    func testNextFireDateDailyIsInFuture() {
        let manager = AutomationManager()
        let fire = manager.nextFireDate(for: "daily_9am")

        XCTAssertNotNil(fire)
        XCTAssertGreaterThan(fire!, Date())
    }

    @MainActor
    func testNextFireDateManualIsNil() {
        let manager = AutomationManager()
        XCTAssertNil(manager.nextFireDate(for: "manual"))
    }

    func testAutomationModelRoundTrip() throws {
        let original = AutomationModel(
            id: "test_auto",
            name: "Test",
            description: "Round trip",
            isEnabled: false,
            scriptPath: "$HOME/Documents/GitHub/System_Org 2/scripts/SystemOrganizer/daily_system_report.sh",
            schedule: "manual",
            category: .development,
            tags: ["test"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AutomationModel.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.scriptPath, original.scriptPath)
        XCTAssertEqual(decoded.isEnabled, false)
        XCTAssertEqual(decoded.category, .development)
        XCTAssertEqual(decoded.tags, ["test"])
    }
}
