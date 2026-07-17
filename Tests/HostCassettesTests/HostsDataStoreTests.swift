import XCTest
@testable import Gas_Mask

final class HostsDataStoreTests: XCTestCase {

    // MARK: - Notification Name Constants

    /// Verify Swift notification names match the ObjC #define values from Gas_Mask_Prefix.pch
    func testNotificationNames_matchObjCDefines() {
        XCTAssertEqual(NSNotification.Name.hostsFileCreated.rawValue, "HostsFileCreatedNotification")
        XCTAssertEqual(NSNotification.Name.hostsFileRemoved.rawValue, "HostsFileRemovedNotification")
        XCTAssertEqual(NSNotification.Name.hostsFileRenamed.rawValue, "HostsFileRenamedNotification")
        XCTAssertEqual(NSNotification.Name.hostsFileSaved.rawValue, "HostsFileSavedNotification")
        XCTAssertEqual(NSNotification.Name.hostsNodeNeedsUpdate.rawValue, "HostsNodeNeedsUpdateNotification")
        XCTAssertEqual(NSNotification.Name.hostsFileShouldBeRenamed.rawValue, "HostsFileShouldBeRenamedNotification")
        XCTAssertEqual(NSNotification.Name.hostsFileShouldBeSelected.rawValue, "HostsFileShouldBeSelectedNotification")
        XCTAssertEqual(NSNotification.Name.synchronizingStatusChanged.rawValue, "SynchronizingStatusChangedNotification")
        XCTAssertEqual(NSNotification.Name.allHostsFilesLoadedFromDisk.rawValue, "AllHostsFilesLoadedFromDiskNotification")
    }

    // MARK: - Instance Creation

    func testInit_returnsDistinctInstances() {
        let nc = NotificationCenter()
        let a = HostsDataStore(notificationCenter: nc)
        let b = HostsDataStore(notificationCenter: nc)
        XCTAssertFalse(a === b)
    }

    // MARK: - Notification Response

    func testRenameNotification_setsRenamingHosts() {
        let nc = NotificationCenter()
        let store = HostsDataStore(notificationCenter: nc)

        let hosts = Hosts(path: "/tmp/test.hst")!
        store.renamingHosts = nil

        nc.post(name: .hostsFileShouldBeRenamed, object: hosts)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertTrue(store.renamingHosts === hosts)
    }

    func testSelectNotification_updatesSelectedHosts() {
        let nc = NotificationCenter()
        let store = HostsDataStore(notificationCenter: nc)

        let hosts = Hosts(path: "/tmp/test.hst")!
        store.selectedHosts = nil

        nc.post(name: .hostsFileShouldBeSelected, object: hosts)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertTrue(store.selectedHosts === hosts)
    }

    // MARK: - Busy State

    func testBusyNotification_setsIsBusy() {
        let nc = NotificationCenter()
        let store = HostsDataStore(notificationCenter: nc)
        XCTAssertFalse(store.isBusy, "precondition")

        nc.post(name: .threadBusy, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertTrue(store.isBusy)
    }

    func testNotBusyNotification_clearsIsBusy() {
        let nc = NotificationCenter()
        let store = HostsDataStore(notificationCenter: nc)

        nc.post(name: .threadBusy, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertTrue(store.isBusy, "precondition")

        nc.post(name: .threadNotBusy, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertFalse(store.isBusy)
    }

    // MARK: - Row Refresh Token

    func testRowRefreshToken_incrementsOnHostsNodeNeedsUpdate() {
        let nc = NotificationCenter()
        let store = HostsDataStore(notificationCenter: nc)
        let before = store.rowRefreshToken

        nc.post(name: .hostsNodeNeedsUpdate, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertEqual(store.rowRefreshToken, before &+ 1)
    }

    func testRowRefreshToken_incrementsOnHostsFileSaved() {
        let nc = NotificationCenter()
        let store = HostsDataStore(notificationCenter: nc)
        let before = store.rowRefreshToken

        nc.post(name: .hostsFileSaved, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertEqual(store.rowRefreshToken, before &+ 1)
    }

    func testRowRefreshToken_incrementsOnSynchronizingStatusChanged() {
        let nc = NotificationCenter()
        let store = HostsDataStore(notificationCenter: nc)
        let before = store.rowRefreshToken

        nc.post(name: .synchronizingStatusChanged, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertEqual(store.rowRefreshToken, before &+ 1)
    }

    func testRowRefreshToken_doesNotChangeOnUnrelatedNotification() {
        let nc = NotificationCenter()
        let store = HostsDataStore(notificationCenter: nc)
        let before = store.rowRefreshToken

        nc.post(name: .hostsFileCreated, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertEqual(store.rowRefreshToken, before)
    }
}
