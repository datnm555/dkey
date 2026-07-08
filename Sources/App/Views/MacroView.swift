import SwiftUI
import UniformTypeIdentifiers

struct MacroView: View {
    @EnvironmentObject private var state: AppState
    @State private var searchQuery = ""
    @State private var selection: Macro.ID?
    @State private var keyField = ""
    @State private var contentField = ""
    @State private var importing = false
    @State private var exporting = false

    private var filteredMacros: [Macro] { MacroFilter.filter(state.macros, query: searchQuery) }

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

                SectionCard(title: "Gõ tắt") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Color.dkSecondary)
                                TextField("Tìm gõ tắt…", text: $searchQuery)
                                    .textFieldStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.dkWindowBg, in: RoundedRectangle(cornerRadius: 7))
                            Spacer()
                            Button("Nhập…") { importing = true }
                            Button("Xuất…") { exporting = true }
                        }

                        Table(filteredMacros, selection: $selection) {
                            TableColumn("Gõ tắt", value: \.key)
                            TableColumn("Thay thế bằng", value: \.content)
                        }
                        .frame(minHeight: 200)
                        .onChange(of: selection) { _, id in
                            if let m = state.macros.first(where: { $0.id == id }) {
                                keyField = m.key; contentField = m.content
                            } else {
                                keyField = ""; contentField = ""
                            }
                        }

                        HStack {
                            TextField("Từ tắt", text: $keyField).frame(width: 120)
                            TextField("Nội dung thay thế", text: $contentField)
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
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { result in
            if case .success(let url) = result {
                let imported = MacroStore().importMacros(from: url)
                var merged = state.macros
                for m in imported {
                    if let i = merged.firstIndex(where: { $0.key == m.key }) { merged[i] = m }
                    else { merged.append(m) }
                }
                state.macros = merged
            }
        }
        .fileExporter(isPresented: $exporting, document: MacrosDocument(state.macros),
                      contentType: .json, defaultFilename: "macros") { _ in }
    }

    private var existsKey: Bool { state.macros.contains { $0.key == keyField } }

    private func addOrEdit() {
        var m = state.macros
        if let i = m.firstIndex(where: { $0.key == keyField }) { m[i].content = contentField }
        else { m.append(Macro(key: keyField, content: contentField)) }
        state.macros = m; keyField = ""; contentField = ""
    }

    private func deleteSelected() {
        state.macros.removeAll { $0.id == selection }
        selection = nil; keyField = ""; contentField = ""
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
