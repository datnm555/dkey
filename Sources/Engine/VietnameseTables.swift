import Foundation

/// Unicode NFC code table — verbatim port of OpenKey _codeTable[0]
/// (../mkey/Sources/Engine/Vietnamese.cpp:411-429).
let codeTableUnicode: [UInt32: [UInt16]] = [
    UInt32(KeyCode.a): [0x00C2,0x00E2,0x0102,0x0103,0x00C1,0x00E1,0x00C0,0x00E0,0x1EA2,0x1EA3,0x00C3,0x00E3,0x1EA0,0x1EA1],
    UInt32(KeyCode.o): [0x00D4,0x00F4,0x01A0,0x01A1,0x00D3,0x00F3,0x00D2,0x00F2,0x1ECE,0x1ECF,0x00D5,0x00F5,0x1ECC,0x1ECD],
    UInt32(KeyCode.u): [0x0000,0x0000,0x01AF,0x01B0,0x00DA,0x00FA,0x00D9,0x00F9,0x1EE6,0x1EE7,0x0168,0x0169,0x1EE4,0x1EE5],
    UInt32(KeyCode.e): [0x00CA,0x00EA,0x0000,0x0000,0x00C9,0x00E9,0x00C8,0x00E8,0x1EBA,0x1EBB,0x1EBC,0x1EBD,0x1EB8,0x1EB9],
    UInt32(KeyCode.d): [0x0110,0x0111],
    UInt32(KeyCode.a) | EngineMask.tone:  [0x1EA4,0x1EA5,0x1EA6,0x1EA7,0x1EA8,0x1EA9,0x1EAA,0x1EAB,0x1EAC,0x1EAD],
    UInt32(KeyCode.a) | EngineMask.toneW: [0x1EAE,0x1EAF,0x1EB0,0x1EB1,0x1EB2,0x1EB3,0x1EB4,0x1EB5,0x1EB6,0x1EB7],
    UInt32(KeyCode.o) | EngineMask.tone:  [0x1ED0,0x1ED1,0x1ED2,0x1ED3,0x1ED4,0x1ED5,0x1ED6,0x1ED7,0x1ED8,0x1ED9],
    UInt32(KeyCode.o) | EngineMask.toneW: [0x1EDA,0x1EDB,0x1EDC,0x1EDD,0x1EDE,0x1EDF,0x1EE0,0x1EE1,0x1EE2,0x1EE3],
    UInt32(KeyCode.u) | EngineMask.toneW: [0x1EE8,0x1EE9,0x1EEA,0x1EEB,0x1EEC,0x1EED,0x1EEE,0x1EEF,0x1EF0,0x1EF1],
    UInt32(KeyCode.e) | EngineMask.tone:  [0x1EBE,0x1EBF,0x1EC0,0x1EC1,0x1EC2,0x1EC3,0x1EC4,0x1EC5,0x1EC6,0x1EC7],
    UInt32(KeyCode.i): [0x00CD,0x00ED,0x00CC,0x00EC,0x1EC8,0x1EC9,0x0128,0x0129,0x1ECA,0x1ECB],
    UInt32(KeyCode.y): [0x00DD,0x00FD,0x1EF2,0x1EF3,0x1EF6,0x1EF7,0x1EF8,0x1EF9,0x1EF4,0x1EF5],
]

// MARK: - consonantD table (Vietnamese.cpp:170-241)

