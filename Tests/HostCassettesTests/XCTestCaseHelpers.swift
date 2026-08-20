import XCTest

extension XCTestCase {
    /// メインキューを N 回ドレインし、DispatchQueue.main.async ブロックが完了するまで待機する。
    /// RunLoop.main.run(until:) の代替。CI 負荷による固定タイムアウト起因のフレイキーさを防ぐ。
    func drainMainQueue(hops: Int = 2, timeout: TimeInterval = 5) {
        let exp = expectation(description: "drainMainQueue(\(hops))")
        func schedule(_ n: Int) {
            if n == 0 { exp.fulfill() } else { DispatchQueue.main.async { schedule(n - 1) } }
        }
        DispatchQueue.main.async { schedule(hops) }
        wait(for: [exp], timeout: timeout)
    }

    /// 条件が真になるまでポーリングして待機する。ウィンドウ生成などの完了確認に使う。
    func waitUntil(_ condition: @escaping () -> Bool, timeout: TimeInterval = 5) {
        let exp = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in condition() },
            object: nil
        )
        wait(for: [exp], timeout: timeout)
    }
}
