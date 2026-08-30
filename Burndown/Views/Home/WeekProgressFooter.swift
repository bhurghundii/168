import SwiftUI

/// Small, de-emphasised — this is context, not something to act on.
struct WeekProgressFooter: View {
    @Environment(TimeStore.self) private var store

    var body: some View {
        Text(daysLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var daysLabel: String {
        let days = store.daysLeftInWeek()
        return days == 1 ? "1 day left this week" : "\(days) days left this week"
    }
}
