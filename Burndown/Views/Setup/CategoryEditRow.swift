import SwiftUI

struct CategoryEditRow: View {
    @Environment(TimeStore.self) private var store
    @Environment(\.editMode) private var editMode
    @Bindable var category: Category

    private var isEditing: Bool { editMode?.wrappedValue.isEditing == true }

    var body: some View {
        HStack {
            if isEditing {
                TextField("Name", text: $category.name)
                    .onSubmit { try? store.rename(category, to: category.name) }
            } else {
                Text(category.name)
            }
            Spacer()
            if isEditing {
                TextField("Hours", value: $category.weeklyHours, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    .onSubmit { try? store.setWeeklyHours(category, hours: category.weeklyHours) }
            } else {
                Text(category.weeklyHours, format: .number)
                    .foregroundStyle(.secondary)
            }
            Text("h/wk")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        // Tapping "Edit" is the only way in; leaving edit mode commits
        // whatever's in the fields even if the user never hit the
        // (nonexistent, for a decimal pad) return key to trigger onSubmit.
        .onChange(of: isEditing) { wasEditing, isNowEditing in
            if wasEditing && !isNowEditing {
                try? store.rename(category, to: category.name)
                try? store.setWeeklyHours(category, hours: category.weeklyHours)
            }
        }
    }
}
