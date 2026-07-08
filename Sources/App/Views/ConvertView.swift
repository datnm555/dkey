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
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: "Bảng mã") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Picker("Từ bảng mã", selection: $fromRaw) {
                                ForEach(CodeTable.allCases, id: \.rawValue) {
                                    Text($0.displayName).tag($0.rawValue)
                                }
                            }
                            Button {
                                let t = fromRaw; fromRaw = toRaw; toRaw = t
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                            }
                            .buttonStyle(.borderless)
                            .help("Hoán đổi bảng mã")
                            Picker("Sang bảng mã", selection: $toRaw) {
                                ForEach(CodeTable.allCases, id: \.rawValue) {
                                    Text($0.displayName).tag($0.rawValue)
                                }
                            }
                        }
                        Picker("Kiểu chữ", selection: $caseRaw) {
                            ForEach(CaseMode.allCases, id: \.rawValue) {
                                Text($0.displayName).tag($0.rawValue)
                            }
                        }
                        ToggleRow(title: "Loại bỏ dấu thanh (tiếng Việt → khong dau)",
                                  isOn: $removeMark)
                    }
                }

                SectionCard(title: "Văn bản nguồn") {
                    TextEditor(text: $input)
                        .font(.body)
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.dkWindowBg, in: RoundedRectangle(cornerRadius: 8))
                }

                SectionCard(title: "Kết quả") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextEditor(text: .constant(output))
                            .font(.body)
                            .frame(minHeight: 110)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.dkWindowBg, in: RoundedRectangle(cornerRadius: 8))
                        Button("Sao chép kết quả") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(output, forType: .string)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dkWindowBg)
    }
}
