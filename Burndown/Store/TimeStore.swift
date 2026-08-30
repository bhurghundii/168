import Foundation
import Observation
import SwiftData

/// The single facade for every mutation and every derived read in the app.
/// Views read model objects via `@Query` (always in sync with SwiftData's
/// change tracking); everything else — starting/stopping a timer, manual
/// adjustments, category CRUD, seeding, import/export, and all week-window
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

    init(modelContext: ModelContext, calendar: Calendar = WeekWindow.mondayStart(), now: @escaping () -> Date = Date.init) {
        self.modelContext = modelContext
        self.calendar = calendar
        self.now = now
    }

    // MARK: - Seeding

    /// Inserts the default categories if the store is empty. Safe to call
    /// every launch — a no-op once any category exists.
    func seedIfNeeded() throws {
        let count = try modelContext.fetchCount(FetchDescriptor<Category>())
        guard count == 0 else { return }
        for (index, seed) in SeedData.defaults.enumerated() {
            modelContext.insert(Category(name: seed.name, weeklyHours: seed.weeklyHours, sortOrder: index))
        }
        try modelContext.save()
    }

    // MARK: - Session lifecycle

    /// At most one session may be running at a time: starting one ends
    /// whichever other session (in any category) was running. Explicitly
    /// saves immediately so a force-quit right after this call can't lose
    /// the running session.
    @discardableResult
    func start(category: Category) throws -> Session {
        let moment = now()
        let runningPredicate = #Predicate<Session> { $0.endedAt == nil }
        let currentlyRunning = try modelContext.fetch(FetchDescriptor<Session>(predicate: runningPredicate))
        for session in currentlyRunning {
            session.endedAt = moment
        }

        let session = Session(startedAt: moment, category: category)
        modelContext.insert(session)
        try modelContext.save()
        return session
    }

    /// Idempotent: if `category` has no running session (e.g. a double-tap
    /// racing an already-processed stop), this is a silent no-op — it never
    /// creates a second entry or throws.
    func stop(category: Category) throws {
        guard let session = runningSession(for: category) else { return }
        session.endedAt = now()
        try modelContext.save()
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
    }

    /// Cascade delete rule on `Category.sessions` removes its sessions too —
    /// no orphaned rows, no separate cleanup needed here.
    func delete(_ category: Category) throws {
        modelContext.delete(category)
        try modelContext.save()
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
    }
}
