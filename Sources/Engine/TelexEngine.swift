import Foundation

public final class TelexEngine: InputEngine {
    public var useModernOrthography: Bool = true
    var buffer = TypingBuffer()

    // Vowel position state — set by findAndCalculateVowel (ported from Engine.cpp globals VSI/VEI/vowelCount)
    var vowelStartIndex = 0
    var vowelEndIndex   = 0
    var vowelCount      = 0

    // VWSM — vowelWillSetMark: index where the tone mark will be placed (Engine.cpp global)
    var vowelWillSetMark = 0

    public init() {}

    public func newSession() { buffer.reset() }

    public func handle(key: UInt16, caps: Bool) -> EngineOutput {
        if Self.breakCodes.contains(key) {
            newSession()
            return EngineOutput(backspaceCount: 0, newChars: [], action: .wordBreak)
        }

        // Route mark keys s/f/r/x/j BEFORE plain insertKey — mirror handleMainKey mark branch
        // (Engine.cpp:1104-1142).
        if isMarkKey(key) && buffer.index > 0 {
            let markMask: UInt32
            switch key {
            case KeyCode.s: markMask = EngineMask.mark1
            case KeyCode.f: markMask = EngineMask.mark2
            case KeyCode.r: markMask = EngineMask.mark3
            case KeyCode.x: markMask = EngineMask.mark4
            case KeyCode.j: markMask = EngineMask.mark5
            default: return insertKey(key, caps: caps)
            }
            for group in vowelForMark {
                let patterns = group.patterns
                for l in 0..<patterns.count {
                    if buffer.index < patterns[l].count { continue }
                    if checkCorrectVowel(patterns: patterns, patternIdx: l, markKey: key) {
                        let markOutput = insertMark(markMask)
                        // Engine.cpp:1512-1514: if vRestore, also insertKey(trigger key)
                        if markOutput.action == .restore {
                            let keyOut = insertKey(key, caps: caps)
                            return EngineOutput(
                                backspaceCount: markOutput.backspaceCount,
                                newChars: markOutput.newChars + keyOut.newChars,
                                action: .passthrough)
                        }
                        return markOutput
                    }
                }
            }
            // No vowel pattern matched — fall through to insertKey
            return insertKey(key, caps: caps)
        }

        return insertKey(key, caps: caps)
    }

    func insertKey(_ key: UInt16, caps: Bool) -> EngineOutput {
        guard buffer.index < TypingBuffer.maxBuff else {
            return EngineOutput(backspaceCount: 0, newChars: [], action: .passthrough)
        }
        let keyWithCaps = UInt32(key) | (caps ? EngineMask.caps : 0)
        buffer[buffer.index] = keyWithCaps
        buffer.index += 1
        let ch = UInt16(keyCodeToCharacter(keyWithCaps))
        let scalars: [Unicode.Scalar] = ch != 0 ? (Unicode.Scalar(ch).map { [$0] } ?? []) : []
        return EngineOutput(backspaceCount: 0, newChars: scalars, action: .passthrough)
    }

    static let breakCodes: Set<UInt16> = [
        KeyCode.esc, KeyCode.tab, KeyCode.enter, KeyCode.ret, KeyCode.left, KeyCode.right,
        KeyCode.down, KeyCode.up, KeyCode.comma, KeyCode.dot, KeyCode.slash, KeyCode.semicolon,
        KeyCode.quote, KeyCode.backSlash, KeyCode.minus, KeyCode.equals, KeyCode.backquote, KeyCode.space
    ]

    // Stub — full implementation in Task 10.
    public func backspace() -> EngineOutput { .none }

    // MARK: - Vowel detection (Engine.cpp:560-585)

    // MARK: - Mark key routing helpers

    /// Returns true for Telex tone-mark keys s/f/r/x/j (Engine.cpp IS_MARK_KEY for Telex).
    private func isMarkKey(_ key: UInt16) -> Bool {
        key == KeyCode.s || key == KeyCode.f || key == KeyCode.r ||
        key == KeyCode.x || key == KeyCode.j
    }

