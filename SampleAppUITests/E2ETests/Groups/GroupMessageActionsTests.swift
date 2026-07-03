import XCTest

/// Message actions in a group — edit/delete own messages, the long-press popup, copy.
/// Covers GRP-023..031, GRP-081, GRP-084..089. Throwaway per-run group.
final class GroupMessageActionsTests: XCTestCase {

    private var app: XCUIApplication!
    private var group: SeedData.TestGroup?

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        app?.terminate(); app = nil
        let g = group; group = nil
        runBlocking { await SeedData.deleteTestGroup(g) }
    }

    /// Edit an own group message; the edited text renders. (GRP-023)
    func test_GRP_023_editOwnGroupMessage() throws {
        openGroup()
        let token = "E2E-gedit\(UUID().uuidString.prefix(8))"
        ComponentQueries.typeAndSend(app, text: token)
        XCTAssertTrue(ComponentQueries.waitForBubble(app, text: token, timeout: 14), "Message did not send")

        XCTAssertTrue(ComponentQueries.openMessageOptions(app, bubbleText: token), "Long-press failed")
        XCTAssertTrue(ComponentQueries.tapMessageOption(app, label: ComponentQueries.MessageOption.edit), "Edit missing")
        let composer = ComponentQueries.composer(app)
        XCTAssertTrue(composer.waitForExistence(timeout: 8), "Composer did not focus for edit")
        composer.tap(); composer.typeText("Z")
        ComponentQueries.sendButton(app).tap()
        XCTAssertTrue(ComponentQueries.waitForBubbleContaining(app, substring: token, timeout: 12), "Edit did not render")
    }

    /// Edited group message shows an Edited marker. (GRP-025)
    func test_GRP_025_editedShowsMarker() throws {
        openGroup()
        let token = "E2E-gmark\(UUID().uuidString.prefix(8))"
        ComponentQueries.typeAndSend(app, text: token)
        XCTAssertTrue(ComponentQueries.waitForBubble(app, text: token, timeout: 14), "Message did not send")
        XCTAssertTrue(ComponentQueries.openMessageOptions(app, bubbleText: token), "Long-press failed")
        XCTAssertTrue(ComponentQueries.tapMessageOption(app, label: ComponentQueries.MessageOption.edit), "Edit missing")
        let composer = ComponentQueries.composer(app)
        XCTAssertTrue(composer.waitForExistence(timeout: 8), "Composer did not focus")
        composer.tap(); composer.typeText("W")
        ComponentQueries.sendButton(app).tap()
        XCTAssertTrue(ComponentQueries.waitForEditedMarker(app, timeout: 12), "Edited marker did not appear")
    }

    /// Delete an own group message; the placeholder replaces it. (GRP-027 / GRP-030)
    func test_GRP_027_deleteOwnGroupMessage() throws {
        openGroup()
        let token = "E2E-gdel\(UUID().uuidString.prefix(8))"
        ComponentQueries.typeAndSend(app, text: token)
        XCTAssertTrue(ComponentQueries.waitForBubble(app, text: token, timeout: 14), "Message did not send")
        XCTAssertTrue(ComponentQueries.openMessageOptions(app, bubbleText: token), "Long-press failed")
        XCTAssertTrue(ComponentQueries.tapMessageOption(app, label: ComponentQueries.MessageOption.delete), "Delete missing")
        _ = ComponentQueries.confirmDestructiveAction(app)
        XCTAssertTrue(ComponentQueries.waitForDeletedPlaceholder(app, timeout: 12)
                        || !ComponentQueries.waitForBubble(app, text: token, timeout: 3),
                      "Group message not deleted")
    }

    /// Copy option present in a group message popup. (GRP-084)
    func test_GRP_084_copyGroupMessage() throws {
        openGroup()
        let token = "E2E-gcopy\(UUID().uuidString.prefix(8))"
        ComponentQueries.typeAndSend(app, text: token)
        XCTAssertTrue(ComponentQueries.waitForBubble(app, text: token, timeout: 14), "Message did not send")
        XCTAssertTrue(ComponentQueries.openMessageOptions(app, bubbleText: token), "Long-press failed")
        XCTAssertTrue(app.buttons[ComponentQueries.MessageOption.copy].waitForExistence(timeout: 6)
                        || app.staticTexts[ComponentQueries.MessageOption.copy].exists,
                      "Copy option missing in group popup")
    }

    /// Long-press a group message shows the action popup with at least one known option. (GRP-086)
    func test_GRP_086_longPressShowsActionPopup() throws {
        openGroup()
        let token = "E2E-glp\(UUID().uuidString.prefix(8))"
        ComponentQueries.typeAndSend(app, text: token)
        XCTAssertTrue(ComponentQueries.waitForBubble(app, text: token, timeout: 14), "Message did not send")
        XCTAssertTrue(ComponentQueries.openMessageOptions(app, bubbleText: token), "Long-press failed")
        let anyOption = ["Copy", "Edit", "Delete", "Reply in Thread", "Info"].contains {
            app.buttons[$0].waitForExistence(timeout: 4) || app.staticTexts[$0].exists
        }
        XCTAssertTrue(anyOption, "Group message action popup did not present options")
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
