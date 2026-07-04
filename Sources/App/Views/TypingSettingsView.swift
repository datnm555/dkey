import SwiftUI

struct TypingSettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Picker("Kiểu gõ:", selection: $state.inputMethod) {
                Text("Telex").tag(InputMethod.telex)
                Text("VNI").tag(InputMethod.vni)
            }
            .pickerStyle(.segmented)

            Picker("Kiểu bỏ dấu:", selection: $state.useModernOrthography) {
                Text("Mới (hoà, uý)").tag(true)
                Text("Cũ (hòa, úy)").tag(false)
            }
            .pickerStyle(.radioGroup)

            LabeledContent("Phím chuyển:") {
                KeyRecorderField(status: $state.switchKeyStatus)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 460, alignment: .leading)
    }
}
