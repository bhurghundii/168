import Foundation

/// First-run default categories. These come from a real week's budget and
/// are floors, not targets — the History screen exists to find out how wrong
/// they are. Only ever inserted once, when the store is empty.
enum SeedData {
    static let defaults: [(name: String, weeklyHours: Double)] = [
        ("Albert", 14),
        ("grumpy.dev", 6),
        ("Gym", 6),
        ("Art", 10),
        ("Hindi", 2),
        ("Rest", 14),
        ("Buffer", 4),
    ]
}
