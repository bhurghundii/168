import Foundation
import Observation
import SwiftData

/// The single facade for every mutation and every derived read in the app.
/// Views read model objects via `@Query` (always in sync with SwiftData's
/// change tracking); everything else — starting/stopping a timer, manual
/// adjustments, category CRUD, import/export, and all week-window
/// arithmetic — goes through this type, which holds the *same* `ModelContext`
/// `@Query` uses. There is exactly one source of truth; nothing here caches
/// model data separately.
///
/// `calendar`/`now` default to the real current calendar/clock in production
/// and are injected explicitly in tests, so the underlying `WeekWindow`/
/// `TimeMath` pure functions can be exercised with fixed, DST-crossing dates.
@MainActor
@Observable
final class TimeStore {
    private let modelContext: ModelContext
    var calendar: Calendar
    var now: () -> Date
    private let liveActivityManager: LiveActivityManaging

    init(modelContext: ModelContext,
         calendar: Calendar = WeekWindow.mondayStart(),
         now: @escaping () -> Date = Date.init,
         liveActivityManager: LiveActivityManaging? = nil) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.now = now
        // `LiveActivityManager()`'s default can't be a default-parameter
        // expression directly: default-argument expressions are evaluated
        // outside this initializer's @MainActor isolation, but constructing
        // one here in the body runs on the main actor like the rest of init.
        self.liveActivityManager = liveActivityManager ?? LiveActivityManager()
    }

    // MARK: - Session lifecycle

    /// Every session app-wide with `endedAt == nil` — normally at most one,
    /// since `start()` enforces the invariant, but this is also reused by
    /// `reconcileLiveActivities()` where that invariant can't be assumed to
    /// have held (e.g. right after a raw `importJSON` replace).
    private func fetchRunningSessions() throws -> [Session] {
        let runningPredicate = #Predicate<Session> { $0.endedAt == nil }
        return try modelContext.fetch(FetchDescriptor<Session>(predicate: runningPredicate))
    }

    /// At most one session may be running at a time: starting one ends
    /// whichever other session (in any category) was running. Explicitly
    /// saves immediately so a force-quit right after this call can't lose
    /// the running session.
    @discardableResult
    func start(category: Category) throws -> Session {
        let moment = now()
        let currentlyRunning = try fetchRunningSessions()
        for session in currentlyRunning {
            session.endedAt = moment
            if let endedCategory = session.category {
                liveActivityManager.end(categoryId: endedCategory.id)
            }
        }

        let session = Session(startedAt: moment, category: category)
        modelContext.insert(session)
        try modelContext.save()

        let remainingAtStart = remaining(category, in: currentWeekInterval())
        let deadline: Date? = remainingAtStart > 0 ? moment.addingTimeInterval(remainingAtStart) : nil
        liveActivityManager.start(categoryId: category.id, categoryName: category.name, startedAt: moment, budgetDeadline: deadline)

        return session
    }

    /// Idempotent: if `category` has no running session (e.g. a double-tap
    /// racing an already-processed stop), this is a silent no-op — it never
    /// creates a second entry or throws.
    func stop(category: Category) throws {
        guard let session = runningSession(for: category) else { return }
        session.endedAt = now()
        try modelContext.save()
        liveActivityManager.end(categoryId: category.id)
    }

    /// Records a manual time adjustment for when the user forgot to hit
    /// start. `hours` may be negative (subtracting time); `0` is a no-op.
    /// Represented as a synthetic session anchored at `now()` — see
    /// `Session.manualAdjustment` for how the sign is encoded.
    func adjust(category: Category, byHours hours: Double) throws {
        guard hours != 0 else { return }
        let anchor = now()
        let end = anchor.addingTimeInterval(hours * 3600)
        let session = Session(startedAt: anchor, endedAt: end, manualAdjustment: true, category: category)
        modelContext.insert(session)
        try modelContext.save()
    }

    /// The running session for `category`, if any.
    func runningSession(for category: Category) -> Session? {
        category.sessions.first { $0.endedAt == nil }
    }

    // MARK: - Week window

    func currentWeekInterval() -> DateInterval {
        WeekWindow.containing(now(), calendar: calendar)
    }

    /// `weeksAgo == 0` is the current week.
    func weekInterval(weeksAgo: Int) -> DateInterval {
        WeekWindow.weeksAgo(weeksAgo, from: now(), calendar: calendar)
    }

    func daysLeftInWeek() -> Int {
        WeekWindow.daysLeftInWeek(from: now(), calendar: calendar)
    }

    // MARK: - Derived reads

    /// Sum of `category`'s session durations intersecting `week`. Never
    /// stored — always recomputed from `startedAt`/`endedAt` on read.
    func spent(_ category: Category, in week: DateInterval) -> TimeInterval {
        let moment = now()
        return category.sessions.reduce(0) { $0 + TimeMath.overlap(of: $1, with: week, asOf: moment) }
    }

    /// May be negative — going over budget is fine, it's just information.
    func remaining(_ category: Category, in week: DateInterval) -> TimeInterval {
        category.weeklyHours * 3600 - spent(category, in: week)
    }

    func totalRemaining(_ categories: [Category], in week: DateInterval) -> TimeInterval {
        categories.reduce(0) { $0 + remaining($1, in: week) }
    }

    /// Sum of every category's `weeklyHours`, in hours — the static "how much
    /// of the week is committed" total. Independent of week window or session
    /// data; distinct from `totalRemaining`, which is live and burn-adjusted.
    func totalAllocatedHours(_ categories: [Category]) -> Double {
        categories.reduce(0) { $0 + $1.weeklyHours }
    }

    // MARK: - Category CRUD

    func addCategory(name: String, weeklyHours: Double) throws {
        let existing = try modelContext.fetch(FetchDescriptor<Category>())
        let nextSortOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(Category(name: name, weeklyHours: weeklyHours, sortOrder: nextSortOrder))
        try modelContext.save()
    }

    func rename(_ category: Category, to name: String) throws {
        category.name = name
        try modelContext.save()
    }

    func setWeeklyHours(_ category: Category, hours: Double) throws {
        category.weeklyHours = hours
        try modelContext.save()

        // A running session's Live Activity countdown was computed off the
        // old budget — refresh it so the lock screen doesn't silently lie
        // about how much time is left. (Renaming a category, by contrast,
        // is left alone: `categoryName` is a static ActivityAttributes
        // field, so reflecting it would mean ending and re-requesting the
        // Activity, causing a visible flicker for a purely cosmetic edit.)
        if runningSession(for: category) != nil {
            let remainingNow = remaining(category, in: currentWeekInterval())
            let deadline: Date? = remainingNow > 0 ? now().addingTimeInterval(remainingNow) : nil
            liveActivityManager.updateBudgetDeadline(categoryId: category.id, budgetDeadline: deadline)
        }
    }

    /// Cascade delete rule on `Category.sessions` removes its sessions too —
    /// no orphaned rows, no separate cleanup needed here. If `category` has
    /// a running session, its Live Activity is ended too — otherwise it
    /// would be orphaned on the lock screen with no session left to stop it.
    func delete(_ category: Category) throws {
        let hadRunningSession = runningSession(for: category) != nil
        modelContext.delete(category)
        try modelContext.save()
        if hadRunningSession {
            liveActivityManager.end(categoryId: category.id)
        }
    }

    func move(_ categories: [Category], fromOffsets: IndexSet, toOffset: Int) throws {
        var reordered = categories
        reordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, category) in reordered.enumerated() {
            category.sortOrder = index
        }
        try modelContext.save()
    }

    // MARK: - Import / export

    func exportJSON() throws -> Data {
        let categories = try modelContext.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))
        let sessions = try modelContext.fetch(FetchDescriptor<Session>())
        return try DataTransfer.encode(categories: categories, sessions: sessions)
    }

    /// Destructive replace-all: every existing category and session is
    /// deleted and replaced with the contents of `data`. The caller is
    /// responsible for confirming this with the user first. The payload is
    /// fully validated (via `DataTransfer.decode`) before any deletion
    /// happens, so a malformed file never touches existing data.
    func importJSON(_ data: Data) throws {
        let payload = try DataTransfer.decode(data)

        let existingSessions = try modelContext.fetch(FetchDescriptor<Session>())
        for session in existingSessions { modelContext.delete(session) }
        let existingCategories = try modelContext.fetch(FetchDescriptor<Category>())
        for category in existingCategories { modelContext.delete(category) }

        var categoriesById: [UUID: Category] = [:]
        for dto in payload.categories {
            let category = Category(id: dto.id, name: dto.name, weeklyHours: dto.weeklyHours, sortOrder: dto.sortOrder)
            modelContext.insert(category)
            categoriesById[dto.id] = category
        }
        for dto in payload.sessions {
            let category = dto.categoryId.flatMap { categoriesById[$0] }
            let session = Session(id: dto.id, startedAt: dto.startedAt, endedAt: dto.endedAt, manualAdjustment: dto.manualAdjustment, category: category)
            modelContext.insert(session)
        }

        try modelContext.save()

        // This replace-all bypasses start()/stop() entirely, so it can leave
        // a pre-import Live Activity pointing at a category that's gone (or
        // no longer running), and/or restore an `endedAt == nil` session
        // with no Live Activity ever requested for it. Self-heal immediately
        // rather than waiting for the next foreground.
        reconcileLiveActivities()
    }

    // MARK: - Live Activity reconciliation

    /// Brings the system's set of active Live Activities back in line with
    /// what `Session`/`Category` data actually says is running. Needed
    /// because a Live Activity can diverge from the persisted running
    /// session for reasons outside `start()`/`stop()`'s control: iOS's ~8h
    /// staleness limit killing an Activity out from under a still-running
    /// session, a device reboot, or a destructive `importJSON` replace.
    ///
    /// Non-throwing and error-swallowing by design: this runs on app launch
    /// and on every foreground transition (see `BurndownApp.init()` and
    /// `HomeView`'s `scenePhase` handling), neither of which should ever be
    /// blocked or crashed by a reconciliation failure.
    func reconcileLiveActivities() {
        let running = (try? fetchRunningSessions())?.first
        let expectedCategoryId = running?.category?.id
        let activeCategoryIds = liveActivityManager.activeCategoryIds()

        // End every Activity that doesn't match the one session that should
        // actually be running (covers "activity but no session" and any
        // stray extras, while never touching the one that's already correct
        // — restarting a correct Activity would cause a visible flicker).
        for categoryId in activeCategoryIds where categoryId != expectedCategoryId {
            liveActivityManager.end(categoryId: categoryId)
        }

        // "Session but no matching activity" — (re)start it using the
        // session's TRUE persisted startedAt, not now(), so elapsed resumes
        // correctly. This is also what seamlessly resurrects an Activity
        // that iOS killed for staleness.
        if let running, let category = running.category, let expectedCategoryId,
           !activeCategoryIds.contains(expectedCategoryId) {
            let remainingNow = remaining(category, in: currentWeekInterval())
            let deadline: Date? = remainingNow > 0 ? now().addingTimeInterval(remainingNow) : nil
            liveActivityManager.start(categoryId: category.id, categoryName: category.name, startedAt: running.startedAt, budgetDeadline: deadline)
        }
    }
}
