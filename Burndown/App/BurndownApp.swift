import SwiftData
import SwiftUI

@main
struct BurndownApp: App {
    private let modelContainer: ModelContainer
    @State private var timeStore: TimeStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var justFinishedOnboarding = false

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Category.self, Session.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        modelContainer = container
        let store = TimeStore(modelContext: container.mainContext)
        _timeStore = State(initialValue: store)
        // Bring the lock screen back in line with reality on cold launch —
        // e.g. a running session whose Live Activity was killed by iOS's
        // staleness limit while the app was backgrounded/terminated.
        store.reconcileLiveActivities()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootTabView(presentAddCategoryOnAppear: justFinishedOnboarding)
                } else {
                    OnboardingView {
                        justFinishedOnboarding = true
                        hasCompletedOnboarding = true
                    }
                }
            }
            .environment(timeStore)
            .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