    /// Port of checkCorrectVowel (Engine.cpp:468-499).
    /// Matches `patterns[patternIdx]` against the buffer's tail (right-to-left).
    /// Returns true if the current buffer ends with that pattern.
    /// vQuickEndConsonant defaults to false (not yet ported) — END_CONSONANT_MASK patterns
    /// are compared verbatim, so they only match if the buffer also carries that bit (it won't
    /// for normal typing, making those entries no-ops until QuickEndConsonant is ported).
    private func checkCorrectVowel(patterns: [[UInt16]], patternIdx l: Int, markKey: UInt16) -> Bool {
        // ignore "qu" case
        if buffer.index >= 2 &&
           buffer[buffer.index - 1].cellKeyCode == KeyCode.u &&
           buffer[buffer.index - 2].cellKeyCode == KeyCode.q {
            return false
        }
        let pattern = patterns[l]
        var k = buffer.index - 1
        var j = pattern.count - 1
        while j >= 0 {
            // vQuickEndConsonant=0: do NOT strip END_CONSONANT_MASK before comparing
            if pattern[j] != buffer[k].cellKeyCode {
                return false
            }
            k -= 1
            j -= 1
            if k < 0 { break }
        }
        // Limit mark for end consonant: f/x/r cannot apply to syllables ending with C or T
        // (Engine.cpp:486-492)
        if pattern.count > 1 &&
           (markKey == KeyCode.f || markKey == KeyCode.x || markKey == KeyCode.r) {
            if pattern[1] == KeyCode.c || pattern[1] == KeyCode.t {
                return false
            }
            if pattern.count > 2 && pattern[2] == KeyCode.t {
                return false
            }
        }
        // If the pattern did not consume the entire buffer, the char just before
        // the pattern must differ from the first pattern char (Engine.cpp:494-498)
        if k >= 0 && buffer[k].cellKeyCode == buffer[k + 1].cellKeyCode {
            return false
        }
        return true
    }

    // MARK: - canHasEndConsonant (Engine.cpp:612-627)

    /// Returns true when the current vowel cluster (VSI..VEI) can legally precede an end consonant,
    /// using the vowelCombine table to identify the vowel sequence.
    private func canHasEndConsonant() -> Bool {
        let vsi = vowelStartIndex
        let vei = vowelEndIndex
        guard let patterns = vowelCombine[buffer[vsi].cellKeyCode] else { return false }
        for row in patterns {
            // row[0] = canHasEndConsonant flag (1/0); row[1..] = key codes with optional tone bits
            var kk = vsi
            var iii = 1
            while iii < row.count {
                let cellVal = UInt32(buffer[kk].cellKeyCode)
                              | (buffer[kk] & EngineMask.tone)
                              | (buffer[kk] & EngineMask.toneW)
                if kk > vei || cellVal != row[iii] {
                    break
                }
                kk += 1
                iii += 1
            }
            if iii >= row.count {
                return row[0] == 1
            }
        }
        return false
    }

    // MARK: - Modern/classic mark placement (Engine.cpp:629-751)

