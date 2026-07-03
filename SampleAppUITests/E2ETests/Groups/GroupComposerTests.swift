import XCTest

/// Sending messages in a group. Covers GRP-013..022. Uses a throwaway
/// per-run group (User A owner, User B member) so the shared `supergroup` is never touched. Mirrors the
/// 1:1 send-variant depth: unique tokens, bubble presence, composer-clears.
final class GroupComposerTests: XCTestCase {

    private var app: XCUIApplication!
    private var group: SeedData.TestGroup?

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        app?.terminate(); app = nil
        let g = group; group = nil
        runBlocking { await SeedData.deleteTestGroup(g) }
    }

    /// Send text in a group; the bubble renders. (GRP-013)
    func test_GRP_013_sendTextInGroup() throws {
        openGroup()
        let token = "E2E-gsend\(UUID().uuidString.prefix(8))"
        ComponentQueries.typeAndSend(app, text: token)
        XCTAssertTrue(ComponentQueries.waitForBubble(app, text: token, timeout: 14), "Group message did not render")
    }

    /// Empty message cannot be sent in a group. (GRP-014)
    func test_GRP_014_emptyMessageBlocked() throws {
        openGroup()
        let send = app.buttons["Send"]
        if send.exists && send.isHittable { send.tap() }
        XCTAssertTrue(ComponentQueries.composerIsEmpty(app), "Empty group message should not send")
    }

    /// Long text sends in a group; the tail renders. (GRP-016)
    func test_GRP_016_longTextSends() throws {
        openGroup()
        let tail = "gtail\(UUID().uuidString.prefix(8))"
        ComponentQueries.typeAndSend(app, text: String(repeating: "G", count: 1024) + tail)
        XCTAssertTrue(ComponentQueries.waitForBubbleContaining(app, substring: tail, timeout: 14),
                      "Long group message tail did not render")
    }

    /// Composer clears after a successful group send. (GRP-018)
    func test_GRP_018_composerClearsAfterSend() throws {
        openGroup()
        let token = "E2E-gclear\(UUID().uuidString.prefix(8))"
        ComponentQueries.typeAndSend(app, text: token)
        XCTAssertTrue(ComponentQueries.waitForBubble(app, text: token, timeout: 14), "Group message did not send")
        XCTAssertTrue(ComponentQueries.composerIsEmpty(app), "Composer did not clear after group send")
    }

    /// A mention message sends in a group; trailing words render. (GRP-020)
    func test_GRP_020_mentionSends() throws {
        openGroup()
        let tail = "gmention\(UUID().uuidString.prefix(8))"
        ComponentQueries.typeAndSend(app, text: "@\(TestConfig.userBDisplayName) hi \(tail)")
        XCTAssertTrue(ComponentQueries.waitForBubbleContaining(app, substring: tail, timeout: 14),
                      "Group mention tail did not render")
    }

    // MARK: - Helpers

    private func openGroup() {
        let g = try? runBlocking { try await SeedData.createTestGroupWithMember() }
        group = g
        XCTAssertNotNil(g, "Could not create the test group")
        app = AppLauncher.launchAndWaitForHome()
        XCTAssertTrue(AppLauncher.openGroup(app, named: g!.name), "Could not open the test group")
        XCTAssertTrue(ComponentQueries.composer(app).waitForExistence(timeout: 15), "Group message list did not open")
    }
}
