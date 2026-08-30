import Foundation

/// The one formatting rule for a duration/remaining value, used everywhere
/// (hero number, category rows, History) so the app never has two different
/// ideas of what "-1h 30m" looks like.
///
/// Rule: round to the nearest minute (not truncate, so a value never looks
/// "stuck"); show `"-Xh Ym"` for negative values (going over is fine, just
/// rendered distinctly — see color handling in the views); always show
/// minutes when hours are present (`"2h 0m"`, not `"2h"`) for consistent
/// scan-width at a glance.
enum Formatting {
    static func remainingLabel(seconds: TimeInterval) -> String {
        let totalMinutes = Int((seconds / 60).rounded())
        let sign = totalMinutes < 0 ? "-" : ""
        let magnitude = abs(totalMinutes)
        let hours = magnitude / 60
        let minutes = magnitude % 60

        if hours > 0 {
            return "\(sign)\(hours)h \(minutes)m"
        } else {
            return "\(sign)\(minutes)m"
        }
    }

    /// Second-precision stopwatch-style label (`"1:23:45"` / `"3:07"`) for a
    /// value that's actively ticking — the running category's elapsed and
    /// remaining. `remainingLabel` rounds to the nearest minute, which is the
    /// right call for a static budget number but makes a just-started timer
    /// look frozen for up to 59 seconds; this is what actually visibly moves
    /// every second.
    static func liveLabel(seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds.rounded())
        let sign = totalSeconds < 0 ? "-" : ""
        let magnitude = abs(totalSeconds)
        let hours = magnitude / 3600
        let minutes = (magnitude % 3600) / 60
        let secs = magnitude % 60

        if hours > 0 {
            return String(format: "%@%d:%02d:%02d", sign, hours, minutes, secs)
        } else {
            return String(format: "%@%d:%02d", sign, minutes, secs)
        }
    }
}
