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
}
