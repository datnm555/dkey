import SwiftUI
import AppKit

/// Công cụ chuyển mã bám luồng mkey: chọn bảng mã + kiểu chữ → sao chép văn bản vào
/// clipboard → bấm "Chuyển mã clipboard" → kết quả ghi lại clipboard + thông báo.
/// (Ô nhập/kết quả trực tiếp của bản dkey cũ đã bỏ để khớp mkey.)
struct ConvertView: View {
    @AppStorage("convert.from") private var fromRaw = CodeTable.unicode.rawValue
    @AppStorage("convert.to") private var toRaw = CodeTable.tcvn3.rawValue
    @AppStorage("convert.case") private var caseRaw = CaseMode.keep.rawValue
    @AppStorage("convert.removeMark") private var removeMark = false
    @State private var resultMessage: String?

    private var from: CodeTable { CodeTable(rawValue: fromRaw) ?? .unicode }
    private var to: CodeTable { CodeTable(rawValue: toRaw) ?? .tcvn3 }
    private var caseMode: CaseMode { CaseMode(rawValue: caseRaw) ?? .keep }

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
                            Picker("Sang bảng mã", selection: $toRaw) {
                                ForEach(CodeTable.allCases, id: \.rawValue) {
                                    Text($0.displayName).tag($0.rawValue)
                                }
                            }
                        }
                        Button {
                            let t = fromRaw; fromRaw = toRaw; toRaw = t
                        } label: {
                            Label("Đảo chiều", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }

                SectionCard(title: "Chữ hoa / chữ thường") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Chuyển đổi", selection: $caseRaw) {
                            ForEach(CaseMode.allCases, id: \.rawValue) {
                                Text($0.displayName).tag($0.rawValue)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        ToggleRow(title: "Loại bỏ dấu thanh (tiếng Việt → khong dau)",
                                  isOn: $removeMark)
                    }
                }

                // Phím tắt chuyển nhanh (⌥…): hoãn sang PR9 vì cần hotkey toàn cục (Carbon).

                SectionCard(title: "Chuyển mã nhanh qua clipboard") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sao chép văn bản cần chuyển vào clipboard rồi bấm Chuyển mã.")
                            .font(.callout)
                            .foregroundStyle(Color.dkSecondary)
                        Button("Chuyển mã clipboard") {
                            let ok = ClipboardConverter.convertPasteboard(
                                from: from, to: to, caseMode: caseMode, removeMark: removeMark)
                            resultMessage = ok
                                ? "Chuyển mã thành công! Kết quả đã được lưu trong clipboard."
                                : "Không có dữ liệu trong clipboard. Hãy sao chép một đoạn văn bản trước."
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dkWindowBg)
        .alert("Công cụ chuyển mã",
               isPresented: .init(get: { resultMessage != nil },
                                  set: { if !$0 { resultMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
    }
}
