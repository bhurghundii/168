import SwiftUI

/// The lock-screen / notification-banner presentation of a running category
/// timer. Everything here ticks itself via `Text`/`ProgressView(timerInterval:)`
/// — this view (and the widget process it runs in) never computes elapsed or
/// remaining time; it only hands the system two `Date`s per row.
struct BurndownLiveActivityLockScreenView: View {
    let attributes: BurndownActivityAttributes
    let state: BurndownActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(attributes.categoryName)
                .font(.headline)
                .lineLimit(1)

            Text(timerInterval: elapsedRange(from: state.startedAt), countsDown: false)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()

            if let deadline = state.budgetDeadline {
                ProgressView(timerInterval: state.startedAt...deadline, countsDown: true) {
                    Text("Time remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } currentValueLabel: {
                    Text(timerInterval: state.startedAt...deadline, countsDown: true)
                        .font(.caption)
                        .monospacedDigit()
                }
            } else {
                Text("Over budget")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .activityBackgroundTint(Color.black)
        .activitySystemActionForegroundColor(Color.white)
    }
}
