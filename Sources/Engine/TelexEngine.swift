import Foundation

public final class TelexEngine: InputEngine {
    public var useModernOrthography: Bool = true
    var buffer = TypingBuffer()

    public init() {}

    public func newSession() { buffer.reset() }

    // Stub — full implementation in Task 4.
    public func handle(key: UInt16, caps: Bool) -> EngineOutput { .none }

    // Stub — full implementation in Task 10.
    public func backspace() -> EngineOutput { .none }

    /// Port of OpenKey getCharacterCode (Engine.cpp:501-543), Unicode table only.
    ///
    /// Index math (1-to-1 with C++):
    ///   capsElem = 0 if caps bit set, else 1  (0=uppercase, 1=lowercase)
    ///   markElem = mark_base (0/2/4/6/8 for mark1..5) + capsElem
    ///   For base vowels (a/o/u/e) with no circumflex/horn: markElem += 4
    ///     (marks live at indices 4-13 in the 14-wide base row)
    ///   No-mark path: TONE → row[capsElem], TONEW → row[capsElem+2]
    func getCharacterCode(_ data: UInt32) -> UInt32 {
        let capsElem = (data & EngineMask.caps) != 0 ? 0 : 1
        let key = data & EngineMask.char

        if data.cellHasMark {
            // Determine mark pair base offset (C++ switch on data & MARK_MASK)
            var markElem: Int
            switch data & EngineMask.mark {
            case EngineMask.mark1: markElem = 0
            case EngineMask.mark2: markElem = 2
            case EngineMask.mark3: markElem = 4
            case EngineMask.mark4: markElem = 6
            case EngineMask.mark5: markElem = 8
            default: return data  // invalid/multiple mark bits → pass through
            }
            markElem += capsElem

            // C++ switch(key) case KEY_A/O/U/E: if no TONE and no TONEW → markElem += 4
            switch key {
            case UInt32(KeyCode.a), UInt32(KeyCode.o), UInt32(KeyCode.u), UInt32(KeyCode.e):
                if (data & EngineMask.tone) == 0 && (data & EngineMask.toneW) == 0 {
                    markElem += 4
                }
            default:
                break
            }

            // Build lookup key with diacritic modifier (C++: key |= TONE_MASK / TONEW_MASK)
            var lookupKey = key
            if (data & EngineMask.tone) != 0 {
                lookupKey |= EngineMask.tone
            } else if (data & EngineMask.toneW) != 0 {
                lookupKey |= EngineMask.toneW
            }

            guard let row = codeTableUnicode[lookupKey] else { return data }
            guard markElem >= 0 && markElem < row.count else { return data }
            let scalar = UInt32(row[markElem])
            if scalar == 0 { return data }
            return scalar | EngineMask.charCode

        } else {
            // No mark: look up bare key, return at capsElem (TONE) or capsElem+2 (TONEW)
            guard let row = codeTableUnicode[key] else { return data }

            if (data & EngineMask.tone) != 0 {
                guard capsElem < row.count else { return data }
                let scalar = UInt32(row[capsElem])
                if scalar == 0 { return data }
                return scalar | EngineMask.charCode
            } else if (data & EngineMask.toneW) != 0 {
                let idx = capsElem + 2
                guard idx < row.count else { return data }
                let scalar = UInt32(row[idx])
                if scalar == 0 { return data }
                return scalar | EngineMask.charCode
            } else {
                return data
            }
        }
    }
}
