import XCTest
import AppKit
import SwiftUI
@testable import Host_Cassettes

final class AboutBoxPresenterTests: XCTestCase {

    /// Finds the About box window by its hosting controller content.
    private func aboutWindow() -> NSWindow? {
        NSApp.windows.first {
            $0.contentViewController is NSHostingController<AboutBoxView>
        }
    }

    override func tearDown() {
        drainMainQueue(hops: 3)
        if let w = aboutWindow() { w.close() }
        drainMainQueue()
        super.tearDown()
    }

    func testShow_createsWindow() {
        AboutBoxPresenter.show()
        waitUntil { self.aboutWindow() != nil }

        let w = aboutWindow()
        XCTAssertNotNil(w, "An About box window should exist")
        XCTAssertTrue(w?.isVisible ?? false, "About box window should be visible")
    }

    func testShow_reusesWindow() {
        AboutBoxPresenter.show()
        waitUntil { self.aboutWindow() != nil }

        let first = aboutWindow()
        XCTAssertNotNil(first)

        AboutBoxPresenter.show()
        drainMainQueue()

        let second = aboutWindow()
        XCTAssertTrue(first === second, "Should reuse the same window instance")
    }

    func testShow_windowStyleMask() {
        AboutBoxPresenter.show()
        waitUntil { self.aboutWindow() != nil }

        let w = aboutWindow()
        XCTAssertNotNil(w)
        XCTAssertTrue(w?.styleMask.contains(.titled) ?? false)
        XCTAssertTrue(w?.styleMask.contains(.closable) ?? false)
    }

    func testShow_windowIsNotReleasedWhenClosed() {
        AboutBoxPresenter.show()
        waitUntil { self.aboutWindow() != nil }

        let w = aboutWindow()
        XCTAssertNotNil(w)
        XCTAssertFalse(w?.isReleasedWhenClosed ?? true)
    }

    func testScreenshot_aboutBox() throws {
        AboutBoxPresenter.show()
        waitUntil { self.aboutWindow() != nil }
        let w = try XCTUnwrap(aboutWindow())

        let view = try XCTUnwrap(w.contentView)
        let bitmapRep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmapRep)
        if let png = bitmapRep.representation(using: .png, properties: [:]) {
            try png.write(to: URL(fileURLWithPath: "/tmp/about-box.png"))
        }
    }
}
