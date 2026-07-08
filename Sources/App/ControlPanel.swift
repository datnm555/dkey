import Foundation

/// Pure model backing the menu-bar popover (screen ②).
enum ControlPanel {
    /// One Kiểu gõ segment. `method == nil` + `enabled == false` marks a
    /// placeholder whose backing feature isn't built yet (Simple Telex).
    struct Segment: Equatable {
        let label: String
        let method: InputMethod?
        let enabled: Bool
    }

    /// Segments for the Kiểu gõ selector: Telex & VNI are live; Simple Telex
    /// is a disabled placeholder (no engine backing yet).
    static var inputMethodSegments: [Segment] {
        [
            Segment(label: "Telex", method: .telex, enabled: true),
            Segment(label: "VNI", method: .vni, enabled: true),
            Segment(label: "Simple Telex", method: nil, enabled: false),
        ]
    }
}
