import Foundation

/// Hardware-independent key codes (macOS virtual key codes, from OpenKey mac.h).
/// Phase 2's event tap maps CGKeyCode → these values (they ARE the macOS codes).
enum KeyCode {
    static let esc: UInt16 = 53, delete: UInt16 = 51, tab: UInt16 = 48
    static let enter: UInt16 = 76, ret: UInt16 = 36, space: UInt16 = 49
    static let left: UInt16 = 123, right: UInt16 = 124, down: UInt16 = 125, up: UInt16 = 126
    static let empty: UInt16 = 256
    static let a: UInt16 = 0, b: UInt16 = 11, c: UInt16 = 8, d: UInt16 = 2, e: UInt16 = 14
    static let f: UInt16 = 3, g: UInt16 = 5, h: UInt16 = 4, i: UInt16 = 34, j: UInt16 = 38
    static let k: UInt16 = 40, l: UInt16 = 37, m: UInt16 = 46, n: UInt16 = 45, o: UInt16 = 31
    static let p: UInt16 = 35, q: UInt16 = 12, r: UInt16 = 15, s: UInt16 = 1, t: UInt16 = 17
    static let u: UInt16 = 32, v: UInt16 = 9, w: UInt16 = 13, x: UInt16 = 7, y: UInt16 = 16, z: UInt16 = 6
    static let n1: UInt16 = 18, n2: UInt16 = 19, n3: UInt16 = 20, n4: UInt16 = 21, n5: UInt16 = 23
    static let n6: UInt16 = 22, n7: UInt16 = 26, n8: UInt16 = 28, n9: UInt16 = 25, n0: UInt16 = 29
    static let leftBracket: UInt16 = 33, rightBracket: UInt16 = 30
    static let dot: UInt16 = 47, backquote: UInt16 = 50, minus: UInt16 = 27, equals: UInt16 = 24
    static let backSlash: UInt16 = 42, semicolon: UInt16 = 41, quote: UInt16 = 39
    static let comma: UInt16 = 43, slash: UInt16 = 44
}

extension KeyCode {
    /// Maps an ASCII character to (keyCode, caps). Used by tests and (later) by
    /// fallback paths. Returns nil for unmapped characters.
    static func keyCode(for ch: Character) -> (code: UInt16, caps: Bool)? {
        if let v = letterMap[ch] { return (v, false) }
        if let lower = ch.lowercased().first, let v = letterMap[lower], ch.isUppercase { return (v, true) }
        return punctMap[ch]
    }
    private static let letterMap: [Character: UInt16] = [
        "a": a, "b": b, "c": c, "d": d, "e": e, "f": f, "g": g, "h": h, "i": i, "j": j,
        "k": k, "l": l, "m": m, "n": n, "o": o, "p": p, "q": q, "r": r, "s": s, "t": t,
        "u": u, "v": v, "w": w, "x": x, "y": y, "z": z,
        "1": n1, "2": n2, "3": n3, "4": n4, "5": n5, "6": n6, "7": n7, "8": n8, "9": n9, "0": n0
    ]
    private static let punctMap: [Character: (UInt16, Bool)] = [
        "[": (leftBracket, false), "]": (rightBracket, false), " ": (space, false),
        ".": (dot, false), ",": (comma, false)
    ]
}
