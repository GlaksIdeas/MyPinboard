import SwiftUI
import SwiftData

@main struct MyApp: App {
    private let container = MyApp.makeContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    /// Builds the store, synced through the iCloud container named in the app's entitlements.
    /// If that can't be set up (for example the capability isn't provisioned yet), the app
    /// still works from a local-only store instead of failing to launch.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Pin.self, Board.self, Profile.self, Friend.self])

        do {
            let synced = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: synced)
        } catch {
            print("iCloud sync unavailable, using a local-only store: \(error)")
        }

        do {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            fatalError("Couldn't create the model container: \(error)")
        }
    }
}
