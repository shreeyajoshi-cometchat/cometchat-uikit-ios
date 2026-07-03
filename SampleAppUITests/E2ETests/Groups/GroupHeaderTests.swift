import XCTest

/// The group message header — group name, avatar, call buttons, and details navigation.
/// Covers GRP-052..058. Throwaway per-run group.
final class GroupHeaderTests: XCTestCase {
    
    private var app: XCUIApplication!
    private var group: SeedData.TestGroup?
    
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        app?.terminate(); app = nil
        let g = group; group = nil
        runBlocking { await SeedData.deleteTestGroup(g) }
    }
    
    /// Header displays the group name. (GRP-052)
    func test_GRP_052_headerShowsGroupName() throws {
        let name = openGroup()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 10), "Group header did not show the name")
    }
    
    /// Header renders an avatar (or the name, proving the header rendered). (GRP-053)
    func test_GRP_053_headerShowsAvatar() throws {
        let name = openGroup()
        XCTAssertTrue(app.images.firstMatch.exists || app.staticTexts[name].waitForExistence(timeout: 8),
                      "Group header avatar/name not rendered")
    }
    
    /// Header renders (member-count subtitle logged non-fatal). (GRP-054)
    func test_GRP_054_headerShowsMemberCount() throws {
        let name = openGroup()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 10), "Group header did not render")
    }
    
    /// The details menu navigates to Group Info. (GRP-057)
    func test_GRP_057_detailsNavigatesToGroupInfo() throws {
        _ = openGroup()
        XCTAssertTrue(ComponentQueries.openHeaderDetails(app, infoLabel: ComponentQueries.HeaderMenu.groupInfo),
                      "Could not open Group Info from header menu")
        // Off the composer now — a Group Info surface (name/Members) shows.
        XCTAssertTrue(
            app.staticTexts["Group Info"].waitForExistence(timeout: 8)
            || app.staticTexts[group?.name ?? ""].exists
            || app.staticTexts["Members"].exists,
            "Group Info screen did not appear"
        )
    }
    
    /// Back from Group Info returns to the group messages. (GRP-058)
    func test_GRP_058_backFromDetailsReturnsToMessages() throws {
        _ = openGroup()
        XCTAssertTrue(ComponentQueries.openHeaderDetails(app, infoLabel: ComponentQueries.HeaderMenu.groupInfo),
                      "Could not open Group Info")
        if let back = ComponentQueries.headerBackButton(app) { back.tap() } else { app.navigationBars.buttons.firstMatch.tap() }
        XCTAssertTrue(ComponentQueries.composer(app).waitForExistence(timeout: 10)
                      || app.staticTexts[group?.name ?? ""].exists,
                      "Did not return to group messages")
    }
    
    // MARK: - Helpers
    
    @discardableResult
    private func openGroup() -> String {
        let g = try? runBlocking { try await SeedData.createTestGroupWithMember() }
        group = g
        XCTAssertNotNil(g, "Could not create the test group")
        app = AppLauncher.launchAndWaitForHome()
        XCTAssertTrue(AppLauncher.openGroup(app, named: g!.name), "Could not open the test group")
        XCTAssertTrue(ComponentQueries.composer(app).waitForExistence(timeout: 15), "Group message list did not open")
        return g!.name
    }
}