    /// Port of handleModernMark (Engine.cpp:629-725).
    /// Classic Vietnamese placement (C++ name is misleading — see comments in Engine.h).
    /// Called when useModernOrthography == false.
    private func handleModernMark(vwsm: inout Int, hBPC: inout Int) {
        let vsi = vowelStartIndex
        let vei = vowelEndIndex
        let idx = buffer.index

        // default
        vwsm = vei
        hBPC = idx - vei

        // rule 2
        if vowelCount == 3 &&
           ((buffer[vsi].cellKeyCode == KeyCode.o && buffer[vsi+1].cellKeyCode == KeyCode.a && buffer[vsi+2].cellKeyCode == KeyCode.i) ||
            (buffer[vsi].cellKeyCode == KeyCode.u && buffer[vsi+1].cellKeyCode == KeyCode.y && buffer[vsi+2].cellKeyCode == KeyCode.u) ||
            (buffer[vsi].cellKeyCode == KeyCode.o && buffer[vsi+1].cellKeyCode == KeyCode.e && buffer[vsi+2].cellKeyCode == KeyCode.o) ||
            (buffer[vsi].cellKeyCode == KeyCode.u && buffer[vsi+1].cellKeyCode == KeyCode.y && buffer[vsi+2].cellKeyCode == KeyCode.a)) {
            vwsm = vsi + 1
            hBPC = idx - vwsm
        } else if (buffer[vsi].cellKeyCode == KeyCode.o && buffer[vsi+1].cellKeyCode == KeyCode.i) ||
                  (buffer[vsi].cellKeyCode == KeyCode.a && buffer[vsi+1].cellKeyCode == KeyCode.i) ||
                  (buffer[vsi].cellKeyCode == KeyCode.u && buffer[vsi+1].cellKeyCode == KeyCode.i) {
            vwsm = vsi
            hBPC = idx - vwsm
        } else if vei >= 1 && buffer[vei-1].cellKeyCode == KeyCode.a && buffer[vei].cellKeyCode == KeyCode.y {
            vwsm = vei - 1
            hBPC = (idx - vei) + 1
        } else if buffer[vsi].cellKeyCode == KeyCode.u && buffer[vsi+1].cellKeyCode == KeyCode.o {
            vwsm = vsi + 1
            hBPC = idx - vwsm
        } else if buffer[vsi+1].cellKeyCode == KeyCode.o || buffer[vsi+1].cellKeyCode == KeyCode.u {
            vwsm = vei - 1
            hBPC = (idx - vei) + 1
        } else if buffer[vsi].cellKeyCode == KeyCode.o || buffer[vsi].cellKeyCode == KeyCode.u {
            vwsm = vei
            hBPC = idx - vei
        }

        // rule 3.1 — checks for IE/YE/UO/UOWO patterns (verbatim, including C++ dead-code)
        if (buffer[vsi].cellKeyCode == KeyCode.i &&
            (buffer[vsi+1] & (UInt32(KeyCode.e) | EngineMask.tone)) != 0) ||
           (buffer[vsi].cellKeyCode == KeyCode.y &&
            (buffer[vsi+1] & (UInt32(KeyCode.e) | EngineMask.tone)) != 0) ||
           (buffer[vsi].cellKeyCode == KeyCode.u &&
            buffer[vsi+1] == (UInt32(KeyCode.o) | EngineMask.tone)) ||
           (buffer[vsi] == (UInt32(KeyCode.u) | EngineMask.toneW) &&
            buffer[vsi+1] == (UInt32(KeyCode.o) | EngineMask.toneW)) {
            if vsi + 2 < idx {
                let c2 = buffer[vsi+2].cellKeyCode
                if c2 == KeyCode.p || c2 == KeyCode.t || c2 == KeyCode.m || c2 == KeyCode.n ||
                   c2 == KeyCode.o || c2 == KeyCode.u || c2 == KeyCode.i || c2 == KeyCode.c ||
                   // verbatim C++ dead-code: CHR(VSI+2)==KEY_C && CHR(VSI+2)==KEY_H (always false)
                   (vsi+3 < idx && buffer[vsi+2].cellKeyCode == KeyCode.c && buffer[vsi+2].cellKeyCode == KeyCode.h) ||
                   (vsi+3 < idx && buffer[vsi+2].cellKeyCode == KeyCode.n && buffer[vsi+2].cellKeyCode == KeyCode.h) ||
                   (vsi+3 < idx && buffer[vsi+2].cellKeyCode == KeyCode.n && buffer[vsi+2].cellKeyCode == KeyCode.g) {
                    vwsm = vsi + 1
                    hBPC = idx - vwsm
                } else {
                    vwsm = vsi
                    hBPC = idx - vwsm
                }
            } else {
                vwsm = vsi
                hBPC = idx - vwsm
            }
        } else if
            // rule 3.2 — verbatim C++ dead-code for IA/YA/UA conditions
            (buffer[vsi].cellKeyCode == KeyCode.i && buffer[vsi].cellKeyCode == KeyCode.a) ||
            (buffer[vsi].cellKeyCode == KeyCode.y && buffer[vsi].cellKeyCode == KeyCode.a) ||
            (buffer[vsi].cellKeyCode == KeyCode.u && buffer[vsi].cellKeyCode == KeyCode.a) ||
            (buffer[vsi].cellKeyCode == KeyCode.u &&
             buffer[vsi+1] == (UInt32(KeyCode.u) | EngineMask.toneW)) {
            vwsm = vsi
            hBPC = idx - vwsm
        }

        // rule 4
        if vowelCount == 2 {
            if (buffer[vsi].cellKeyCode == KeyCode.i && buffer[vsi+1].cellKeyCode == KeyCode.a) ||
               (buffer[vsi].cellKeyCode == KeyCode.i && buffer[vsi+1].cellKeyCode == KeyCode.u) ||
               (buffer[vsi].cellKeyCode == KeyCode.i && buffer[vsi+1].cellKeyCode == KeyCode.o) {
                if vsi == 0 || buffer[vsi-1].cellKeyCode != KeyCode.g {
                    vwsm = vsi
                    hBPC = idx - vwsm
                } else {
                    vwsm = vsi + 1
                    hBPC = idx - vwsm
                }
            } else if buffer[vsi].cellKeyCode == KeyCode.u && buffer[vsi+1].cellKeyCode == KeyCode.a {
                if vsi == 0 || buffer[vsi-1].cellKeyCode != KeyCode.q {
                    if vei + 1 >= idx || !canHasEndConsonant() {
                        vwsm = vsi
                        hBPC = idx - vwsm
                    }
                } else {
                    vwsm = vsi + 1
                    hBPC = idx - vwsm
                }
            } else if buffer[vsi].cellKeyCode == KeyCode.o && buffer[vsi+1].cellKeyCode == KeyCode.o {
                vwsm = vei
                hBPC = idx - vwsm
            }
        }
    }