/// Valid D-initial syllable skeletons — verbatim port of _consonantD (Vietnamese.cpp:170-241).
/// checkCorrectVowel matches these right-to-left against the buffer tail; if matched,
/// insertD fires.  END_CONSONANT_MASK (EC) entries never match during normal typing
/// (vQuickEndConsonant=false, same as C++ default).
let consonantD: [[UInt16]] = {
    let EC = UInt16(EngineMask.endConsonant)
    return [
        [KeyCode.d, KeyCode.e, KeyCode.n, KeyCode.h], [KeyCode.d, KeyCode.e, KeyCode.h | EC],
        [KeyCode.d, KeyCode.e, KeyCode.n, KeyCode.g], [KeyCode.d, KeyCode.e, KeyCode.g | EC],
        [KeyCode.d, KeyCode.e, KeyCode.c, KeyCode.h], [KeyCode.d, KeyCode.e, KeyCode.k | EC],
        [KeyCode.d, KeyCode.e, KeyCode.n],
        [KeyCode.d, KeyCode.e, KeyCode.c],
        [KeyCode.d, KeyCode.e, KeyCode.m],
        [KeyCode.d, KeyCode.e],
        [KeyCode.d, KeyCode.e, KeyCode.t],
        [KeyCode.d, KeyCode.e, KeyCode.u],
        [KeyCode.d, KeyCode.e, KeyCode.o],
        [KeyCode.d, KeyCode.e, KeyCode.p],

        [KeyCode.d, KeyCode.u, KeyCode.n, KeyCode.g], [KeyCode.d, KeyCode.u, KeyCode.g | EC],
        [KeyCode.d, KeyCode.u, KeyCode.n],
        [KeyCode.d, KeyCode.u, KeyCode.m],
        [KeyCode.d, KeyCode.u, KeyCode.c],
        [KeyCode.d, KeyCode.u, KeyCode.o],
        [KeyCode.d, KeyCode.u, KeyCode.a],
        [KeyCode.d, KeyCode.u, KeyCode.o, KeyCode.i],
        [KeyCode.d, KeyCode.u, KeyCode.o, KeyCode.c],
        [KeyCode.d, KeyCode.u, KeyCode.o, KeyCode.n],
        [KeyCode.d, KeyCode.u, KeyCode.o, KeyCode.n, KeyCode.g], [KeyCode.d, KeyCode.u, KeyCode.o, KeyCode.g | EC],
        [KeyCode.d, KeyCode.u],
        [KeyCode.d, KeyCode.u, KeyCode.p],
        [KeyCode.d, KeyCode.u, KeyCode.t],
        [KeyCode.d, KeyCode.u, KeyCode.i],

        [KeyCode.d, KeyCode.i, KeyCode.c, KeyCode.h], [KeyCode.d, KeyCode.i, KeyCode.k | EC],
        [KeyCode.d, KeyCode.i, KeyCode.c],
        [KeyCode.d, KeyCode.i, KeyCode.n, KeyCode.h], [KeyCode.d, KeyCode.i, KeyCode.h | EC],
        [KeyCode.d, KeyCode.i, KeyCode.n],
        [KeyCode.d, KeyCode.i],
        [KeyCode.d, KeyCode.i, KeyCode.a],
        [KeyCode.d, KeyCode.i, KeyCode.e],
        [KeyCode.d, KeyCode.i, KeyCode.e, KeyCode.c],
        [KeyCode.d, KeyCode.i, KeyCode.e, KeyCode.u],
        [KeyCode.d, KeyCode.i, KeyCode.e, KeyCode.n],
        [KeyCode.d, KeyCode.i, KeyCode.e, KeyCode.m],
        [KeyCode.d, KeyCode.i, KeyCode.e, KeyCode.p],
        [KeyCode.d, KeyCode.i, KeyCode.t],

        [KeyCode.d, KeyCode.o],
        [KeyCode.d, KeyCode.o, KeyCode.a],
        [KeyCode.d, KeyCode.o, KeyCode.a, KeyCode.n],
        [KeyCode.d, KeyCode.o, KeyCode.a, KeyCode.n, KeyCode.g], [KeyCode.d, KeyCode.o, KeyCode.a, KeyCode.g | EC],
        [KeyCode.d, KeyCode.o, KeyCode.a, KeyCode.n, KeyCode.h], [KeyCode.d, KeyCode.o, KeyCode.a, KeyCode.h | EC],
        [KeyCode.d, KeyCode.o, KeyCode.a, KeyCode.m],
        [KeyCode.d, KeyCode.o, KeyCode.e],
        [KeyCode.d, KeyCode.o, KeyCode.i],
        [KeyCode.d, KeyCode.o, KeyCode.p],
        [KeyCode.d, KeyCode.o, KeyCode.c],
        [KeyCode.d, KeyCode.o, KeyCode.n],
        [KeyCode.d, KeyCode.o, KeyCode.n, KeyCode.g], [KeyCode.d, KeyCode.o, KeyCode.g | EC],
        [KeyCode.d, KeyCode.o, KeyCode.m],
        [KeyCode.d, KeyCode.o, KeyCode.t],

        [KeyCode.d, KeyCode.a],
        [KeyCode.d, KeyCode.a, KeyCode.t],
        [KeyCode.d, KeyCode.a, KeyCode.y],
        [KeyCode.d, KeyCode.a, KeyCode.u],
        [KeyCode.d, KeyCode.a, KeyCode.i],
        [KeyCode.d, KeyCode.a, KeyCode.o],
        [KeyCode.d, KeyCode.a, KeyCode.p],
        [KeyCode.d, KeyCode.a, KeyCode.c],
        [KeyCode.d, KeyCode.a, KeyCode.c, KeyCode.h], [KeyCode.d, KeyCode.a, KeyCode.k | EC],
        [KeyCode.d, KeyCode.a, KeyCode.n],
        [KeyCode.d, KeyCode.a, KeyCode.n, KeyCode.h], [KeyCode.d, KeyCode.a, KeyCode.h | EC],
        [KeyCode.d, KeyCode.a, KeyCode.n, KeyCode.g], [KeyCode.d, KeyCode.a, KeyCode.g | EC],
        [KeyCode.d, KeyCode.a, KeyCode.m],

        [KeyCode.d],
    ]
}()

