import ActivityKit
import WidgetKit
import SwiftUI

struct BurndownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BurndownActivityAttributes.self) { context in
            BurndownLiveActivityLockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.categoryName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: elapsedRange(from: context.state.startedAt), countsDown: false)
                        .monospacedDigit()
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let deadline = context.state.budgetDeadline {
                        ProgressView(timerInterval: context.state.startedAt...deadline, countsDown: true) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                    } else {
                        Text("Over budget")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(timerInterval: elapsedRange(from: context.state.startedAt), countsDown: false)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}

/// A wide-open-ended range starting at `startedAt`, used to drive an
/// elapsed-time-counting-up `Text(timerInterval:)` — the upper bound is
/// arbitrary and never meant to be reached; only `countsDown: false` and the
/// lower bound matter for this display.
func elapsedRange(from startedAt: Date) -> ClosedRange<Date> {
    startedAt...startedAt.addingTimeInterval(60 * 60 * 24 * 365)
}