    /// Port of handleOldMark (Engine.cpp:727-751).
    /// Modern Vietnamese placement (C++ name is misleading).
    /// Called when useModernOrthography == true.
    private func handleOldMark(vwsm: inout Int, hBPC: inout Int) {
        let vsi = vowelStartIndex
        let vei = vowelEndIndex
        let idx = buffer.index

        // default
        if vowelCount == 0 && buffer[vei].cellKeyCode == KeyCode.i {
            vwsm = vei
        } else {
            vwsm = vsi
        }
        hBPC = idx - vwsm

        // rule 2
        if vowelCount == 3 ||
           (vei + 1 < idx && isConsonant(buffer[vei + 1].cellKeyCode) && canHasEndConsonant()) {
            vwsm = vsi + 1
            hBPC = idx - vwsm
        }

        // rule 3
        for ii in vsi...vei {
            let cell = buffer[ii]
            let chr = cell.cellKeyCode
            if (chr == KeyCode.e && (cell & EngineMask.tone) != 0) ||
               (chr == KeyCode.o && (cell & EngineMask.toneW) != 0) {
                vwsm = ii
                hBPC = idx - vwsm
                break
            }
        }
        // hNCC = hBPC is handled by caller
    }

    // MARK: - Output helpers

    /// Convert one TypingWord cell to a displayable Unicode.Scalar.
    /// If getCharacterCode produced a char-code (CHAR_CODE_MASK set) → use the scalar.
    /// Otherwise (raw key code) → convert via keyCodeToCharacter.
    private func cellToScalar(_ data: UInt32) -> Unicode.Scalar? {
        let code = getCharacterCode(data)
        if (code & EngineMask.charCode) != 0 {
            return Unicode.Scalar(UInt16(code & EngineMask.char))
        }
        let ch = keyCodeToCharacter(code)
        return ch != 0 ? Unicode.Scalar(ch) : nil
    }

    // MARK: - insertMark (Engine.cpp:753-806)

