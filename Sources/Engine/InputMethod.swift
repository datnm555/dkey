import Foundation

/// Typing method. Mirrors OpenKey's vInputType (DataType.h:34-38); we ship the two
/// common ones. VNI drives the same engine core through a different key mapping.
public enum InputMethod: String, Codable, CaseIterable {
    case telex
    case vni
}
