import Foundation

public final class TelexEngine: InputEngine {
    public var useModernOrthography: Bool = true
    public var inputMethod: InputMethod = .telex
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

        // Route remove-tone key → removeMark (IS_KEY_Z, Engine.cpp:1057-1062)
        // Telex: 'z'; VNI: '0'. If no mark present, fall through to insertKey.
        if isKeyZ(key) {
            let removeOut = removeMark()
            let out = removeOut == .none ? insertKey(key, caps: caps) : removeOut
            return afterMainKey(out, plainInsert: removeOut == .none)
        }

        // Route '[' (KEY_LEFT_BRACKET) → standalone ơ (Engine.cpp:1065-1068)
        // Telex only; in VNI brackets are literal.
        if inputMethod == .telex && key == KeyCode.leftBracket {
            let out = checkForStandaloneChar(key, caps: caps, keyWillReverse: KeyCode.o)
            return afterMainKey(out, plainInsert: out.action == .passthrough)
        }

        // Route ']' (KEY_RIGHT_BRACKET) → standalone ư (Engine.cpp:1070-1073)
        // Telex only; in VNI brackets are literal.
        if inputMethod == .telex && key == KeyCode.rightBracket {
            let out = checkForStandaloneChar(key, caps: caps, keyWillReverse: KeyCode.u)
            return afterMainKey(out, plainInsert: out.action == .passthrough)
        }

        // VNI circumflex/horn/breve (keys 6/7/8). Telex handles a/e/o + w separately below.
        if inputMethod == .vni && (key == KeyCode.n6 || key == KeyCode.n7 || key == KeyCode.n8) {
            return handleVNIAOEW(key: key, caps: caps)
        }

