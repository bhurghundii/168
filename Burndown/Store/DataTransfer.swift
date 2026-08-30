import Foundation

/// Encoding/decoding for the Setup screen's export/import feature. Decoding
/// validates the payload (known version, every session's category reference
/// resolves) *before* `TimeStore.importJSON` deletes anything existing, so a
/// malformed file never wipes existing data.
enum DataTransfer {
    static func encode(categories: [Category], sessions: [Session]) throws -> Data {
        let payload = ExportPayloadV1(
            categories: categories.map {
                CategoryDTO(id: $0.id, name: $0.name, weeklyHours: $0.weeklyHours, sortOrder: $0.sortOrder)
            },
            sessions: sessions.map {
                SessionDTO(
                    id: $0.id,
                    categoryId: $0.category?.id,
                    startedAt: $0.startedAt,
                    endedAt: $0.endedAt,
                    manualAdjustment: $0.manualAdjustment
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    /// Decodes and validates `data`. Throws before any mutation happens if
    /// the version is unrecognized or a session references a category not
    /// present in the same payload.
    static func decode(_ data: Data) throws -> ExportPayloadV1 {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportPayloadV1.self, from: data)

        guard payload.version == ExportPayloadV1.currentVersion else {
            throw DataTransferError.unsupportedVersion(payload.version)
        }

        let categoryIds = Set(payload.categories.map(\.id))
        for session in payload.sessions {
            if let categoryId = session.categoryId, !categoryIds.contains(categoryId) {
                throw DataTransferError.sessionReferencesUnknownCategory(categoryId)
            }
        }

        return payload
    }
}
