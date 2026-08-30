import SwiftData
import SwiftUI

@main
struct BurndownApp: App {
    private let modelContainer: ModelContainer
    @State private var timeStore: TimeStore

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Category.self, Session.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        modelContainer = container

        let store = TimeStore(modelContext: container.mainContext)
        do {
            // Seeded synchronously here, before any view renders, so there's
            // no first-frame flash of an empty Home screen.
            try store.seedIfNeeded()
        } catch {
            print("Seeding failed: \(error)")
        }
        _timeStore = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(timeStore)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
