import Foundation

/// Pure week-boundary math. A "week" is Monday 00:00 -> following Monday 00:00
/// (exclusive), in the user's current calendar and time zone.
///
/// Every function here takes its `Calendar`/`Date` explicitly rather than
/// reaching for `Calendar.current`/`Date()` internally, so tests can pin both
/// and exercise DST transitions deterministically. Production call sites use
/// the defaults, which resolve to the real current calendar/clock.
///
/// Deliberately never does `date.addingTimeInterval(7 * 24 * 3600)` — that
/// breaks across DST transitions (23h/25h days). `Calendar.dateInterval(of:for:)`
/// is the DST-safe primitive and is used throughout.
enum WeekWindow {
    /// A calendar configured so weeks start on Monday.
    static func mondayStart(from base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    /// The Monday-00:00 -> next-Monday-00:00 interval containing `date`.
    static func containing(_ date: Date, calendar: Calendar) -> DateInterval {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            // dateInterval(of:for:) only fails for calendars/components that don't
            // support the query; .weekOfYear on any real Calendar always succeeds.
            preconditionFailure("Calendar \(calendar.identifier) could not compute a week interval")
        }
        return interval
    }

    /// The week interval `n` weeks before the week containing `now`. `n == 0`
    /// is the current week.
    static func weeksAgo(_ n: Int, from now: Date, calendar: Calendar) -> DateInterval {
        let current = containing(now, calendar: calendar)
        guard n != 0 else { return current }
        guard let shiftedStart = calendar.date(byAdding: .weekOfYear, value: -n, to: current.start) else {
            preconditionFailure("Calendar \(calendar.identifier) could not shift by \(n) weeks")
        }
        return containing(shiftedStart, calendar: calendar)
    }

    /// Number of calendar days remaining in the week containing `now`,
    /// counting the current day. Monday -> 7, Sunday -> 1.
    static func daysLeftInWeek(from now: Date, calendar: Calendar) -> Int {
        let week = containing(now, calendar: calendar)
        let startOfToday = calendar.startOfDay(for: now)
        let daysElapsed = calendar.dateComponents([.day], from: week.start, to: startOfToday).day ?? 0
        return max(1, 7 - daysElapsed)
    }
}
