import SwiftUI

/// "How much of the week is committed" — same look wherever it appears
/// (Setup, Home, and the add-category sheet).
struct BudgetAllocationSummary: View {
    let allocatedHours: Double

    private var health: BudgetHealth { BudgetHealth.level(forAllocatedHours: allocatedHours) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(allocatedHours, format: .number.precision(.fractionLength(0...1))) / \(Int(BudgetHealth.totalWeeklyHours))h allocated")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(health.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(health.color)
            }
            ProgressBar(fraction: allocatedHours / BudgetHealth.totalWeeklyHours, fillColor: health.color)
        }
    }
}
