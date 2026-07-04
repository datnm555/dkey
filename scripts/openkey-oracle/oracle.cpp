// oracle.cpp — Minimal CLI driver over the real OpenKey C++ engine.
//
// Reads Telex input lines from stdin; for each line emits:
//   <input><TAB><modern_out><TAB><classic_out>
// where "modern" means the linguistically-modern Vietnamese standard (hòa style)
// and "classic" means the old/alternative placement (hoà style).
//
// NOTE on vUseModernOrthography naming confusion:
//   The OpenKey C++ engine's vUseModernOrthography flag has names that are
//   reversed relative to the linguistic standard:
//     vUseModernOrthography=0 → handleOldMark  → linguistically MODERN ("hòa")
//     vUseModernOrthography=1 → handleModernMark → linguistically CLASSIC ("hoà")
//   The Swift port documents this at TelexEngine.swift:907-909.
//   Consequently we call runOne(telex, 0) for modern_out and runOne(telex, 1)
//   for classic_out.
//
// Stubs added to satisfy the linker (all features disabled via their config globals):
//   None required — all referenced code is compiled from the engine .cpp files.
//   The macroMap and macro functions are compiled in from Macro.cpp (vUseMacro=0
//   means they are never actually invoked at runtime).
//
// Build: bash scripts/openkey-oracle/build.sh

#include <cstdio>
#include <string>
#include <vector>
#include <cctype>
#include "Engine.h"
#include "Vietnamese.h"

// ---------------------------------------------------------------------------
// Engine config globals (declared extern in Engine.h; must be defined here)
// ---------------------------------------------------------------------------
int vLanguage             = 1;  // Vietnamese
int vInputType            = 0;  // vTelex
int vFreeMark             = 0;
int vCodeTable            = 0;  // Unicode
int vCheckSpelling        = 0;  // OFF — parity test does not exercise spelling
int vUseModernOrthography = 0;  // set per-call in runOne()

// Feature flags — all OFF for the oracle (we only need basic Telex→Unicode)
int vQuickTelex               = 0;
int vRestoreIfWrongSpelling    = 0;
int vUseMacro                 = 0;
int vUseMacroInEnglishMode    = 0;
int vAutoCapsMacro            = 0;
int vUseSmartSwitchKey        = 0;
int vUpperCaseFirstChar       = 0;
int vTempOffSpelling          = 0;
int vAllowConsonantZFWJ       = 0;
int vQuickStartConsonant      = 0;
int vQuickEndConsonant        = 0;
int vRememberCode             = 0;
int vOtherLanguage            = 0;
int vTempOffOpenKey           = 0;
int vSwitchKeyStatus          = 0;
int vFixRecommendBrowser      = 0;

// ---------------------------------------------------------------------------
// Forward declarations of engine symbols used below
// ---------------------------------------------------------------------------
extern vKeyHookState HookState;
extern map<Uint32, Uint32> _characterMap;

// ---------------------------------------------------------------------------
// Decode one charData cell to a Unicode codepoint.
//
// HookState.charData[i] is filled by GET(TypingWord[i]) (= getCharacterCode)
// in most code paths, but by raw TypingWord[i] in restore paths.
// We call getCharacterCode() on it unconditionally; if the result has
// CHAR_CODE_MASK the lower 16 bits are already the Unicode scalar.
// Otherwise the value is a plain macOS keycode (e.g. KEY_H=4); we convert it
// back to its ASCII character via keyCodeToCharacter().
// ---------------------------------------------------------------------------
static Uint32 charDataCodepoint(Uint32 data) {
    Uint32 d = getCharacterCode(data);
    if (d & CHAR_CODE_MASK) {
        return d & 0xFFFF;
    }
    // Plain key code — strip extraneous mask bits (keep key + CAPS_MASK only)
    // keyCodeToCharacter() distinguishes KEY_A vs KEY_A|CAPS_MASK from _characterMap.
    Uint16 ch = keyCodeToCharacter(d & (CHAR_MASK | CAPS_MASK));
    return static_cast<Uint32>(ch);
}

