// convert-oracle.cpp — Minimal CLI driver over OpenKey's ConvertTool.
//
// Reads lines from stdin:  <from>\t<to>\t<utf8-text>
//   from  = ConvertTool code-table index (0=Unicode, 1=TCVN3, 2=VNI, 3=UCCompound, 4=CP1258)
//   to    = same indices
//   text  = UTF-8 source text (should end with a trailing space so no Viet char is last)
//
// Outputs for each line:  <from>\t<to>\t<text>\t<result>
//   result = convertUtil output (UTF-8)
//
// Always uses lower case-mode (convertToolToAllNonCaps=true) and no remove-mark.
// This is the condition where dkey and OpenKey agree on case handling.
//
// Build: bash scripts/openkey-oracle/build.sh
// (build.sh also compiles this target as "convert-oracle")

#include <cstdio>
#include <cstdlib>
#include <string>
#include "Engine.h"
#include "ConvertTool.h"

// ---------------------------------------------------------------------------
// Engine config globals (declared extern in Engine.h; must be defined here)
// ---------------------------------------------------------------------------
int vLanguage             = 1;  // Vietnamese
int vInputType            = 0;  // vTelex (not used by ConvertTool, but required)
int vFreeMark             = 0;
int vCodeTable            = 0;  // Unicode
int vCheckSpelling        = 0;
int vUseModernOrthography = 0;

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
// main — read TSV lines from stdin, emit TSV
// ---------------------------------------------------------------------------
int main() {
    char buf[8192];
    while (fgets(buf, sizeof(buf), stdin)) {
        std::string line(buf);
        // Strip trailing newline / CR
        while (!line.empty() && (line.back() == '\n' || line.back() == '\r')) {
            line.pop_back();
        }
        if (line.empty()) continue;

        // Parse: <from>\t<to>\t<text>
        size_t t1 = line.find('\t');
        if (t1 == std::string::npos) continue;
        size_t t2 = line.find('\t', t1 + 1);
        if (t2 == std::string::npos) continue;

        int from = std::atoi(line.substr(0, t1).c_str());
        int to   = std::atoi(line.substr(t1 + 1, t2 - t1 - 1).c_str());
        std::string text = line.substr(t2 + 1);

        // Set ConvertTool options
        convertToolFromCode       = static_cast<Uint8>(from);
        convertToolToCode         = static_cast<Uint8>(to);
        convertToolToAllNonCaps   = true;   // lower mode — where dkey and OpenKey agree
        convertToolRemoveMark     = false;

        // Clear other case flags
        convertToolToAllCaps          = false;
        convertToolToCapsFirstLetter  = false;
        convertToolToCapsEachWord     = false;

        std::string result = convertUtil(text);

        // Strip trailing NUL that convertUtil appends
        while (!result.empty() && result.back() == '\0') result.pop_back();

        printf("%d\t%d\t%s\t%s\n", from, to, text.c_str(), result.c_str());
    }
    return 0;
}
