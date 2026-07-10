import SwiftUI
import UniformTypeIdentifiers

/// Gõ tắt bám mkey: tuỳ chọn + đồng bộ iCloud + ô thêm/sửa inline + bảng + nhập/xuất.
/// (Ô tìm kiếm của bản dkey cũ đã bỏ để khớp mkey; helper MacroFilter vẫn giữ.)
struct MacroView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var cloudSync = MacroCloudSync.shared
    @AppStorage("macroCloudSyncEnabled") private var syncEnabled = false
    @State private var selection: Macro.ID?
    @State private var keyField = ""
    @State private var contentField = ""
    @State private var importing = false
    @State private var exporting = false
    @FocusState private var focusedField: Field?

    private enum Field { case key, content }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: "Tùy chọn gõ tắt") {
                    VStack(alignment: .leading, spacing: 10) {
                        ToggleRow(title: "Bật gõ tắt", isOn: $state.useMacro)
                        ToggleRow(title: "Dùng gõ tắt cả trong chế độ tiếng Anh",
                                  isOn: $state.useMacroInEnglishMode,
                                  enabled: state.useMacro)
                        ToggleRow(title: "Tự hoa theo từ gốc",
                                  subtitle: "btw→by the way, Btw→By the way",
                                  isOn: $state.autoCapsMacro,
                                  enabled: state.useMacro)
                    }
                }

                SectionCard(title: "Đồng bộ") {
                    VStack(alignment: .leading, spacing: 10) {
                        ToggleRow(title: "Đồng bộ danh sách gõ tắt qua iCloud Drive",
                                  isOn: $syncEnabled)
                            .onChange(of: syncEnabled) { _, on in cloudSync.setEnabled(on) }
                        HStack(spacing: 8) {
                            Image(systemName: cloudSync.isAvailable ? "checkmark.icloud" : "icloud.slash")
                                .foregroundStyle(cloudSync.isAvailable ? Color.dkSuccess : Color.dkSecondary)
                                .accessibilityHidden(true)
                            Text(cloudSync.statusText)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.dkSecondary)
                                .lineLimit(2)
                            Spacer()
                            Button("Đồng bộ ngay") { cloudSync.syncNow() }
                                .disabled(!syncEnabled || !cloudSync.isAvailable)
                        }
                    }
                }

                SectionCard(title: "Gõ tắt") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Spacer()
                            Button("Nhập…") { importing = true }
                            Button("Xuất…") { exporting = true }
                        }

                        Table(state.macros, selection: $selection) {
                            TableColumn("Gõ tắt", value: \.key)
                            TableColumn("Thay thế bằng", value: \.content)
                        }
                        .frame(minHeight: 220)
                        .onChange(of: selection) { _, id in
                            if let m = state.macros.first(where: { $0.id == id }) {
                                keyField = m.key; contentField = m.content
                            } else {
                                keyField = ""; contentField = ""
                            }
                        }

                        HStack {
                            TextField("Từ tắt", text: $keyField)
                                .frame(width: 130)
                                .focused($focusedField, equals: .key)
                                .onSubmit { focusedField = .content }
                            TextField("Nội dung thay thế", text: $contentField)
                                .focused($focusedField, equals: .content)
                                .onSubmit { addOrEdit() }
                            Button(existsKey ? "Sửa" : "Thêm") { addOrEdit() }
                                .disabled(keyField.isEmpty)
                            Button("Xoá", role: .destructive) { deleteSelected() }
                                .disabled(selection == nil)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dkWindowBg)
        .onAppear {
            cloudSync.localMacrosProvider = { AppState.shared.macros }
            cloudSync.applyMacros = { AppState.shared.macros = $0 }
            cloudSync.start()
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { result in
            if case .success(let url) = result {
                let imported = MacroStore().importMacros(from: url)
                var merged = state.macros
                for m in imported {
                    if let i = merged.firstIndex(where: { $0.key == m.key }) { merged[i] = m }
                    else { merged.append(m) }
                }
                state.macros = merged
                cloudSync.localMacrosDidChange()
            }
        }
        .fileExporter(isPresented: $exporting, document: MacrosDocument(state.macros),
                      contentType: .json, defaultFilename: "macros") { _ in }
    }

    private var existsKey: Bool { state.macros.contains { $0.key == keyField } }

    private func addOrEdit() {
        guard !keyField.isEmpty else { return }
        var m = state.macros
        if let i = m.firstIndex(where: { $0.key == keyField }) { m[i].content = contentField }
        else { m.append(Macro(key: keyField, content: contentField)) }
        state.macros = m
        keyField = ""; contentField = ""
        selection = nil
        focusedField = .key
        cloudSync.localMacrosDidChange()
    }

    private func deleteSelected() {
        state.macros.removeAll { $0.id == selection }
        selection = nil; keyField = ""; contentField = ""
        cloudSync.localMacrosDidChange()
    }
}

/// FileDocument for exporting macros as JSON.
struct MacrosDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let macros: [Macro]
    init(_ macros: [Macro]) { self.macros = macros }
    init(configuration: ReadConfiguration) throws { macros = [] }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: (try? JSONEncoder().encode(macros)) ?? Data())
    }
}
