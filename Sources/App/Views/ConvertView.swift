import SwiftUI
import AppKit

struct ConvertView: View {
    @AppStorage("convert.from") private var fromRaw = CodeTable.unicode.rawValue
    @AppStorage("convert.to") private var toRaw = CodeTable.tcvn3.rawValue
    @AppStorage("convert.case") private var caseRaw = CaseMode.keep.rawValue
    @AppStorage("convert.removeMark") private var removeMark = false
    @State private var input = ""

    private var output: String {
        ConvertTool.convert(
            input,
            from: CodeTable(rawValue: fromRaw) ?? .unicode,
            to: CodeTable(rawValue: toRaw) ?? .tcvn3,
            caseMode: CaseMode(rawValue: caseRaw) ?? .keep,
            removeMark: removeMark)
    }

    var body: some View {
        Form {
            HStack {
                Picker("Từ bảng mã:", selection: $fromRaw) {
                    ForEach(CodeTable.allCases, id: \.rawValue) { Text($0.displayName).tag($0.rawValue) }
                }
                Button { let t = fromRaw; fromRaw = toRaw; toRaw = t } label: { Image(systemName: "arrow.left.arrow.right") }
                Picker("Sang:", selection: $toRaw) {
                    ForEach(CodeTable.allCases, id: \.rawValue) { Text($0.displayName).tag($0.rawValue) }
                }
            }
            Picker("Kiểu chữ:", selection: $caseRaw) {
                ForEach(CaseMode.allCases, id: \.rawValue) { Text($0.displayName).tag($0.rawValue) }
            }
            Toggle("Loại bỏ dấu thanh (tiếng Việt → khong dau)", isOn: $removeMark)
            Section("Văn bản") {
                TextEditor(text: $input).frame(minHeight: 90).font(.body)
            }
            Section("Kết quả") {
                TextEditor(text: .constant(output)).frame(minHeight: 90).font(.body)
                Button("Copy kết quả") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                }
            }
        }
        .formStyle(.grouped)
    }
}
