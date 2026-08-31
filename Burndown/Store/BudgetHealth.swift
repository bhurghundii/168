import SwiftUI

/// Traffic-light read on how much of the week's 168 hours has been
/// allocated across every category's `weeklyHours` — a *static* budgeting
/// signal, independent of any week's actual burn (see `TimeStore.totalRemaining`
/// for that). Thresholds account for what allocated hours don't show: sleep
/// (~56h/wk) and daily maintenance — eating, washing, resting, taking
/// breaks (~20h/wk) — are never in a category, but still have to fit in
/// what's left of the week. `.comfy` leaves plenty of that unaccounted-for
/// time; `.tight` starts eating into it; `.critical` leaves too little of
/// the week unspoken-for to actually live.
enum BudgetHealth {
    case comfy, tight, critical

    static let totalWeeklyHours: Double = 168
    /// Allocated hours at/under this stay green.
    static let comfyCeiling: Double = 60
    /// Allocated hours at/under this are yellow; above it is red.
    static let tightCeiling: Double = 80

    static func level(forAllocatedHours hours: Double) -> BudgetHealth {
        switch hours {
        case ...comfyCeiling: return .comfy
        case ...tightCeiling: return .tight
        default: return .critical
        }
    }

    var color: Color {
        switch self {
        case .comfy: return .green
        case .tight: return .yellow
        case .critical: return .red
        }
    }

    var label: String {
        switch self {
        case .comfy: return "Comfy"
        case .tight: return "Tight"
        case .critical: return "Critical"
        }
    }
}