// MARK: - Horn/breve standalone tables (Vietnamese.cpp:375-389)

/// Characters after which a standalone w/[/] is disallowed (1-char prefix).
/// Verbatim port of _standaloneWbad (Vietnamese.cpp:375-377).
let standaloneWbad: [UInt16] = [
    KeyCode.w, KeyCode.e, KeyCode.y, KeyCode.f, KeyCode.j, KeyCode.k, KeyCode.z
]

/// Two-character prefixes that allow a standalone w/[/] to follow.
/// Verbatim port of _doubleWAllowed (Vietnamese.cpp:379-389).
let doubleWAllowed: [[UInt16]] = [
    [KeyCode.t, KeyCode.r],
    [KeyCode.t, KeyCode.h],
    [KeyCode.c, KeyCode.h],
    [KeyCode.n, KeyCode.h],
    [KeyCode.n, KeyCode.g],
    [KeyCode.k, KeyCode.h],
    [KeyCode.g, KeyCode.i],
    [KeyCode.p, KeyCode.h],
    [KeyCode.g, KeyCode.h],
]

// MARK: - Vowel pattern tables (Vietnamese.cpp:19-97, 99-168)

/// Vowel pattern table — verbatim port of OpenKey _vowel (Vietnamese.cpp:19-97).
/// Key = first vowel key code; value = list of syllable-final vowel+consonant patterns.
/// END_CONSONANT_MASK (0x4000) is OR'd directly into UInt16 key codes as in C++.
let vowel: [UInt16: [[UInt16]]] = {
    let EC = UInt16(EngineMask.endConsonant)   // 0x4000
    return [
        KeyCode.a: [
            [KeyCode.a, KeyCode.n, KeyCode.g], [KeyCode.a, KeyCode.g | EC],
            [KeyCode.a, KeyCode.n],
            [KeyCode.a, KeyCode.m],
            [KeyCode.a, KeyCode.u],
            [KeyCode.a, KeyCode.y],
            [KeyCode.a, KeyCode.t],
            [KeyCode.a, KeyCode.p],
            [KeyCode.a],
            [KeyCode.a, KeyCode.c],
        ],
        KeyCode.o: [
            [KeyCode.o, KeyCode.n, KeyCode.g], [KeyCode.o, KeyCode.g | EC],
            [KeyCode.o, KeyCode.n],
            [KeyCode.o, KeyCode.m],
            [KeyCode.o, KeyCode.i],
            [KeyCode.o, KeyCode.c],
            [KeyCode.o, KeyCode.t],
            [KeyCode.o, KeyCode.p],
            [KeyCode.o],
        ],
        KeyCode.e: [
            [KeyCode.e, KeyCode.n, KeyCode.h], [KeyCode.e, KeyCode.h | EC],
            [KeyCode.e, KeyCode.n, KeyCode.g], [KeyCode.e, KeyCode.g | EC],
            [KeyCode.e, KeyCode.c, KeyCode.h], [KeyCode.e, KeyCode.k | EC],
            [KeyCode.e, KeyCode.c],
            [KeyCode.e, KeyCode.t],
            [KeyCode.e, KeyCode.y],
            [KeyCode.e, KeyCode.u],
            [KeyCode.e, KeyCode.p],
            [KeyCode.e, KeyCode.c],
            [KeyCode.e, KeyCode.n],
            [KeyCode.e, KeyCode.m],
            [KeyCode.e],
        ],
        KeyCode.w: [
            [KeyCode.o, KeyCode.n],

            [KeyCode.u, KeyCode.o, KeyCode.n, KeyCode.g], [KeyCode.u, KeyCode.o, KeyCode.g | EC],

            [KeyCode.u, KeyCode.o, KeyCode.n],
            [KeyCode.u, KeyCode.o, KeyCode.i],
            [KeyCode.u, KeyCode.o, KeyCode.c],

            [KeyCode.o, KeyCode.i],
            [KeyCode.o, KeyCode.p],
            [KeyCode.o, KeyCode.m],
            [KeyCode.o, KeyCode.a],
            [KeyCode.o, KeyCode.t],

            [KeyCode.u, KeyCode.n, KeyCode.g], [KeyCode.u, KeyCode.g | EC],
            [KeyCode.a, KeyCode.n, KeyCode.g], [KeyCode.a, KeyCode.g | EC],
            [KeyCode.u, KeyCode.n],
            [KeyCode.u, KeyCode.m],
            [KeyCode.u, KeyCode.c],
            [KeyCode.u, KeyCode.a],
            [KeyCode.u, KeyCode.i],
            [KeyCode.u, KeyCode.t],
            [KeyCode.u],

            [KeyCode.a, KeyCode.p],
            [KeyCode.a, KeyCode.t],
            [KeyCode.a, KeyCode.m],

            [KeyCode.a, KeyCode.n],
            [KeyCode.a],
            [KeyCode.a, KeyCode.c],
            [KeyCode.a, KeyCode.c, KeyCode.h], [KeyCode.a, KeyCode.k | EC],

            [KeyCode.o],
            [KeyCode.u, KeyCode.u],
        ],
    ]
}()

