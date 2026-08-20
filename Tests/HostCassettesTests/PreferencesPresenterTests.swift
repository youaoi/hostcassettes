import XCTest
import AppKit
@testable import Host_Cassettes

final class PreferencesPresenterTests: XCTestCase {

    /// Finds the preferences window by its `NSTabViewController` content.
    private func preferencesWindow() -> NSWindow? {
        NSApp.windows.first { $0.contentViewController is NSTabViewController }
    }

    override func tearDown() {
        // Close any preferences window opened during the test.
        // CA トランザクションを含む保留中の処理を完了させてからウィンドウを閉じる
        drainMainQueue(hops: 3)
        if let w = preferencesWindow() { w.close() }
        drainMainQueue()
        super.tearDown()
    }

    func testShowPreferences_createsWindow() {
        PreferencesPresenter.showPreferences()
        waitUntil { self.preferencesWindow() != nil }

        let w = preferencesWindow()
        XCTAssertNotNil(w, "A preferences window should exist")
        XCTAssertTrue(w?.isVisible ?? false, "Preferences window should be visible")
    }

    func testShowPreferences_reusesWindow() {
        PreferencesPresenter.showPreferences()
        waitUntil { self.preferencesWindow() != nil }

        let first = preferencesWindow()
        XCTAssertNotNil(first)

        PreferencesPresenter.showPreferences()
        drainMainQueue()

        let second = preferencesWindow()
        XCTAssertTrue(first === second, "Should reuse the same window instance")
    }

    func testShowPreferences_hasFiveTabs() {
        PreferencesPresenter.showPreferences()
        waitUntil { self.preferencesWindow() != nil }

        let tabVC = preferencesWindow()?.contentViewController as? NSTabViewController
        XCTAssertEqual(tabVC?.tabViewItems.count, 5, "Should have 5 preference tabs")
    }

    func testShowPreferences_tabLabelsMatch() {
        PreferencesPresenter.showPreferences()
        waitUntil { self.preferencesWindow() != nil }

        let tabVC = preferencesWindow()?.contentViewController as? NSTabViewController
        let labels = tabVC?.tabViewItems.map(\.label)
        let expected = ["General", "Editor", "Remote", "Hotkeys", "Update"].map {
            NSLocalizedString($0, comment: "")
        }
        XCTAssertEqual(labels, expected)
    }

    func testShowPreferences_tabsHaveIcons() {
        PreferencesPresenter.showPreferences()
        waitUntil { self.preferencesWindow() != nil }

        let tabVC = preferencesWindow()?.contentViewController as? NSTabViewController
        XCTAssertNotNil(tabVC)
        for item in tabVC?.tabViewItems ?? [] {
            XCTAssertNotNil(item.image, "Tab '\(item.label)' should have an icon")
        }
    }

    /// Captures a screenshot of a specific tab and saves to /tmp/preferences-<tab>.png.
    /// Uses view-based rendering to avoid requiring screen recording permission.
    private func captureTab(index: Int, name: String) throws {
        PreferencesPresenter.showPreferences()
        waitUntil { self.preferencesWindow() != nil }
        let w = try XCTUnwrap(preferencesWindow())
        let tabVC = try XCTUnwrap(w.contentViewController as? NSTabViewController)
        tabVC.selectedTabViewItemIndex = index
        drainMainQueue(hops: 3)

        let view = try XCTUnwrap(w.contentView)
        let bitmapRep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmapRep)
        if let png = bitmapRep.representation(using: .png, properties: [:]) {
            try png.write(to: URL(fileURLWithPath: "/tmp/preferences-\(name).png"))
        }
    }

    func testScreenshot_allTabs() throws {
        for (i, name) in ["general", "editor", "remote", "hotkeys", "update"].enumerated() {
            try captureTab(index: i, name: name)
        }
    }

    func testShowPreferences_toolbarStyleIsPreference() {
        PreferencesPresenter.showPreferences()
        waitUntil { self.preferencesWindow() != nil }

        let w = preferencesWindow()
        XCTAssertEqual(w?.toolbarStyle, .preference)
    }
}
