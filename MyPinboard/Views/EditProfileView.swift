import SwiftUI

/// Sheet for changing your photo, name, handle, and bio. Changes are saved as you type.
struct EditProfileView: View {
    @Bindable var profile: Profile
    @Environment(\.dismiss) private var dismiss

    private let bioLimit = 160
    private let handleLimit = 20

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        AvatarView(data: profile.avatarData, name: profile.displayName, size: 96)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)

                    CustomPhotoRow(
                        title: "Choose Photo",
                        data: $profile.avatarData,
                        maxDimension: 512,
                        onChosen: {},
                        onRemoved: {}
                    )
                }

                Section("About You") {
                    TextField("Name", text: $profile.displayName)

                    HStack(spacing: 2) {
                        Text("@")
                            .foregroundStyle(.secondary)
                        TextField("handle", text: $profile.handle)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                    }

                    TextField("Bio", text: $profile.bio, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                } footer: {
                    Text("Your handle is how friends will recognize you. Use letters, numbers, dots, and underscores.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: profile.handle) { _, newValue in
                let cleaned = String(Self.cleanedHandle(newValue).prefix(handleLimit))
                if cleaned != newValue {
                    profile.handle = cleaned
                }
            }
            .onChange(of: profile.bio) { _, newValue in
                if newValue.count > bioLimit {
                    profile.bio = String(newValue.prefix(bioLimit))
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 460)
        #endif
        .presentationDetents([.large])
    }

    /// Lowercase letters, numbers, dots, and underscores only.
    private static func cleanedHandle(_ text: String) -> String {
        text.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "_") }
    }
}
