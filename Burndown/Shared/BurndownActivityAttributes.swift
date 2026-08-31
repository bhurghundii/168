import ActivityKit
import Foundation

/// Shared between the `Burndown` app target and the `BurndownWidgets`
/// extension target (see `project.yml`'s `BurndownWidgets.sources`, which
/// includes this file's parent directory explicitly since the extension's
/// own source root is `BurndownWidgets/`, not `Burndown/`).
///
/// Mirrors the app's core invariant: never persist elapsed/remaining time as
/// a number, only a `Date` the OS can tick a `Text`/`ProgressView(timerInterval:)`
/// against. See `TimeStore.swift` for the "derive everything from Date" rule
/// this type extends into the out-of-process widget extension.
struct BurndownActivityAttributes: ActivityAttributes {
    /// Fixed for the Activity's entire lifetime (`Activity.update()` can only
    /// change `ContentState`, never these). `categoryId` is the stable lookup
    /// key used to find/end/update a specific category's Activity — the name
    /// alone isn't unique or stable enough (a category can be renamed).
    var categoryId: UUID
    var categoryName: String

    struct ContentState: Codable, Hashable {
        /// The moment the running session began. Elapsed time is never
        /// stored — the widget derives it live from this Date alone.
        var startedAt: Date

        /// The Date at which the category's weekly budget hits exactly zero
        /// if the session keeps running uninterrupted, i.e.
        /// `startedAt + remaining-budget-seconds-at-start`. `nil` means the
        /// category was already at or past its weekly budget when this
        /// session began — there's no meaningful countdown to render.
        var budgetDeadline: Date?
    }
}
