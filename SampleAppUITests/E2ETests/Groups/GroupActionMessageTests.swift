import XCTest

/// In-chat action/system messages for membership events — the one place iOS otherwise only backend-
/// verifies (E2EAdminCheck/GroupLifecycle prove the mutation on the server, not that the group's message
/// list renders "X was added / banned / made a moderator"). Covers RT-GRP-004/005/006.
///
/// A owns a throwaway per-run group and is viewing its message list when the change fires over REST; the
/// resulting action message is a centered staticText naming the affected member. Because a member may
/// already be named by an earlier event, each test captures a baseline count of mentions and asserts a NEW
/// one appears (not merely that the name is present).
///
/// NOTE: the action-message ELEMENT (centered system bubble) and its exact wording weren't confirmable off-
/// device; the assertion matches the member's first name (robust to verb wording). Confirm on first run per
/// the team's on-device diagnostic-dump practice, and adjust the locator if the bubble isn't a staticText.
final class GroupActionMessageTests: XCTestCase {

    private var app: XCUIApplication!
    private var group: SeedData.TestGroup?

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        app?.terminate(); app = nil
        let g = group; group = nil
        runBlocking { await SeedData.deleteTestGroup(g) }
    }

    /// Adding a member emits an action message naming them in the group. (RT-GRP-006)
    func test_RT_GRP_006_memberAddedShowsActionMessage() throws {
        let g = try runBlocking { try await SeedData.createEmptyTestGroup() } // A owns, no other members
        group = g
        openGroupMessages(name: g.name)
        let baseline = mentionCount(of: TestConfig.userBDisplayName)
        try runBlocking { try await PeerActions.addGroupMembers(guid: g.guid, uids: [TestConfig.userBUid]) }
        XCTAssertTrue(waitForNewMention(of: TestConfig.userBDisplayName, above: baseline, timeout: 20),
                      "No in-chat action message appeared when a member was added")
    }

    /// Banning a member emits an action message naming them. (RT-GRP-004)
    func test_RT_GRP_004_memberBannedShowsActionMessage() throws {
        let g = try runBlocking { try await SeedData.createTestGroupWithMember() } // A owns, B member
        group = g
        openGroupMessages(name: g.name)
        let baseline = mentionCount(of: TestConfig.userBDisplayName)
        try runBlocking { try await PeerActions.banGroupMember(guid: g.guid, uid: TestConfig.userBUid) }
        XCTAssertTrue(waitForNewMention(of: TestConfig.userBDisplayName, above: baseline, timeout: 20),
                      "No in-chat action message appeared when a member was banned")
    }

    /// Changing a member's scope emits an action message naming them. (RT-GRP-005)
    func test_RT_GRP_005_scopeChangeShowsActionMessage() throws {
        let g = try runBlocking { try await SeedData.createTestGroupWithMember() }
        group = g
        openGroupMessages(name: g.name)
        let baseline = mentionCount(of: TestConfig.userBDisplayName)
        try runBlocking { try await PeerActions.setMemberScope(guid: g.guid, uid: TestConfig.userBUid, scope: "moderator") }
        XCTAssertTrue(waitForNewMention(of: TestConfig.userBDisplayName, above: baseline, timeout: 20),
                      "No in-chat action message appeared when a member's scope changed")
    }

    // MARK: - Helpers

    private func openGroupMessages(name: String) {
        app = AppLauncher.launchAndWaitForHome()
        XCTAssertTrue(AppLauncher.openGroup(app, named: name), "Could not open \(name)")
        XCTAssertTrue(ComponentQueries.composer(app).waitForExistence(timeout: 15), "Group message list did not open")
    }

    /// First name of the member — action messages use the display name; matching the first token is robust
    /// to both "First" and "First Last" wording, and avoids depending on the exact system-message verb.
    private func firstName(_ displayName: String) -> String {
        String(displayName.split(separator: " ").first ?? Substring(displayName))
    }

    /// Count of currently-rendered staticTexts mentioning the member. The throwaway group has (almost) no
    /// real messages, so a mention is an action/system message about that member.
    private func mentionCount(of displayName: String) -> Int {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", firstName(displayName))).count
    }

    private func waitForNewMention(of displayName: String, above baseline: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if mentionCount(of: displayName) > baseline { return true }
            _ = app.staticTexts.firstMatch.waitForExistence(timeout: 0.5)
        } while Date() < deadline
        return false
    }
}