/// Vowel-combination table — verbatim port of OpenKey _vowelCombine (Vietnamese.cpp:99-168).
/// Key = leading vowel key code; value = list of patterns where each pattern's first element
/// is the 0/1 "can have end consonant" flag, followed by key codes (with TONE/TONEW masks).
let vowelCombine: [UInt16: [[UInt32]]] = {
    let TM  = EngineMask.tone    // TONE_MASK  0x20000
    let TWM = EngineMask.toneW   // TONEW_MASK 0x40000
    let A   = UInt32(KeyCode.a)
    let E   = UInt32(KeyCode.e)
    let I   = UInt32(KeyCode.i)
    let O   = UInt32(KeyCode.o)
    let U   = UInt32(KeyCode.u)
    let Y   = UInt32(KeyCode.y)
    return [
        KeyCode.a: [
            //first elem can has end consonant or not
            [0, A, I],
            [0, A, O],
            [0, A, U],
            [0, A | TM, U],
            [0, A, Y],
            [0, A | TM, Y],
        ],
        KeyCode.e: [
            [0, E, O],
            [0, E | TM, U],
        ],
        KeyCode.i: [
            [1, I, E | TM, U],
            [0, I, A],
            [1, I, E | TM],
            [0, I, U],
        ],
        KeyCode.o: [
            [0, O, A, I],
            [0, O, A, O],
            [0, O, A, Y],
            [0, O, E, O],
            [1, O, A],
            [1, O, A | TWM],
            [1, O, E],
            [0, O, I],
            [0, O | TM,  I],
            [0, O | TWM, I],
            [1, O, O],
            [1, O | TM, O | TM],
        ],
        KeyCode.u: [
            [0, U, Y, U],
            [1, U, Y, E | TM],
            [0, U, Y, A],
            [0, U | TWM, O | TWM, U],
            [0, U | TWM, O | TWM, I],
            [0, U, O | TM,  I],
            [0, U, A | TM,  Y],
            [1, U, A, O],
            [1, U, A],
            [1, U, A | TWM],
            [1, U, A | TM],
            [0, U | TWM, A],
            [1, U, E | TM],
            [0, U, I],
            [0, U | TWM, I],
            [1, U, O],
            [1, U, O | TM],
            [0, U, O | TWM],
            [1, U | TWM, O | TWM],
            [0, U | TWM, U],
            [1, U, Y],
        ],
        KeyCode.y: [
            [0, Y, E | TM, U],
            [1, Y, E | TM],
        ],
    ]
}()

