import Foundation

/// Pure duration/overlap math shared by every "how much time was spent" query
/// in the app. One function handles real sessions, the currently-running
/// session, and both signs of a manual adjustment — see `Session.manualAdjustment`
/// for how sign is encoded on disk.
enum TimeMath {
    /// The end of a session for arithmetic purposes: its real `endedAt`, or
    /// `asOf` (typically "now") if it's still running.
    static func effectiveEnd(of session: Session, asOf: Date) -> Date {
        session.endedAt ?? asOf
    }

    /// The portion of `session`'s duration that falls within `week`
    /// (a half-open [Monday 00:00, following Monday 00:00) interval).
    ///
    /// A session that crosses a week boundary (e.g. started Sun 23:00, ended
    /// Mon 00:30) has its duration split proportionally between the two
    /// weeks it intersects — each week's total reflects the time actually
    /// worked in that calendar week, rather than attributing the whole
    /// session to whichever week it started in.
    ///
    /// Returns a *signed* duration: positive for ordinary/positive-adjustment
    /// sessions, negative when `endedAt` precedes `startedAt` (a negative
    /// manual adjustment). A still-running session (`endedAt == nil`) is
    /// always non-negative, since its effective end is `asOf`.
    static func overlap(of session: Session, with week: DateInterval, asOf: Date) -> TimeInterval {
        let start = session.startedAt
        let end = effectiveEnd(of: session, asOf: asOf)
        guard start != end else { return 0 }

        let sign: Double = end > start ? 1 : -1
        let ordered = DateInterval(start: min(start, end), end: max(start, end))
        guard let intersection = ordered.intersection(with: week) else { return 0 }
        return sign * intersection.duration
    }
}
