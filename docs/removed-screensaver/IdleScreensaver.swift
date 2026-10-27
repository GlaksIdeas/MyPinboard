import SwiftUI

#if os(iOS)
import UIKit
#endif

// Idle detection for the screensaver, kept apart from the scene itself in Screensaver.swift.

extension View {
    /// On iPad, dims the screen and plays a screensaver after five minutes without a touch.
    /// Any touch wakes it. Does nothing on other devices.
    func idleScreensaver() -> some View {
        #if os(iOS)
        modifier(IdleScreensaver())
        #else
        self
        #endif
    }
}

#if os(iOS)

/// Watches for five idle minutes on iPad, then dims the screen and shows the screensaver.
private struct IdleScreensaver: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("screensaverEnabled") private var isEnabled = true

    @State private var lastActivity = Date.now
    @State private var isAsleep = false

    /// How long the iPad must go untouched.
    private static let timeout: TimeInterval = 5 * 60

    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content
                .background(IdleTouchDetector { lastActivity = .now })
                .task { await watchForIdle() }
                .onAppear(perform: refresh)
                .onChange(of: scenePhase) { refresh() }
                .onChange(of: isEnabled) { refresh() }
        } else {
            content
        }
    }

    private func watchForIdle() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            guard isEnabled, scenePhase == .active, !isAsleep else { continue }
            if Date.now.timeIntervalSince(lastActivity) >= Self.timeout {
                fallAsleep()
            }
        }
    }

    /// Keeps the iPad awake while the app is open and the screensaver is on, so the five minutes is the
    /// one that decides when it sleeps, not the system's auto-lock. Backgrounding the app wakes it.
    private func refresh() {
        let staysAwake = isEnabled && scenePhase == .active
        UIApplication.shared.isIdleTimerDisabled = staysAwake
        if staysAwake {
            if !isAsleep { lastActivity = .now }
        } else if isAsleep {
            wake()
        }
    }

    private func fallAsleep() {
        isAsleep = true
        ScreenDimmer.dim()
        ScreensaverPresenter.shared.show { wake() }
    }

    private func wake() {
        ScreensaverPresenter.shared.hide()
        ScreenDimmer.restore()
        isAsleep = false
        lastActivity = .now
    }
}

/// Dims the screen, and puts its brightness back exactly as it was.
@MainActor
enum ScreenDimmer {
    private static var savedBrightness: CGFloat?

    private static var screen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
    }

    static func dim() {
        guard savedBrightness == nil, let screen else { return }
        savedBrightness = screen.brightness
        screen.brightness = max(0.05, screen.brightness * 0.2)
    }

    static func restore() {
        guard let saved = savedBrightness else { return }
        savedBrightness = nil
        screen?.brightness = saved
    }
}

/// Shows the screensaver in a window of its own, above everything else, so it covers sheets and keyboards too.
@MainActor
final class ScreensaverPresenter {
    static let shared = ScreensaverPresenter()

    private var window: UIWindow?

    var isShowing: Bool { window != nil }

    /// Fades the screensaver in. `onWake` runs when it's touched, after it has started to fade out.
    func show(onWake: @escaping () -> Void) {
        guard window == nil else { return }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }

        let host = UIHostingController(rootView: ScreensaverView { [weak self] in
            self?.hide()
            onWake()
        })
        host.view.backgroundColor = .black

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = host
        window.alpha = 0
        window.isHidden = false
        UIView.animate(withDuration: 1.5) { window.alpha = 1 }
        self.window = window
    }

    func hide() {
        guard let window else { return }
        self.window = nil
        UIView.animate(withDuration: 0.4) {
            window.alpha = 0
        } completion: { _ in
            window.isHidden = true
        }
    }
}

/// Reports every touch anywhere in the app's window, without getting in the way of the touch itself.
private struct IdleTouchDetector: UIViewRepresentable {
    let onTouch: () -> Void

    func makeUIView(context: Context) -> DetectorView {
        let view = DetectorView()
        view.onTouch = onTouch
        return view
    }

    func updateUIView(_ view: DetectorView, context: Context) {
        view.onTouch = onTouch
    }
}

private final class DetectorView: UIView {
    var onTouch: (() -> Void)?

    private let spy = TouchSpy()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        spy.onTouch = { [weak self] in self?.onTouch?() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The spy sits on the whole window, not just this view, so it hears touches everywhere.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        spy.view?.removeGestureRecognizer(spy)
        window?.addGestureRecognizer(spy)
    }
}

/// A gesture recognizer that only listens: it reports that a touch began and then steps aside,
/// so the touch carries on to whatever it was meant for.
private final class TouchSpy: UIGestureRecognizer {
    var onTouch: (() -> Void)?

    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouch?()
        state = .failed
    }
}

#endif