/// Reverse map: engine key cell (low byte = keyCode, +caps) → ASCII character code.
/// Verbatim behavior of OpenKey keyCodeToCharacter.
func keyCodeToCharacter(_ keyCode: UInt32) -> UInt16 {
    let code = UInt16(keyCode & EngineMask.char)
    let caps = (keyCode & EngineMask.caps) != 0
    for ch in asciiTable {
        if let m = KeyCode.keyCode(for: ch), m.code == code, m.caps == caps {
            return UInt16(ch.asciiValue ?? 0)
        }
    }
    return 0
}
private let asciiTable: [Character] =
    Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789[] .,")

// MARK: - Vowel-for-mark pattern table (Vietnamese.cpp:244-331)

/// Ordered array of (vowelKey, patterns) — verbatim port of OpenKey _vowelForMark.
/// C++ stores this as map<Uint16, ...> iterated by integer index 0..35, which visits
/// the actual keys in ascending-key-code order: A(0), E(14), Y(16), O(31), U(32), I(34).
/// Each pattern is a list of key codes (right-to-left from buffer end) that a vowel group
/// must match for the engine to apply a tone mark.  END_CONSONANT_MASK (0x4000) on a
/// pattern element is only stripped when vQuickEndConsonant is enabled (not yet ported).
let vowelForMark: [(key: UInt16, patterns: [[UInt16]])] = {
    let EC = UInt16(EngineMask.endConsonant)
    return [
        // KEY_A = 0
        (KeyCode.a, [
            [KeyCode.a, KeyCode.n, KeyCode.g], [KeyCode.a, KeyCode.g | EC],
            [KeyCode.a, KeyCode.n],
            [KeyCode.a, KeyCode.n, KeyCode.h], [KeyCode.a, KeyCode.h | EC],
            [KeyCode.a, KeyCode.m],
            [KeyCode.a, KeyCode.u],
            [KeyCode.a, KeyCode.y],
            [KeyCode.a, KeyCode.t],
            [KeyCode.a, KeyCode.p],
            [KeyCode.a],
            [KeyCode.a, KeyCode.c],
            [KeyCode.a, KeyCode.i],
            [KeyCode.a, KeyCode.o],
            [KeyCode.a, KeyCode.c, KeyCode.h], [KeyCode.a, KeyCode.k | EC],
        ]),
        // KEY_E = 14
        (KeyCode.e, [
            [KeyCode.e, KeyCode.n, KeyCode.h], [KeyCode.e, KeyCode.h | EC],
            [KeyCode.e, KeyCode.n, KeyCode.g], [KeyCode.e, KeyCode.g | EC],
            [KeyCode.e, KeyCode.c, KeyCode.h], [KeyCode.e, KeyCode.k | EC],
            [KeyCode.e, KeyCode.c],
            [KeyCode.e, KeyCode.t],
            [KeyCode.e, KeyCode.y],
            [KeyCode.e, KeyCode.u],
            [KeyCode.e, KeyCode.p],
            [KeyCode.e, KeyCode.c],
            [KeyCode.e, KeyCode.n],
            [KeyCode.e, KeyCode.m],
            [KeyCode.e],
        ]),
        // KEY_Y = 16
        (KeyCode.y, [
            [KeyCode.y],
        ]),
        // KEY_O = 31
        (KeyCode.o, [
            [KeyCode.o, KeyCode.o, KeyCode.n, KeyCode.g], [KeyCode.o, KeyCode.o, KeyCode.g | EC],
            [KeyCode.o, KeyCode.n, KeyCode.g], [KeyCode.o, KeyCode.g | EC],
            [KeyCode.o, KeyCode.o, KeyCode.n],
            [KeyCode.o, KeyCode.o, KeyCode.c],
            [KeyCode.o, KeyCode.o],
            [KeyCode.o, KeyCode.n],
            [KeyCode.o, KeyCode.m],
            [KeyCode.o, KeyCode.i],
            [KeyCode.o, KeyCode.c],
            [KeyCode.o, KeyCode.t],
            [KeyCode.o, KeyCode.p],
            [KeyCode.o],
        ]),
        // KEY_U = 32
        (KeyCode.u, [
            [KeyCode.u, KeyCode.n, KeyCode.g], [KeyCode.u, KeyCode.g | EC],
            [KeyCode.u, KeyCode.i],
            [KeyCode.u, KeyCode.o],
            [KeyCode.u, KeyCode.y],
            [KeyCode.u, KeyCode.y, KeyCode.n],
            [KeyCode.u, KeyCode.y, KeyCode.t],
            [KeyCode.u, KeyCode.y, KeyCode.p],
            [KeyCode.u, KeyCode.y, KeyCode.n, KeyCode.h], [KeyCode.u, KeyCode.y, KeyCode.h | EC],
            [KeyCode.u, KeyCode.t],
            [KeyCode.u, KeyCode.u],
            [KeyCode.u, KeyCode.a],
            [KeyCode.u, KeyCode.i],
            [KeyCode.u, KeyCode.c],
            [KeyCode.u, KeyCode.n],
            [KeyCode.u, KeyCode.m],
            [KeyCode.u, KeyCode.p],
            [KeyCode.u],
        ]),
        // KEY_I = 34
        (KeyCode.i, [
            [KeyCode.i, KeyCode.n, KeyCode.h], [KeyCode.i, KeyCode.h | EC],
            [KeyCode.i, KeyCode.c, KeyCode.h], [KeyCode.i, KeyCode.k | EC],
            [KeyCode.i, KeyCode.n],
            [KeyCode.i, KeyCode.t],
            [KeyCode.i, KeyCode.u],
            [KeyCode.i, KeyCode.u, KeyCode.p],
            [KeyCode.i, KeyCode.n],
            [KeyCode.i, KeyCode.m],
            [KeyCode.i, KeyCode.p],
            [KeyCode.i, KeyCode.a],
            [KeyCode.i, KeyCode.c],
            [KeyCode.i],
        ]),
    ]
}()
