import SwiftData
import SwiftUI

/// Add / rename / reorder / delete categories, set weekly hours, export or
/// import JSON. Nothing else — no other settings.
struct SetupView: View {
    @Environment(TimeStore.self) private var store
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var isAddingCategory = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    BudgetAllocationSummary(allocatedHours: store.totalAllocatedHours(categories))
                }

                Section("Categories") {
                    ForEach(categories) { category in
                        CategoryEditRow(category: category)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            try? store.delete(categories[index])
                        }
                    }
                    .onMove { source, destination in
                        try? store.move(categories, fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        isAddingCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus")
                    }
                }

                ExportImportSection()
            }
            .navigationTitle("Setup")
            .toolbar {
                EditButton()
            }
            .sheet(isPresented: $isAddingCategory) {
                AddCategorySheet()
            }
        }
    }
}
