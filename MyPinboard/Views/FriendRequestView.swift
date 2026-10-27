import SwiftUI

/// Sheet for adding a friend from a link they sent, for apps that don't open it directly.
struct PasteLinkView: View {
    /// Receives the pasted text. Returns an error message to show, or nil when the link was accepted.
    let onSubmit: (String) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paste a friend link", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif

                    PasteButton(payloadType: String.self) { strings in
                        if let pasted = strings.first {
                            text = pasted
                            submit()
                        }
                    }
                } footer: {
                    Text("Friend links start with pinboard://. Pasting one here shows you who it's from before anyone is added.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Paste a Link")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue", action: submit)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: text) { errorMessage = nil }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
        .presentationDetents([.medium])
    }

    private func submit() {
        if let message = onSubmit(text) {
            errorMessage = message
        } else {
            dismiss()
        }
    }
}

#Preview {
    FriendRequestView(
        profile: previewRequestProfile(),
        isUpdate: false,
        onAdd: {},
        onDecline: {}
    )
}

/// A sample incoming profile, built from models that never enter a store.
@MainActor
private func previewRequestProfile() -> ProfileSnapshot {
    let profile = Profile()
    profile.displayName = "Ollie Finch"
    profile.handle = "ollie_finch"
    profile.bio = "Dragons, mostly."
    let pins = ["Tiny Dragon", "Ember Wyrm", "Hoard Cat"].map { name -> Pin in
        let pin = Pin(name: name)
        pin.purchasePrice = 14
        pin.artist = "Ollie Finch"
        pin.festival = "Eurofurence"
        return pin
    }
    return ProfileSnapshot(profile: profile, boards: [Board(name: "Dragon Hoard")], pins: pins)
}

/// Shown when someone's profile arrives, by AirDrop, Messages, or a file. Nobody is added until
/// you say so.
struct FriendRequestView: View {
    let profile: ProfileSnapshot
    /// True when you already have this person, so adding refreshes their profile.
    let isUpdate: Bool
    let onAdd: () -> Void
    let onDecline: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        AvatarView(data: profile.avatarData, name: profile.displayName, size: 104)

                        Text(profile.displayName.isEmpty ? "Someone new" : profile.displayName)
                            .font(.title.bold())
                            .fontDesign(.rounded)

                        if !profile.handle.isEmpty {
                            Text("@\(profile.handle)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if !profile.bio.isEmpty {
                            Text(profile.bio)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }

                    if profile.cardOnly == true {
                        CardOnlyNote()
                    } else {
                        StatsRow(stats: profile.stats)
                    }

                    VStack(spacing: 12) {
                        Button(isUpdate ? "Update Friend" : "Add Friend", systemImage: "person.badge.plus", action: onAdd)
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)

                        Button("Not Now", action: onDecline)
                            .buttonStyle(.glass)
                            .controlSize(.large)
                    }

                    Text(isUpdate
                         ? "You already have them. This replaces the copy you saved with their latest."
                         : "They'll appear in your friends. You can remove them any time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Friend Request")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 520)
        #endif
        .presentationDetents([.large])
    }
}
