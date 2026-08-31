import SwiftUI
import UniformTypeIdentifiers

/// A minimal `FileDocument` wrapper so `.fileExporter` can hand the user a
/// raw JSON blob without any custom serialization at the view layer.
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Export/import — the only two data-management controls in the app.
/// Import is a destructive replace-all, gated behind an in-app confirmation
/// alert, and the payload is validated before that confirmation is even
/// shown (so a malformed file never prompts to wipe existing data).
struct ExportImportSection: View {
    @Environment(TimeStore.self) private var store

    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDocument: JSONDocument?
    @State private var pendingImportData: Data?
    @State private var showReplaceConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        Section("Data") {
            Button("Export JSON") {
                guard let data = try? store.exportJSON() else { return }
                exportDocument = JSONDocument(data: data)
                isExporting = true
            }
            Button("Import JSON") {
                isImporting = true
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "burndown-export"
        ) { _ in }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = "Couldn't read that file."
                return
            }
            guard (try? DataTransfer.decode(data)) != nil else {
                errorMessage = "That file isn't a valid 168 export."
                return
            }
            pendingImportData = data
            showReplaceConfirmation = true
        }
        .alert("Replace all data?", isPresented: $showReplaceConfirmation, presenting: pendingImportData) { data in
            Button("Replace All Data", role: .destructive) {
                try? store.importJSON(data)
                pendingImportData = nil
            }
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
            }
        } message: { _ in
            Text("This replaces every category and session currently in 168. This can't be undone.")
        }
        .alert("Import failed", isPresented: errorAlertBinding) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}
