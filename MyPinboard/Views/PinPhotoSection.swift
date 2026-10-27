import SwiftUI
import PhotosUI

/// A form section for a pin's photo: take one, retake it, or choose another from the library. Each new photo
/// is cut out from its background automatically. Used for a pin's main photo and for the inside of a pin that opens.
struct PinPhotoSection: View {
    @Binding var imageData: Data?
    var header: String?
    /// A line of guidance under the buttons.
    var hint: String?
    /// Shape of the preview: 1 is square, 2 is twice as wide as tall (for a pin photographed open).
    var previewAspect: CGFloat = 1
    /// Adds a button to clear the photo, for photos that are optional.
    var canRemove = false
    /// Updated while a new photo is being cut out, so a form can hold off saving until it's ready.
    var isBusy: Binding<Bool>?

    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var cutoutFailed = false
    #if os(iOS)
    @State private var isShowingCamera = false
    #endif

    private var hasPhoto: Bool { imageData != nil }

    var body: some View {
        Section {
            VStack(spacing: 16) {
                preview

                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        #if os(iOS)
                        if CameraPicker.isAvailable {
                            Button(hasPhoto ? "Retake Photo" : "Take Photo", systemImage: "camera") {
                                isShowingCamera = true
                            }
                            .buttonStyle(.glass)
                        }
                        #endif
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label(hasPhoto ? "Choose Another" : "Choose Photo", systemImage: "photo")
                        }
                        .buttonStyle(.glass)
                    }
                }

                if canRemove && hasPhoto {
                    Button("Remove Photo", role: .destructive) {
                        imageData = nil
                        cutoutFailed = false
                    }
                    .font(.footnote)
                }

                if cutoutFailed {
                    Text("Couldn't isolate the pin, so the original photo will be used.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let hint {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .task(id: selectedItem) {
                guard let selectedItem,
                      let data = try? await selectedItem.loadTransferable(type: Data.self)
                else { return }
                await process(data)
            }
            .onChange(of: isProcessing) { _, processing in
                isBusy?.wrappedValue = processing
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker { data in
                    Task { await process(data) }
                }
                .ignoresSafeArea()
            }
            #endif
        } header: {
            if let header {
                Text(header)
            }
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.quaternary.opacity(0.6))

            PinImageView(data: imageData)
                .padding(20)
                .opacity(isProcessing ? 0.4 : 1)

            if isProcessing {
                ProgressView()
            }
        }
        .frame(width: 200 * min(previewAspect, 1.6), height: 200)
        .animation(.smooth, value: isProcessing)
    }

    /// Shows the new photo right away, then swaps in the cutout when it's ready.
    private func process(_ data: Data) async {
        imageData = data
        cutoutFailed = false
        isProcessing = true
        defer { isProcessing = false }

        do {
            imageData = try await PinCutout.removeBackground(from: data)
        } catch {
            print("PinCutout failed: \(error)")
            cutoutFailed = true
        }
    }
}
