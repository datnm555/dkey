import Foundation

/// OpenKey TypingWord[MAX_BUFF] + _index, with named accessors.
struct TypingBuffer {
    static let maxBuff = 32
    var word = [UInt32](repeating: 0, count: TypingBuffer.maxBuff)
    var index: Int = 0

    mutating func reset() { index = 0 }
    subscript(_ i: Int) -> UInt32 {
        get { word[i] }
        set { word[i] = newValue }
    }
}
