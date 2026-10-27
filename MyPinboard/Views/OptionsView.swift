import SwiftUI

/// App-wide preferences.
struct OptionsView: View {
    @AppStorage("showSharingTips") private var showSharingTips = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Tap a pin to select it", systemImage: "hand.tap")
                    Label("Drag anywhere on the board to move it", systemImage: "hand.draw")
                    Label("Pinch anywhere to resize it", systemImage: "arrow.up.left.and.arrow.down.right")
                    Label("Twist with two fingers to rotate it", systemImage: "rotate.right")
                } header: {
                    Text("Moving Pins")
                } footer: {
                    Text("A selected pin also gets size and rotation sliders. Tap empty space on the board, or Done, and they slide away.")
                }

                Section {
                    Toggle("Show sharing tips", isOn: $showSharingTips)
                } header: {
                    Text("Tips")
                } footer: {
                    Text("The steps on your Profile page for adding friends by AirDrop.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Options")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 440)
        #endif
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    OptionsView()
}
