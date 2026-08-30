import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    var startedAt: Date
    /// nil == currently running.
    var endedAt: Date?
    /// true for hours typed in after the fact via manual adjust.
    ///
    /// A manual adjustment is encoded as a synthetic session anchored at the
    /// moment it was made: `endedAt = startedAt + adjustmentHours*3600`. A
    /// *negative* adjustment (subtracting hours) is represented by letting
    /// `endedAt` precede `startedAt` — this is the one place the otherwise-true
    /// invariant "endedAt >= startedAt, or nil while running" is relaxed, and
    /// it only ever applies to `manualAdjustment == true` rows (which are never
    /// "running", since their `endedAt` is non-nil the instant they're
    /// created). See `TimeMath.overlap` for how this sign is consumed.
    var manualAdjustment: Bool
    var category: Category?

    init(id: UUID = UUID(), startedAt: Date, endedAt: Date? = nil, manualAdjustment: Bool = false, category: Category? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.manualAdjustment = manualAdjustment
        self.category = category
    }
}
