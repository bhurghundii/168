import SwiftData
import SwiftUI

struct AddCategorySheet: View {
    @Environment(TimeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [Category]

    @State private var name = ""
    @State private var weeklyHours = ""

    private var projectedTotal: Double {
        store.totalAllocatedHours(categories) + (Double(weeklyHours) ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Weekly hours", text: $weeklyHours)
                    .keyboardType(.decimalPad)

                Section {
                    BudgetAllocationSummary(allocatedHours: projectedTotal)
                }
            }
            .navigationTitle("Add Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let hours = Double(weeklyHours) ?? 0
                        try? store.addCategory(name: name.isEmpty ? "New Category" : name, weeklyHours: hours)
                        dismiss()
                    }
                }
            }
        }
    }
}
