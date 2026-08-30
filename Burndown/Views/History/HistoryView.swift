import SwiftData
import SwiftUI

/// Last 8 weeks: allocated vs actual, per category. See
/// `CategoryHistorySection` for the averaging window.
struct HistoryView: View {
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(categories) { category in
                        CategoryHistorySection(category: category)
                    }
                }
                .padding()
            }
            .navigationTitle("History")
        }
    }
}
