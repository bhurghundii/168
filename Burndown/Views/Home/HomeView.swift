import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(TimeStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var refreshTick = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            content(for: store.currentWeekInterval(), now: context.date)
                .id(refreshTick)
        }
        .onChange(of: scenePhase) { _, phase in
            // Belt-and-suspenders: elapsed/remaining are derived on read, so
            // this is correct regardless, but forces an immediate recompute
            // the moment the app returns to foreground rather than waiting
            // up to 1s for the next TimelineView tick.
            if phase == .active {
                refreshTick += 1
            }
        }
    }

    private func content(for week: DateInterval, now: Date) -> some View {
        let totalRemaining = store.totalRemaining(categories, in: week)

        return ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(Formatting.remainingLabel(seconds: totalRemaining))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(totalRemaining < 0 ? .red : .primary)
                        .monospacedDigit()
                    Text("remaining this week")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                VStack(spacing: 8) {
                    ForEach(categories) { category in
                        // `now` is passed explicitly (not read from `store`
                        // inside the row) because ForEach treats its content
                        // closure as a pure function of each Category's
                        // identity: without an explicitly-changing parameter,
                        // SwiftUI never re-invokes a row's body on a
                        // TimelineView tick, even though this parent re-runs
                        // every second -- which is exactly why elapsed/
                        // remaining looked frozen.
                        CategoryRowView(category: category, week: week, now: now)
                    }
                }

                WeekProgressFooter()
                    .padding(.bottom, 4)
            }
            .padding(.horizontal)
        }
        .background(Color.black)
    }
}
