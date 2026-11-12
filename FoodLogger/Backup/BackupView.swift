import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Save everything to a file (e.g. iCloud Drive), or restore from one.
struct BackupView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.backupIncludesPhotos) private var includePhotos = false

    @State private var document: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingRestore: BackupFile?
    @State private var message: String?

    private var filename: String {
        "FoodLogger Backup \(Date.now.formatted(.iso8601.year().month().day()))"
    }

    var body: some View {
        Form {
            Section {
                Toggle("Include meal photos", isOn: $includePhotos)
                Button("Back up now", systemImage: "square.and.arrow.up") {
                    backUp()
                }
            } header: {
                Text("Back up")
            } footer: {
                Text("Saves meals, water, saved foods, goals and settings as one file. Choose iCloud Drive to keep it safe off your phone. Photos make the file much bigger.")
            }

            Section {
                if let last = BackupService.lastBackupDate {
                    LabeledContent("Last backup", value: last.formatted(.relative(presentation: .named)))
                } else {
                    Text("No backup yet")
                        .foregroundStyle(Theme.deepOrangeText)
                }
            }

            Section {
                Button("Restore from a backup", systemImage: "square.and.arrow.down") {
                    showingImporter = true
                }
            } footer: {
                Text("Replaces everything in the app with the backup's contents.")
            }

            if let message {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Backup")
        .inlineNavigationTitle()
        .fileExporter(
            isPresented: $showingExporter,
            document: document,
            contentType: .json,
            defaultFilename: filename
        ) { result in
            switch result {
            case .success:
                BackupService.markBackedUp()
                message = "Backup saved."
            case .failure(let error):
                message = "Couldn't save the backup: \(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            loadBackup(result)
        }
        .confirmationDialog(
            "Replace all data?",
            isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
            titleVisibility: .visible,
            presenting: pendingRestore
        ) { file in
            Button("Replace with backup", role: .destructive) { restore(file) }
            Button("Cancel", role: .cancel) {}
        } message: { file in
            Text("Backup from \(file.exportedAt.formatted(date: .abbreviated, time: .shortened)): \(file.meals.count) meals, \(file.water.count) water entries, \(file.savedFoods.count) saved foods. Everything currently in the app will be replaced.")
        }
    }

    private func backUp() {
        do {
            document = BackupDocument(data: try BackupService.makeBackup(context: context, includePhotos: includePhotos))
            showingExporter = true
        } catch {
            message = "Couldn't create the backup: \(error.localizedDescription)"
        }
    }

    private func loadBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            pendingRestore = try BackupService.read(try Data(contentsOf: url))
        } catch {
            message = error.localizedDescription
        }
    }

    private func restore(_ file: BackupFile) {
        do {
            try BackupService.restore(file, context: context)
            message = "Restored \(file.meals.count) meals, \(file.water.count) water entries and \(file.savedFoods.count) saved foods."
            Task { await WaterReminders.reschedule(context: context) }
        } catch {
            message = "Couldn't restore: \(error.localizedDescription)"
        }
    }
}
