import SwiftUI

/// Long-press a category row -> this menu appears; one more tap on any
/// button commits the adjustment. `.contextMenu`'s native long-press trigger
/// gets "long-press -> commit" down to a single subsequent tap, with no
/// custom gesture code, satisfying the spec's "≤2 taps" recovery-path
/// requirement.
struct ManualAdjustMenu: View {
    @Environment(TimeStore.self) private var store
    let category: Category

    var body: some View {
        Group {
            Button("+15m") { adjust(0.25) }
            Button("+30m") { adjust(0.5) }
            Button("+1h") { adjust(1) }
            Divider()
            Button("-15m", role: .destructive) { adjust(-0.25) }
            Button("-30m", role: .destructive) { adjust(-0.5) }
            Button("-1h", role: .destructive) { adjust(-1) }
        }
    }

    private func adjust(_ hours: Double) {
        try? store.adjust(category: category, byHours: hours)
    }
}
