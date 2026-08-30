import SwiftUI

struct CategoryHistorySection: View {
    @Environment(TimeStore.self) private var store
    let category: Category

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.name)
                    .font(.headline)
                Spacer()
                Text("target \(Formatting.remainingLabel(seconds: category.weeklyHours * 3600))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(Formatting.remainingLabel(seconds: averageSpentSeconds))
                    .font(.title2.bold())
                    .monospacedDigit()
                Text("average — your real capacity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<8, id: \.self) { index in
                    weekBar(weeksAgo: 7 - index)
                }
            }
            .frame(height: 48)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Average `spent` over the last 8 *completed* weeks (weeksAgo 1...8) —
    /// deliberately excludes the current, in-progress week, which would
    /// otherwise skew this number down for reasons unrelated to actual
    /// capacity. The strip below still shows the current week live (weeksAgo
    /// 0), for context, alongside the 7 completed weeks before it — the two
    /// are different 8-week windows by one week, by design.
    private var averageSpentSeconds: TimeInterval {
        let totalSeconds = (1...8).reduce(0.0) { partial, weeksAgo in
            partial + store.spent(category, in: store.weekInterval(weeksAgo: weeksAgo))
        }
        return totalSeconds / 8
    }

    private func weekBar(weeksAgo: Int) -> some View {
        let week = store.weekInterval(weeksAgo: weeksAgo)
        let spentSeconds = store.spent(category, in: week)
        let allocatedSeconds = category.weeklyHours * 3600
        let fraction = allocatedSeconds > 0 ? spentSeconds / allocatedSeconds : 0

        return GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 3)
                    .fill(fraction > 1 ? Color.red : Color("AccentBurn"))
                    .frame(height: geometry.size.height * min(max(fraction, 0.02), 1))
            }
        }
    }
}
