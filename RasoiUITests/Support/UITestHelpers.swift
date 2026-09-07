import XCTest

extension XCUIElement {
    /// Waits until the element exists *and* can actually receive a tap.
    ///
    /// `waitForExistence` is not enough on a screen that is still settling: a row can exist while
    /// the list is mid-layout, and tapping it then does nothing at all.
    @discardableResult
    func waitUntilHittable(timeout: TimeInterval = 25) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exists, isHittable { return true }
            _ = waitForExistence(timeout: 0.2)
        }
        return exists && isHittable
    }

    /// Scrolls the given container until this element can be tapped.
    @discardableResult
    func scrollUntilHittable(in container: XCUIElement, maxSwipes: Int = 8) -> Bool {
        if waitUntilHittable(timeout: 2) { return true }
        for _ in 0..<maxSwipes {
            container.swipeUp()
            if exists, isHittable { return true }
        }
        return exists && isHittable
    }

    /// Waits for the element to be tappable, then taps it.
    ///
    /// The failure message is passed in rather than read from the element: asking a missing
    /// element for its identifier throws "Failed to get matching snapshot" and hides the real
    /// problem.
    func waitAndTap(_ what: String, timeout: TimeInterval = 25,
                    file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitUntilHittable(timeout: timeout),
                      "\(what) never became tappable", file: file, line: line)
        tap()
    }
}
