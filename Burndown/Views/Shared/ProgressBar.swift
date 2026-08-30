import SwiftUI

/// A thin horizontal progress bar. Fills 0-100% of the budget in the accent
/// color; once spent reaches or exceeds the budget, the whole bar switches
/// to `overColor` rather than trying to render past 100% width — clearer at
/// a glance than a bar that keeps growing.
struct ProgressBar: View {
    /// spent / weeklyHours. May exceed 1 — going over is fine, it's just
    /// rendered distinctly.
    let fraction: Double
    var fillColor: Color = Color("AccentBurn")
    var overColor: Color = .red

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(fraction >= 1 ? overColor : fillColor)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 4)
    }
}
