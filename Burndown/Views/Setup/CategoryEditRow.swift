import SwiftUI

struct CategoryEditRow: View {
    @Environment(TimeStore.self) private var store
    @Bindable var category: Category

    var body: some View {
        HStack {
            TextField("Name", text: $category.name)
                .onSubmit { try? store.rename(category, to: category.name) }
            Spacer()
            TextField("Hours", value: $category.weeklyHours, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
                .onSubmit { try? store.setWeeklyHours(category, hours: category.weeklyHours) }
            Text("h/wk")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