    /// Port of insertMark — applies (or toggles off) a tone mark on the vowel cluster.
    /// Returns an EngineOutput with action == .restore when the same mark was already set
    /// (the caller in `handle` must then also call insertKey for the trigger key).
    func insertMark(_ markMask: UInt32, canModifyFlag: Bool = true) -> EngineOutput {
        vowelCount = 0
        // canModifyFlag → sets hCode=vWillProcess (tracked via action in EngineOutput)
        findAndCalculateVowel(forGrammar: false)
        var vwsm = 0
        var hBPC = 0

        // detect mark position
        if vowelCount == 1 {
            vwsm = vowelEndIndex
            hBPC = buffer.index - vowelEndIndex
        } else if vowelCount >= 2 {
            // Swift: useModernOrthography=true → modern Vietnamese standard → handleOldMark
            //        useModernOrthography=false → classic style              → handleModernMark
            // (C++: vUseModernOrthography=0 → handleOldMark; =1 → handleModernMark)
            if useModernOrthography {
                handleOldMark(vwsm: &vwsm, hBPC: &hBPC)
            } else {
                handleModernMark(vwsm: &vwsm, hBPC: &hBPC)
            }
            if (buffer[vowelEndIndex] & EngineMask.tone) != 0 ||
               (buffer[vowelEndIndex] & EngineMask.toneW) != 0 {
                // C++ `#define VWSM vowelWillSetMark` — VWSM and vowelWillSetMark are the
                // SAME variable, so Engine.cpp:772-773 overrides the placement pointer too.
                // hBPC is NOT updated here (C++ doesn't change it either).
                vwsm = vowelEndIndex
                vowelWillSetMark = vowelEndIndex
            }
        }

        let vsi = vowelStartIndex

        // if duplicate same mark → restore (toggle off)
        if (buffer[vwsm] & markMask) != 0 {
            buffer[vwsm] &= ~EngineMask.mark
            // Clear marks across the FULL cluster (Engine.cpp:784-787 loops VSI..<_index)
            // — necessary for correct buffer state even though output only covers hBPC cells.
            for ii in vsi..<buffer.index {
                buffer[ii] &= ~EngineMask.mark
            }
            // Emit newChars only for vwsm..<buffer.index (the last hBPC cells).
            // C++ hNCC = hBPC (line 805) — consumer reads hData[0..hNCC-1] which maps to
            // TypingWord[VWSM..<_index], NOT TypingWord[VSI..<_index].
            var newChars: [Unicode.Scalar] = []
            for ii in vwsm..<buffer.index {
                if let s = cellToScalar(buffer[ii]) { newChars.append(s) }
            }
            return EngineOutput(backspaceCount: hBPC, newChars: newChars, action: .restore)
        } else {
            // add mark: clear any existing mark on VWSM, set new mark; clear marks on others
            buffer[vwsm] &= ~EngineMask.mark
            buffer[vwsm] |= markMask
            var newChars: [Unicode.Scalar] = []
            for ii in vsi..<buffer.index {
                if ii != vwsm {
                    buffer[ii] &= ~EngineMask.mark
                }
                if let s = cellToScalar(buffer[ii]) { newChars.append(s) }
            }
            hBPC = buffer.index - vsi   // override (Engine.cpp:803)
            return EngineOutput(backspaceCount: hBPC, newChars: newChars, action: .passthrough)
        }
    }

    // MARK: - Vowel detection (Engine.cpp:560-585)

    /// Port of IS_CONSONANT macro: returns true if keyCode is not a Vietnamese vowel.
    private func isConsonant(_ keyCode: UInt16) -> Bool {
        return keyCode != KeyCode.a && keyCode != KeyCode.e &&
               keyCode != KeyCode.u && keyCode != KeyCode.y &&
               keyCode != KeyCode.i && keyCode != KeyCode.o
    }

    /// Scans the buffer backwards to locate the vowel cluster, setting
    /// vowelStartIndex (VSI), vowelEndIndex (VEI), vowelCount.
    /// Verbatim port of findAndCalculateVowel (Engine.cpp:560-585).
    func findAndCalculateVowel(forGrammar: Bool) {
        vowelCount      = 0
        vowelStartIndex = 0
        vowelEndIndex   = 0
        var i = buffer.index - 1
        while i >= 0 {
            let chr = buffer[i].cellKeyCode
            if isConsonant(chr) {
                if vowelCount > 0 { break }
            } else {  // is vowel
                if vowelCount == 0 {
                    vowelEndIndex = i
                }
                if !forGrammar {
                    if (i - 1 >= 0 && chr == KeyCode.i && buffer[i - 1].cellKeyCode == KeyCode.g) ||
                       (i - 1 >= 0 && chr == KeyCode.u && buffer[i - 1].cellKeyCode == KeyCode.q) {
                        break
                    }
                }
                vowelStartIndex = i
                vowelCount += 1
            }
            i -= 1
        }
        // August 26th, 2019: don't count "u" at "qu" as a vowel
        if vowelStartIndex - 1 >= 0 &&
           buffer[vowelStartIndex].cellKeyCode == KeyCode.u &&
           buffer[vowelStartIndex - 1].cellKeyCode == KeyCode.q {
            vowelStartIndex += 1
            vowelCount -= 1
        }
    }

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
