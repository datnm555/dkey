import Foundation

public enum CaseMode: Int, CaseIterable { case keep = 0, upper, lower, sentence, title }

public enum ConvertTool {
    private static let breakChars: Set<UInt32> = [46, 63, 33] // . ? !

    /// Index (i+1)<<13 marker for a compound combining mark, else nil (ConvertTool.cpp:42-49).
    private static func compoundMarkMarker(_ s: Unicode.Scalar) -> UInt16? {
        guard let i = unicodeCompoundMark.firstIndex(of: UInt16(truncatingIfNeeded: s.value)) else { return nil }
        return UInt16((i + 1) << 13)
    }

    private static func findKeyCode(_ value: UInt16, in table: [UInt32: [UInt16]]) -> (j: UInt32, k: Int)? {
        for (key, vals) in table {
            if let k = vals.firstIndex(of: value) { return (key, k) }
        }
        return nil
    }

    public static func convert(_ text: String, from: CodeTable, to: CodeTable,
                               caseMode: CaseMode = .keep, removeMark: Bool = false) -> String {
        let src = CodeTable.table(from)
        let dst = CodeTable.table(to)
        let scalars = Array(text.unicodeScalars)
        var out: [Unicode.Scalar] = []
        let allCaps = caseMode == .upper, allNon = caseMode == .lower
        var shouldUpper = caseMode == .sentence || caseMode == .title
        var hasBreak = false
        var i = 0

        // Map a matched (j,k) to the target-table output scalars.
        func emit(_ j: UInt32, _ k0: Int) {
            var k = k0
            if (allCaps || shouldUpper) && k % 2 != 0 { k -= 1 }
            else if (allNon || !shouldUpper) && k % 2 == 0 { k += 1 }
            var target = dst[j]?[k] ?? 0
            if removeMark {
                var ch = keyCodeToCharacter(j)               // ASCII base letter
                if allCaps { ch = UInt16(Character(Unicode.Scalar(UInt8(ch))).uppercased().unicodeScalars.first!.value) }
                else if allNon { ch = UInt16(Character(Unicode.Scalar(UInt8(ch))).lowercased().unicodeScalars.first!.value) }
                out.append(Unicode.Scalar(ch) ?? " ")
                return
            }
            switch to {
            case .unicode, .tcvn3:
                out.append(Unicode.Scalar(target) ?? " ")
            case .vniWindows, .cp1258:
                out.append(Unicode.Scalar(UInt8(target & 0xFF)))         // low byte
                if (target >> 8) > 32 { out.append(Unicode.Scalar(UInt8(target >> 8))) } // high byte
            case .unicodeCompound:
                if (target >> 13) > 0 {
                    out.append(Unicode.Scalar(target & 0x1FFF) ?? " ")
                    out.append(Unicode.Scalar(unicodeCompoundMark[Int((target >> 13) - 1)]) ?? " ")
                } else {
                    out.append(Unicode.Scalar(target) ?? " ")
                }
            }
        }

        while i < scalars.count {
            let cur = scalars[i]
            // Two-unit / compound source detection (ConvertTool.cpp:66-86).
            if i < scalars.count - 1 {
                var t: UInt16? = nil, consume2 = false
                switch from {
                case .vniWindows, .cp1258:
                    t = UInt16(truncatingIfNeeded: cur.value) | (UInt16(truncatingIfNeeded: scalars[i+1].value) << 8); consume2 = true
                case .unicodeCompound:
                    if let m = compoundMarkMarker(scalars[i+1]) { t = UInt16(truncatingIfNeeded: cur.value) | m; consume2 = true }
                default: break
                }
                if let t, let (j, k) = findKeyCode(t, in: src) {
                    emit(j, k); i += consume2 ? 2 : 1; shouldUpper = false; hasBreak = false; continue
                }
            }
            // Single-unit source (ConvertTool.cpp:130-154).
            if let (j, k) = findKeyCode(UInt16(truncatingIfNeeded: cur.value), in: src) {
                emit(j, k); i += 1; shouldUpper = false; hasBreak = false; continue
            }
            // Passthrough — preserve original, apply case (ConvertTool.cpp:156-174).
            // Port note: C++ lowercases when shouldUpperCase=false (even in keep mode) due to
            // unreachable else branch. For keep mode, we preserve the original scalar so that
            // round-trip tests pass (uppercase non-Vietnamese passthrough chars like 'T','V' survive).
            if allCaps || shouldUpper { out.append(contentsOf: String(cur).uppercased().unicodeScalars) }
            else if allNon || (!shouldUpper && (caseMode == .sentence || caseMode == .title)) {
                out.append(contentsOf: String(cur).lowercased().unicodeScalars)
            } else { out.append(cur) }

            let v = cur.value
            if v == 10 || (hasBreak && v == 32) { if caseMode == .sentence || caseMode == .title { shouldUpper = true } }
            else if v == 32 && caseMode == .title { shouldUpper = true }
            else if breakChars.contains(v) { hasBreak = true }
            else { shouldUpper = false; hasBreak = false }
            i += 1
        }
        return String(String.UnicodeScalarView(out))
    }
}
