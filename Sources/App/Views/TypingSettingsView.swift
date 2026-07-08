import SwiftUI

struct TypingSettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: "Kiểu gõ") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kiểu gõ")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dkText)
                            Picker("", selection: $state.inputMethod) {
                                Text("Telex").tag(InputMethod.telex)
                                Text("VNI").tag(InputMethod.vni)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kiểu bỏ dấu")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dkText)
                            Picker("", selection: $state.useModernOrthography) {
                                Text("Mới (hoà, uý)").tag(true)
                                Text("Cũ (hòa, úy)").tag(false)
                            }
                            .labelsHidden()
                            .pickerStyle(.radioGroup)
                        }
                        HStack {
                            Text("Phím chuyển")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dkText)
                            Spacer()
                            KeyRecorderField(status: $state.switchKeyStatus)
                        }
                    }
                }

                SectionCard(title: "Gõ tiếng Việt") {
                    VStack(spacing: 10) {
                        ForEach(TypingExtras.placeholderRows, id: \.title) { row in
                            ToggleRow(title: row.title,
                                      subtitle: row.subtitle,
                                      isOn: .constant(false),
                                      enabled: row.enabled)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dkWindowBg)
    }
}
