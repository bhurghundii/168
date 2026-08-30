import SwiftUI

/// The primary interaction of the whole app: tap a not-running row and its
/// timer starts immediately (no sheet, no confirmation). A running row is
/// highlighted, ticks live, and exposes a prominent STOP button. Long-press
/// (anywhere on the row) opens `ManualAdjustMenu`.
struct CategoryRowView: View {
    @Environment(TimeStore.self) private var store
    let category: Category
    let week: DateInterval
    /// The current tick's timestamp, passed down explicitly from HomeView's
    /// TimelineView rather than read via `store.now()` inside this view.
    /// `ForEach` treats its row-building closure as a pure function of each
    /// Category's identity, so without a parameter that actually changes
    /// every second, SwiftUI never re-invokes this row's body on a tick —
    /// only reading ambient state wouldn't do it; this stored property has
    /// to change value each render for the row to redraw at all.
    let now: Date

    var body: some View {
        let running = store.runningSession(for: category)
        let remaining = store.remaining(category, in: week)
        let spent = store.spent(category, in: week)
        let fraction = category.weeklyHours > 0 ? spent / (category.weeklyHours * 3600) : 0

        VStack(alignment: .leading, spacing: 8) {
            Text(category.name)
                .font(.headline)

            // One row, one element: elapsed (counting up) and remaining
            // (counting down) flank the same bar, both ticking every second
            // while running. Idle rows have nothing counting up, so they
            // just show the bar and the (unchanging) remaining figure.
            if let running {
                HStack(spacing: 10) {
                    Text(elapsedLabel(for: running))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 52, alignment: .leading)
                    ProgressBar(fraction: fraction)
                    Text(Formatting.liveLabel(seconds: remaining))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(remaining < 0 ? .red : .secondary)
                        .frame(minWidth: 52, alignment: .trailing)
                }

                Button {
                    try? store.stop(category: category)
                } label: {
                    Text("STOP")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                HStack(spacing: 12) {
                    ProgressBar(fraction: fraction)
                    Text(Formatting.remainingLabel(seconds: remaining))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(remaining < 0 ? .red : .secondary)
                        .frame(minWidth: 64, alignment: .trailing)
                }
            }
        }
        .padding(12)
        .background(running != nil ? Color("AccentBurn").opacity(0.18) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            // Running rows are only stopped via the explicit STOP button —
            // tapping elsewhere on a running row does nothing.
            guard running == nil else { return }
            try? store.start(category: category)
        }
        .contextMenu {
            ManualAdjustMenu(category: category)
        }
    }

    private func elapsedLabel(for session: Session) -> String {
        let elapsed = now.timeIntervalSince(session.startedAt)
        return Formatting.liveLabel(seconds: elapsed)
    }
}
