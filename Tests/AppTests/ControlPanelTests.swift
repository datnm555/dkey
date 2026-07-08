import XCTest
@testable import dkey

final class ControlPanelTests: XCTestCase {
    func testSegmentCountAndLabels() {
        let segs = ControlPanel.inputMethodSegments
        XCTAssertEqual(segs.count, 3)
        XCTAssertEqual(segs.map(\.label), ["Telex", "VNI", "Simple Telex"])
    }

    func testTelexAndVniAreEnabledWithMethod() {
        let segs = ControlPanel.inputMethodSegments
        XCTAssertEqual(segs[0].method, .telex)
        XCTAssertTrue(segs[0].enabled)
        XCTAssertEqual(segs[1].method, .vni)
        XCTAssertTrue(segs[1].enabled)
    }

    func testSimpleTelexIsDisabledPlaceholder() {
        let seg = ControlPanel.inputMethodSegments[2]
        XCTAssertNil(seg.method)
        XCTAssertFalse(seg.enabled)
    }
}
