import Foundation

/// Versioned, self-contained JSON schema for export/import (Setup screen).
/// Import is a destructive replace-all operation — see `DataTransfer`.
struct ExportPayloadV1: Codable {
    static let currentVersion = 1

    var version: Int = ExportPayloadV1.currentVersion
    var categories: [CategoryDTO]
    var sessions: [SessionDTO]
}

struct CategoryDTO: Codable {
    var id: UUID
    var name: String
    var weeklyHours: Double
    var sortOrder: Int
}

struct SessionDTO: Codable {
    var id: UUID
    var categoryId: UUID?
    var startedAt: Date
    var endedAt: Date?
    var manualAdjustment: Bool
}

enum DataTransferError: Error, Equatable {
    case unsupportedVersion(Int)
    case sessionReferencesUnknownCategory(UUID)
}