// ---------------------------------------------------------------------------
// UTF-8 encode a Unicode codepoint (BMP only; sufficient for Vietnamese).
// ---------------------------------------------------------------------------
static std::string toUtf8(Uint32 cp) {
    std::string out;
    if (cp == 0) return out;
    if (cp < 0x80) {
        out += static_cast<char>(cp);
    } else if (cp < 0x800) {
        out += static_cast<char>(0xC0 | (cp >> 6));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    } else {
        out += static_cast<char>(0xE0 | (cp >> 12));
        out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        out += static_cast<char>(0x80 | (cp & 0x3F));
    }
    return out;
}

// ---------------------------------------------------------------------------
// Run the engine over one Telex string and return the resulting UTF-8 text.
//
// orthography: value assigned to vUseModernOrthography.
//   0 → linguistically modern Vietnamese (handleOldMark → "hòa" style)
//   1 → linguistically classic/old       (handleModernMark → "hoà" style)
//
// Screen buffer semantics (mirrors Swift TelexTestSupport.swift type()):
//   vWillProcess / vRestore → pop backspaceCount, push newCharCount chars
//   everything else (vDoNothing, vBreakWord, …) → push the raw ASCII char
// ---------------------------------------------------------------------------
static std::string runOne(const std::string& telex, int orthography) {
    vUseModernOrthography = orthography;
    vKeyInit();
    startNewSession();

    std::vector<Uint32> screen; // Unicode codepoints

    for (unsigned char c : telex) {
        auto it = _characterMap.find(static_cast<Uint32>(c));
        if (it == _characterMap.end()) {
            // Unknown character — pass through as-is
            screen.push_back(c);
            continue;
        }

        Uint32  km   = it->second;
        Uint16  code = static_cast<Uint16>(km & 0xFFFF);
        Uint8   caps = (km & CAPS_MASK) ? 1 : 0;

        vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, code, caps, false);

        if (HookState.code == vWillProcess || HookState.code == vRestore) {
            // Delete the engine-indicated characters from our screen buffer
            for (int i = 0; i < HookState.backspaceCount && !screen.empty(); i++) {
                screen.pop_back();
            }
            // Append new characters — charData is stored right-to-left by the engine
            // (hData[_index-1-ii] = TypingWord[ii]) so index newCharCount-1 is leftmost.
            for (int i = HookState.newCharCount - 1; i >= 0; i--) {
                Uint32 cp = charDataCodepoint(HookState.charData[i]);
                if (cp != 0) screen.push_back(cp);
            }
        } else {
            // vDoNothing (normal passthrough), vBreakWord, etc.
            screen.push_back(static_cast<Uint32>(c));
        }
    }

    std::string out;
    for (Uint32 cp : screen) {
        out += toUtf8(cp);
    }
    return out;
}

// ---------------------------------------------------------------------------
// main — read lines from stdin, emit TSV
// Usage: oracle [telex|vni]   (default: telex)
// ---------------------------------------------------------------------------
int main(int argc, char* argv[]) {
    // Set input method before processing any input.
    if (argc > 1 && std::string(argv[1]) == "vni") vInputType = 1;  // vVNI

    char buf[4096];
    while (fgets(buf, sizeof(buf), stdin)) {
        std::string telex(buf);
        // Strip trailing newline / CR
        while (!telex.empty() && (telex.back() == '\n' || telex.back() == '\r')) {
            telex.pop_back();
        }
        if (telex.empty()) continue;

        // modern_out: vUseModernOrthography=0 (linguistically modern, "hòa")
        // classic_out: vUseModernOrthography=1 (linguistically classic, "hoà")
        std::string modern  = runOne(telex, 0);
        std::string classic = runOne(telex, 1);

        printf("%s\t%s\t%s\n", telex.c_str(), modern.c_str(), classic.c_str());
    }
    return 0;
}