        // Route mark keys (Telex: s/f/r/x/j; VNI: 1-5) BEFORE plain insertKey —
        // mirror handleMainKey mark branch (Engine.cpp:1104-1142).
        if isMarkKey(key) && buffer.index > 0 {
            guard let markMask = markMask(for: key) else {
                return afterMainKey(insertKey(key, caps: caps), plainInsert: true)
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
                                action: .restore)
                        }
                        // vWillProcess (mark added) → per-key checkGrammar(0)
                        return afterMainKey(markOutput, plainInsert: false)
                    }
                }
            }
            // No vowel pattern matched — fall through to insertKey (vDoNothing)
            return afterMainKey(insertKey(key, caps: caps), plainInsert: true)
        }

        // Route 'w' key → horn/breve via insertW (if vowel pattern matched) or standalone ư.
        // Mirror handleMainKey IS_KEY_W branch (Engine.cpp:1169-1191).
        if key == KeyCode.w {
            let patterns = vowel[KeyCode.w] ?? []
            var wMatched = false
            for l in 0..<patterns.count {
                if buffer.index < patterns[l].count { continue }
                if buffer.index > 0 && checkCorrectVowel(patterns: patterns, patternIdx: l, markKey: key) {
                    wMatched = true
                    let wOut = insertW(caps: caps)
                    // insertW multi-vowel "don't do anything" → fall through to standalone
                    if wOut.action == .passthrough { break }
                    // insertW vRestore → also output current key (Engine.cpp:1512-1514)
                    if wOut.action == .restore {
                        let keyOut = insertKey(key, caps: caps)
                        return EngineOutput(
                            backspaceCount: wOut.backspaceCount,
                            newChars: wOut.newChars + keyOut.newChars,
                            action: .restore)
                    }
                    // vWillProcess (horn/breve applied) → per-key checkGrammar(0)
                    return afterMainKey(wOut, plainInsert: false)
                }
            }
            // No pattern matched or insertW said "don't do anything" → standalone
            _ = wMatched  // consumed
            let out = checkForStandaloneChar(key, caps: caps, keyWillReverse: KeyCode.u)
            return afterMainKey(out, plainInsert: out.action == .passthrough)
        }

        // Route đ key → insertD (Telex: dd→đ; VNI: d9→đ) — mirror handleMainKey IS_KEY_D branch
        // (Engine.cpp:1076-1101).
        if isKeyD(key) {
            var isChanged = false
            for l in 0..<consonantD.count {
                if buffer.index < consonantD[l].count { continue }
                var isCorect = checkCorrectVowel(patterns: consonantD, patternIdx: l, markKey: key)

                // Allow d after a preceding consonant (Engine.cpp:1087-1089).
                if !isCorect &&
                   buffer.index >= 2 &&
                   buffer[buffer.index - 1].cellKeyCode == KeyCode.d &&
                   isConsonant(buffer[buffer.index - 2].cellKeyCode) {
                    isCorect = true
                }

                if isCorect {
                    isChanged = true
                    let dOut = insertD(caps: caps)
                    // On restore, Engine.cpp:1512-1513 also calls insertKey(trigger key).
                    if dOut.action == .restore {
                        let keyOut = insertKey(key, caps: caps)
                        return EngineOutput(
                            backspaceCount: dOut.backspaceCount,
                            newChars: dOut.newChars + keyOut.newChars,
                            action: .restore)
                    }
                    return dOut
                }
            }
            if !isChanged {
                return insertKey(key, caps: caps)
            }
        }

        // Route double keys a/e/o for circumflex (insertAOE) — mirror handleMainKey vowel branch
        // (Engine.cpp:1154-1168, IS_KEY_DOUBLE).
        if isDoubleKey(key) && buffer.index > 0 {
            let patterns = vowel[key] ?? []
            for l in 0..<patterns.count {
                if buffer.index < patterns[l].count { continue }
                if checkCorrectVowel(patterns: patterns, patternIdx: l, markKey: key) {
                    let aoeOut = insertAOE(key, caps: caps)
                    // Restore + key != o: OS passes through the key (tempDisableKey=true).
                    // Mirror with insertKey so the literal character is appended.
                    // For KEY_O the C++ does NOT set tempDisableKey ("case thoòng").
                    if aoeOut.action == .restore && key != KeyCode.o {
                        let keyOut = insertKey(key, caps: caps)
                        return EngineOutput(
                            backspaceCount: aoeOut.backspaceCount,
                            newChars: aoeOut.newChars + keyOut.newChars,
                            action: .restore)
                    }
                    // vWillProcess (circumflex applied; or KEY_O "thoòng" restore which the
                    // C++ does NOT pass through) → per-key checkGrammar(0)
                    return afterMainKey(aoeOut, plainInsert: false)
                }
            }
            // No vowel pattern matched — fall through to insertKey
        }

        // Plain literal key (vDoNothing) → per-key checkGrammar(-1)
        return afterMainKey(insertKey(key, caps: caps), plainInsert: true)
    }

    /// After a main key (non-break, non-d), C++ runs checkGrammar (Engine.cpp:1504-1510),
    /// which re-places the tone mark when the vowel/consonant structure changed as the word
    /// grew (e.g. typing the final consonant after the tone). The delta mirrors C++:
    ///   • plainInsert (hCode==vDoNothing): checkGrammar(-1) — the just-typed literal is in the
    ///     buffer but was not yet on the previous screen, so one fewer backspace.
    ///   • transform   (hCode==vWillProcess): checkGrammar(0) — the trigger key added no buffer
    ///     cell, so the on-screen cluster length equals (index - VSI).
    /// When checkGrammar re-arranges, its full-cluster redraw REPLACES the key's own output,
    /// mirroring how C++ overwrites hBPC/hNCC/hData/hExt (Engine.cpp:334-346). The restore
    /// (vRestore) paths are handled inline before this is reached and intentionally skip
    /// checkGrammar: a toggle-off removes the mark, so the re-placement loop is a no-op.
    private func afterMainKey(_ keyOut: EngineOutput, plainInsert: Bool) -> EngineOutput {
        if let regrammar = checkGrammar(plainInsert ? -1 : 0) {
            return regrammar
        }
        return keyOut
    }

    // MARK: - insertW (Engine.cpp:871-984)

    /// Port of insertW — applies (or toggles off) horn/breve diacritic.
    /// For multi-vowel clusters handles uo/ua/ui/uu/oi/io/oa vowel-pair rules.
    /// For single-vowel scans backward from buffer tail to VSI, toggling TONEW on a/u/o.
    /// Returns action == .restore when toggling off (caller in handle must then also
    /// call insertKey for the trigger key, mirroring C++ vRestore passthrough).
    /// Returns action == .passthrough when multi-vowel pair is unrecognised (caller
    /// falls through to checkForStandaloneChar, mirroring C++ isChanged=false path).
    func insertW(caps: Bool) -> EngineOutput {
        var isRestoredW = false

        findAndCalculateVowel(forGrammar: false)

        // Remove TONE_MASK from vowel cluster (Engine.cpp:877-879)
        if vowelCount > 0 {
            for ii in vowelStartIndex...vowelEndIndex {
                buffer[ii] &= ~EngineMask.tone
            }
        }

        let vsi = vowelStartIndex
        let idx = buffer.index

        // Multi-vowel branch (Engine.cpp:881-933)
        if vowelCount > 1 {
            let hBPC = idx - vsi

            let firstHasToneW  = (buffer[vsi] & EngineMask.toneW) != 0
            let secondHasToneW = (buffer[vsi + 1] & EngineMask.toneW) != 0
            let secondIsI      = buffer[vsi + 1].cellKeyCode == KeyCode.i
            let secondIsA      = buffer[vsi + 1].cellKeyCode == KeyCode.a

            if (firstHasToneW && secondHasToneW) ||
               (firstHasToneW && secondIsI) ||
               (firstHasToneW && secondIsA) {
                // Restore: clear all TONEW (Engine.cpp:889-895)
                isRestoredW = true
                for ii in vsi..<idx {
                    buffer[ii] &= ~EngineMask.toneW
                }
                var newChars: [Unicode.Scalar] = []
                for ii in vsi..<idx {
                    // C++ stores raw TypingWord (no STANDALONE) for restore char
                    let cell = buffer[ii] & ~EngineMask.standalone
                    if let s = cellToScalar(cell) { newChars.append(s) }
                }
                return EngineOutput(backspaceCount: hBPC, newChars: newChars, action: .restore)
            }

            // Determine which position(s) get TONEW (Engine.cpp:898-930)
            let chr0 = buffer[vsi].cellKeyCode
            let chr1 = buffer[vsi + 1].cellKeyCode

            if chr0 == KeyCode.u && chr1 == KeyCode.o {
                // UO: context-sensitive (Engine.cpp:900-911)
                if vsi - 2 >= 0 &&
                   buffer[vsi - 2] == UInt32(KeyCode.t) &&
                   buffer[vsi - 1] == UInt32(KeyCode.h) {
                    buffer[vsi + 1] |= EngineMask.toneW
                    if vsi + 2 < idx && buffer[vsi + 2].cellKeyCode == KeyCode.n {
                        buffer[vsi] |= EngineMask.toneW
                    }
                } else if vsi - 1 >= 0 && buffer[vsi - 1] == UInt32(KeyCode.q) {
                    buffer[vsi + 1] |= EngineMask.toneW
                } else {
                    buffer[vsi] |= EngineMask.toneW
                    buffer[vsi + 1] |= EngineMask.toneW
                }
            } else if (chr0 == KeyCode.u && chr1 == KeyCode.a) ||
                      (chr0 == KeyCode.u && chr1 == KeyCode.i) ||
                      (chr0 == KeyCode.u && chr1 == KeyCode.u) ||
                      (chr0 == KeyCode.o && chr1 == KeyCode.i) {
                buffer[vsi] |= EngineMask.toneW
            } else if (chr0 == KeyCode.i && chr1 == KeyCode.o) ||
                      (chr0 == KeyCode.o && chr1 == KeyCode.a) {
                buffer[vsi + 1] |= EngineMask.toneW
            } else {
                // Don't do anything (Engine.cpp:921-924) — caller falls to standalone
                return EngineOutput(backspaceCount: 0, newChars: [], action: .passthrough)
            }

            var newChars: [Unicode.Scalar] = []
            for ii in vsi..<idx {
                if let s = cellToScalar(buffer[ii]) { newChars.append(s) }
            }
            return EngineOutput(backspaceCount: hBPC, newChars: newChars, action: .process)
        }

        // Single-vowel branch (Engine.cpp:935-983)
        // hCode = vWillProcess, hBPC = 0
        var hBPC = 0
        var ii = idx - 1
        while ii >= 0 {
            if ii < vsi { break }
            hBPC += 1
            let chr = buffer[ii].cellKeyCode
            switch chr {
            case KeyCode.a, KeyCode.u, KeyCode.o:
                if (buffer[ii] & EngineMask.toneW) != 0 {
                    // Already has TONEW → toggle off (Engine.cpp:948-966)
                    if (buffer[ii] & EngineMask.standalone) != 0 {
                        // Standalone case
                        if chr == KeyCode.u {
                            // ư (standalone) → restore to 'w' key, hCode=vWillProcess
                            buffer[ii] = UInt32(KeyCode.w) |
                                         (buffer[ii].cellHasCaps ? EngineMask.caps : 0)
                        } else if chr == KeyCode.o {
                            // ơ (standalone) → restore to 'o', hCode=vRestore
                            isRestoredW = true
                            buffer[ii] = UInt32(KeyCode.o) |
                                         (buffer[ii].cellHasCaps ? EngineMask.caps : 0)
                        }
                        // tempDisableKey = true in C++ (no Swift equivalent needed here)
                    } else {
                        // Regular toggle off, hCode=vRestore
                        isRestoredW = true
                        buffer[ii] &= ~EngineMask.toneW
                    }
                } else {
                    // Add TONEW (Engine.cpp:967-970)
                    buffer[ii] |= EngineMask.toneW
                    buffer[ii] &= ~EngineMask.tone
                }
            default:
                break  // consonants: output as-is (Engine.cpp:974-976)
            }
            ii -= 1
        }

        let startIdx = idx - hBPC
        var newChars: [Unicode.Scalar] = []
        for i in startIdx..<idx {
            if let s = cellToScalar(buffer[i]) { newChars.append(s) }
        }

        return EngineOutput(
            backspaceCount: hBPC,
            newChars: newChars,
            action: isRestoredW ? .restore : .process
        )
    }

    // MARK: - reverseLastStandaloneChar (Engine.cpp:986-993)

    /// Port of reverseLastStandaloneChar — overwrites buffer[index-1] with the
    /// standalone form of keyCode (TONEW | STANDALONE set). Returns EngineOutput
    /// with 0 backspaces and 1 new char (hBPC=0, hNCC=1 in C++).
    private func reverseLastStandaloneChar(_ keyCode: UInt16, caps: Bool) -> EngineOutput {
        let cell = UInt32(keyCode) | EngineMask.toneW | EngineMask.standalone |
                   (caps ? EngineMask.caps : 0)
        buffer[buffer.index - 1] = cell
        let scalar = cellToScalar(cell)
        return EngineOutput(
            backspaceCount: 0,
            newChars: scalar.map { [$0] } ?? [],
            action: .process
        )
    }

    // MARK: - insertIntoBuffer (C++ insertKey with isCheckSpelling=false, buffer-only)

    /// Inserts a key into the buffer without producing screen output.
    /// Used inside checkForStandaloneChar before reverseLastStandaloneChar.
    private func insertIntoBuffer(_ key: UInt16, caps: Bool) {
        guard buffer.index < TypingBuffer.maxBuff else { return }
        buffer[buffer.index] = UInt32(key) | (caps ? EngineMask.caps : 0)
        buffer.index += 1
    }

    // MARK: - checkForStandaloneChar (Engine.cpp:995-1040)

    /// Port of checkForStandaloneChar — handles standalone w/[/] conversion.
    /// `data` = the typed key (w, [, or ]); `keyWillReverse` = the vowel to stand in
    /// (KEY_O for [, KEY_U for ] and w).
    ///
    /// Logic:
    ///  1. If last buffer cell is keyWillReverse with TONEW → replace with data (toggle off).
    ///  2. If last cell is KEY_U and keyWillReverse==KEY_O → insert KEY_O then standalone ơ.
    ///  3. Empty buffer → insert data (buffer only) + standalone keyWillReverse.
    ///  4. 1-char buffer → standalone unless prefix is in standaloneWbad.
    ///  5. 2-char buffer → standalone only if prefix is in doubleWAllowed.
    ///  6. 3+ chars → plain insertKey.
    func checkForStandaloneChar(_ data: UInt16, caps: Bool, keyWillReverse: UInt16) -> EngineOutput {
        // 1. Toggle off: last char is keyWillReverse with TONEW (Engine.cpp:996-1003)
        if buffer.index > 0 {
            let last = buffer[buffer.index - 1]
            if last.cellKeyCode == keyWillReverse && (last & EngineMask.toneW) != 0 {
                let cell = UInt32(data) | (caps ? EngineMask.caps : 0)
                buffer[buffer.index - 1] = cell
                let scalar = cellToScalar(cell)
                return EngineOutput(
                    backspaceCount: 1,
                    newChars: scalar.map { [$0] } ?? [],
                    action: .process
                )
            }
        }

        // 2. Standalone w → ư followed by '[' (Engine.cpp:1007-1010)
        if buffer.index > 0 &&
           buffer[buffer.index - 1].cellKeyCode == KeyCode.u &&
           keyWillReverse == KeyCode.o {
            insertIntoBuffer(keyWillReverse, caps: caps)
            return reverseLastStandaloneChar(keyWillReverse, caps: caps)
        }

        // 3. Empty buffer (Engine.cpp:1013-1015)
        if buffer.index == 0 {
            insertIntoBuffer(data, caps: caps)
            return reverseLastStandaloneChar(keyWillReverse, caps: caps)
        }

        // 4. One-char buffer (Engine.cpp:1017-1026)
        if buffer.index == 1 {
            let chr = buffer[0].cellKeyCode
            for bad in standaloneWbad {
                if chr == bad {
                    return insertKey(data, caps: caps)
                }
            }
            insertIntoBuffer(data, caps: caps)
            return reverseLastStandaloneChar(keyWillReverse, caps: caps)
        }

        // 5. Two-char buffer (Engine.cpp:1027-1036)
        if buffer.index == 2 {
            let chr0 = buffer[0].cellKeyCode
            let chr1 = buffer[1].cellKeyCode
            for pair in doubleWAllowed {
                if chr0 == pair[0] && chr1 == pair[1] {
                    insertIntoBuffer(data, caps: caps)
                    return reverseLastStandaloneChar(keyWillReverse, caps: caps)
                }
            }
            return insertKey(data, caps: caps)
        }

        // 6. 3+ chars → plain insert (Engine.cpp:1039)
        return insertKey(data, caps: caps)
    }

    // MARK: - insertD (Engine.cpp:808-831)

    /// Port of insertD — applies (or toggles off) the TONE_MASK on the KEY_D cell.
    /// Scans backward from the tail; the first KEY_D cell found is toggled.
    /// • No TONE set  → add TONE (KEY_D|TONE renders as đ via codeTableUnicode).
    /// • TONE already → clear TONE, return action=.restore (caller adds the trigger key).
    func insertD(caps: Bool) -> EngineOutput {
        var hBPC = 0
        var isRestore = false

        // Scan backward to find KEY_D (Engine.cpp:811-829)
        var ii = buffer.index - 1
        while ii >= 0 {
            hBPC += 1
            if buffer[ii].cellKeyCode == KeyCode.d {
                if (buffer[ii] & EngineMask.tone) != 0 {
                    // Toggle off: clear TONE, store raw cell (Engine.cpp:816-819)
                    isRestore = true
                    buffer[ii] &= ~EngineMask.tone
                    // hData[...] = TypingWord[ii]  (raw, not GET — C++ line 818)
                } else {
                    // Set TONE: KEY_D|TONE → đ via codeTableUnicode (Engine.cpp:822-823)
                    buffer[ii] |= EngineMask.tone
                }
                break
            }
            ii -= 1
        }

        let startIdx = buffer.index - hBPC
        var newChars: [Unicode.Scalar] = []
        for idx in startIdx..<buffer.index {
            if let s = cellToScalar(buffer[idx]) { newChars.append(s) }
        }
        return EngineOutput(backspaceCount: hBPC, newChars: newChars,
                            action: isRestore ? .restore : .process)
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

    // MARK: - insertAOE (Engine.cpp:833-869)

    /// Port of insertAOE — applies (or toggles off) circumflex diacritic on a/e/o.
    /// Scans the buffer backwards for the matching vowel key; if already marked with
    /// TONE_MASK, toggles it OFF (restore); otherwise sets TONE_MASK.
    /// Removes TONEW_MASK from the entire vowel cluster before acting (Engine.cpp:837-839).
    /// Returns action == .restore when toggling off (caller in handle must then also
    /// call insertKey for the trigger key, mirroring C++ tempDisableKey passthrough).
    func insertAOE(_ key: UInt16, caps: Bool) -> EngineOutput {
        findAndCalculateVowel(forGrammar: false)

        // Remove TONEW from the vowel cluster (C++ lines 837-839)
        if vowelCount > 0 {
            for ii in vowelStartIndex...vowelEndIndex {
                buffer[ii] &= ~EngineMask.toneW
            }
        }

        var hBPC = 0
        var isRestore = false

        // Scan backwards to find the matching vowel key (C++ lines 844-868)
        var ii = buffer.index - 1
        while ii >= 0 {
            hBPC += 1
            if buffer[ii].cellKeyCode == key {
                if (buffer[ii] & EngineMask.tone) != 0 {
                    // Toggle off (restore) — C++ lines 849-855
                    isRestore = true
                    buffer[ii] &= ~EngineMask.tone
                    // C++ stores raw TypingWord[ii] (not GET) for the restore char
                } else {
                    // Set circumflex — C++ lines 857-860
                    buffer[ii] |= EngineMask.tone
                    buffer[ii] &= ~EngineMask.toneW  // IS_KEY_D check: a/e/o are not d
                }
                break
            }
            ii -= 1
        }

        // Build output left-to-right from the start of the changed range (hBPC chars)
        // C++ hData is RIGHT-TO-LEFT (hData[_index-1-ii]), but Swift newChars is
        // LEFT-TO-RIGHT — both produce the same screen result after backspace apply.
        let startIdx = buffer.index - hBPC
        var newChars: [Unicode.Scalar] = []
        for idx in startIdx..<buffer.index {
            if let s = cellToScalar(buffer[idx]) { newChars.append(s) }
        }

        return EngineOutput(
            backspaceCount: hBPC,
            newChars: newChars,
            action: isRestore ? .restore : .process
        )
    }

    // MARK: - handleVNIAOEW (Engine.cpp:1145-1192, vInputType==vVNI)

    /// VNI 6/7/8 → circumflex/horn/breve. Faithful port of OpenKey vKeyHandleEvent
    /// (Engine.cpp:1145-1192, vInputType==vVNI): scan for the target vowel, compute
    /// keyForAEO, then reuse the shared insertAOE / insertW.
    private func handleVNIAOEW(key: UInt16, caps: Bool) -> EngineOutput {
        // VEI = last O/A/E in the buffer — the circumflex target (Engine.cpp:1145-1152).
        var vei = -1
        for i in stride(from: buffer.index - 1, through: 0, by: -1) {
            let c = buffer[i].cellKeyCode
            if c == KeyCode.o || c == KeyCode.a || c == KeyCode.e { vei = i; break }
        }
        // keyForAEO (Engine.cpp:1154): 7/8 → W; 6 → the vowel at VEI; else the key itself.
        let keyForAEO: UInt16
        if key == KeyCode.n7 || key == KeyCode.n8 {
            keyForAEO = KeyCode.w
        } else if key == KeyCode.n6 {
            keyForAEO = vei >= 0 ? buffer[vei].cellKeyCode : key
        } else {
            keyForAEO = key
        }

        let patterns = vowel[keyForAEO] ?? []
        for l in 0..<patterns.count {
            if buffer.index < patterns[l].count { continue }
            if checkCorrectVowel(patterns: patterns, patternIdx: l, markKey: key) {
                if key == KeyCode.n6 {
                    let out = insertAOE(keyForAEO, caps: caps)
                    if out.action == .restore {
                        let k = insertKey(key, caps: caps)
                        return EngineOutput(backspaceCount: out.backspaceCount,
                                            newChars: out.newChars + k.newChars, action: .restore)
                    }
                    return afterMainKey(out, plainInsert: false)
                } else {
                    // Horn/breve target + guard (Engine.cpp:1170-1179).
                    var vw = -1
                    for j in stride(from: buffer.index - 1, through: 0, by: -1) {
                        let c = buffer[j].cellKeyCode
                        if c == KeyCode.o || c == KeyCode.u || c == KeyCode.a || c == KeyCode.e { vw = j; break }
                    }
                    if vw >= 0 {
                        let cv = buffer[vw].cellKeyCode
                        let prevNotU = vw - 1 >= 0 ? buffer[vw - 1].cellKeyCode != KeyCode.u : true
                        if (key == KeyCode.n7 && cv == KeyCode.a && prevNotU) ||
                           (key == KeyCode.n8 && (cv == KeyCode.o || cv == KeyCode.u)) {
                            break   // blocked → literal digit
                        }
                    }
                    let out = insertW(caps: caps)
                    if out.action == .passthrough { break }
                    if out.action == .restore {
                        let k = insertKey(key, caps: caps)
                        return EngineOutput(backspaceCount: out.backspaceCount,
                                            newChars: out.newChars + k.newChars, action: .restore)
                    }
                    return afterMainKey(out, plainInsert: false)
                }
            }
        }
        // No vowel pattern matched (or guard blocked) → literal digit.
        return afterMainKey(insertKey(key, caps: caps), plainInsert: true)
    }

    static let breakCodes: Set<UInt16> = [
        KeyCode.esc, KeyCode.tab, KeyCode.enter, KeyCode.ret, KeyCode.left, KeyCode.right,
        KeyCode.down, KeyCode.up, KeyCode.comma, KeyCode.dot, KeyCode.slash, KeyCode.semicolon,
        KeyCode.quote, KeyCode.backSlash, KeyCode.minus, KeyCode.equals, KeyCode.backquote, KeyCode.space
    ]

    // MARK: - removeMark (Engine.cpp:587-609)

    /// Port of removeMark — clears all MARK_MASK bits from the vowel cluster (VSI…VEI).
    /// Returns .none when no mark was present (caller falls through to insertKey).
    /// Returns a redraw EngineOutput covering VSI…_index-1 when a mark was removed.
    func removeMark() -> EngineOutput {
        findAndCalculateVowel(forGrammar: true)
        var isChanged = false
        if buffer.index > 0 {
            if vowelStartIndex <= vowelEndIndex {
                for i in vowelStartIndex...vowelEndIndex {
                    if (buffer[i] & EngineMask.mark) != 0 {
                        buffer[i] &= ~EngineMask.mark
                        isChanged = true
                    }
                }
            }
        }
        guard isChanged else { return .none }
        var newChars: [Unicode.Scalar] = []
        for i in vowelStartIndex..<buffer.index {
            if let s = cellToScalar(buffer[i]) { newChars.append(s) }
        }
        return EngineOutput(
            backspaceCount: buffer.index - vowelStartIndex,
            newChars: newChars,
            action: .process
        )
    }

    // MARK: - checkGrammar (Engine.cpp:290-346, tone parts only)

    /// Port of checkGrammar — after a deletion re-places the tone mark on the correct vowel.
    /// Spell-check / KeyStates undo-stack (_stateIndex, vCheckSpelling) are deferred (Phase 1
    /// constant: vCheckSpelling=0), so only the tone-reflow logic is ported.
    /// Returns nil when no re-arrangement was needed; returns the redraw EngineOutput otherwise.
    @discardableResult
    func checkGrammar(_ deltaBackspace: Int) -> EngineOutput? {
        guard buffer.index > 1 && buffer.index < TypingBuffer.maxBuff else { return nil }
        findAndCalculateVowel(forGrammar: true)
        guard vowelCount > 0 else { return nil }

        var isCheckedGrammar = false
        let l = vowelStartIndex       // save before insertMark re-runs findAndCalculateVowel
        let savedVEI = vowelEndIndex  // save for mark-scan loop

        // Fix UO TONEW mismatch: "thuơn"/"ưoi"/"ưom"/"ưoc" (Engine.cpp:302-317)
        if buffer.index >= 3 {
            outer: for i in stride(from: buffer.index - 1, through: 0, by: -1) {
                let chr = buffer[i].cellKeyCode
                if chr == KeyCode.n || chr == KeyCode.c || chr == KeyCode.i ||
                   chr == KeyCode.m || chr == KeyCode.p || chr == KeyCode.t {
                    if i >= 2 &&
                       buffer[i-1].cellKeyCode == KeyCode.o &&
                       buffer[i-2].cellKeyCode == KeyCode.u {
                        if ((buffer[i-1] & EngineMask.toneW) ^ (buffer[i-2] & EngineMask.toneW)) != 0 {
                            buffer[i-2] |= EngineMask.toneW
                            buffer[i-1] |= EngineMask.toneW
                            isCheckedGrammar = true
                            break outer
                        }
                    }
                }
            }
        }

        // Re-place tone mark on the correct vowel (Engine.cpp:320-331)
        if buffer.index >= 2 {
            var i = l
            while i <= savedVEI {
                if (buffer[i] & EngineMask.mark) != 0 {
                    let mark = buffer[i] & EngineMask.mark
                    buffer[i] &= ~EngineMask.mark
                    _ = insertMark(mark, canModifyFlag: false)
                    // vowelWillSetMark is set by insertMark for all vowel-count cases
                    if i != vowelWillSetMark {
                        isCheckedGrammar = true
                    }
                    break
                }
                i += 1
            }
        }

        guard isCheckedGrammar else { return nil }

        // Assemble redraw output (Engine.cpp:334-346)
        // hBPC = (chars from l…_index-1) + deltaBackspace; hNCC = chars from l…_index-1
        var newChars: [Unicode.Scalar] = []
        for i in l..<buffer.index {
            if let s = cellToScalar(buffer[i]) { newChars.append(s) }
        }
        let hNCC = buffer.index - l
        return EngineOutput(
            backspaceCount: hNCC + deltaBackspace,
            newChars: newChars,
            action: .process
        )
    }

    // MARK: - backspace (Engine.cpp:1420-1465, tone parts only)

    /// Port of the KEY_DELETE path in the main key handler.
    /// Decrements buffer.index, then calls checkGrammar(1) to re-place any tone mark
    /// on the surviving vowel cluster.  Spell-check / _stateIndex / _longWordHelper /
    /// _specialChar / _spaceCount handling are all deferred (Phase 1 scope).
    public func backspace() -> EngineOutput {
        guard buffer.index > 0 else { return .none }
        buffer.index -= 1
        if buffer.index == 0 {
            newSession()
            return EngineOutput(backspaceCount: 1, newChars: [], action: .passthrough)
        }
        // checkGrammar(1) — deltaBackspace=1 because one char was just deleted
        if let redrawn = checkGrammar(1) {
            return redrawn
        }
        // No grammar re-arrangement — just tell caller to delete 1 char
        return EngineOutput(backspaceCount: 1, newChars: [], action: .passthrough)
    }

    // MARK: - Vowel detection (Engine.cpp:560-585)

    // MARK: - Mark key routing helpers

    // Which physical key plays each role, per input method.
    // Mirrors OpenKey ProcessingChar[vInputType] (Engine.cpp:35-36):
    //   Telex row uses letters; VNI row: 1-5 tones, 6 circumflex, 7/8 horn/breve, 9 đ, 0 remove.
    private func isKeyZ(_ key: UInt16) -> Bool {   // remove-tone key
        inputMethod == .telex ? key == KeyCode.z : key == KeyCode.n0
    }
    private func isKeyD(_ key: UInt16) -> Bool {   // đ key
        inputMethod == .telex ? key == KeyCode.d : key == KeyCode.n9
    }
    private func markMask(for key: UInt16) -> UInt32? {
        switch inputMethod {
        case .telex:
            switch key {
            case KeyCode.s: return EngineMask.mark1
            case KeyCode.f: return EngineMask.mark2
            case KeyCode.r: return EngineMask.mark3
            case KeyCode.x: return EngineMask.mark4
            case KeyCode.j: return EngineMask.mark5
            default: return nil
            }
        case .vni:
            switch key {
            case KeyCode.n1: return EngineMask.mark1
            case KeyCode.n2: return EngineMask.mark2
            case KeyCode.n3: return EngineMask.mark3
            case KeyCode.n4: return EngineMask.mark4
            case KeyCode.n5: return EngineMask.mark5
            default: return nil
            }
        }
    }

    /// Returns true for tone-mark keys (method-aware).
    private func isMarkKey(_ key: UInt16) -> Bool {
        markMask(for: key) != nil
    }

    /// Returns true for Telex double keys a/e/o (Engine.cpp IS_KEY_DOUBLE for Telex).
    /// These keys double to insert circumflex: aa→â, ee→ê, oo→ô.
    private func isDoubleKey(_ key: UInt16) -> Bool {
        key == KeyCode.a || key == KeyCode.e || key == KeyCode.o
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
        } else {
            // C++ Engine.cpp:767 uses a bare `else` here, so this branch covers BOTH
            // vowelCount >= 2 AND vowelCount == 0. The vowelCount == 0 case occurs for
            // "gi"/"ngi" words: findAndCalculateVowel(forGrammar:false) breaks the 'i' out
            // of the cluster (gi rule), leaving vowelCount == 0 with VEI pointing at the 'i'.
            // handleOldMark/handleModernMark then place the mark on that 'i'
            // (handleOldMark's `vowelCount == 0 && CHR(VEI) == i → vwsm = VEI` rule), giving
            // "gì"/"ngì". Narrowing this to `vowelCount >= 2` dropped the mark onto the
            // preceding consonant (rendered bare) — fixed to match C++.
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
        // Always update vowelWillSetMark (single-vowel case and multi-vowel fallback).
        // Required so that checkGrammar can compare the old mark position with the new one.
        vowelWillSetMark = vwsm

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
            return EngineOutput(backspaceCount: hBPC, newChars: newChars, action: .process)
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
