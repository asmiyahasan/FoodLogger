import SwiftUI
import SwiftData
import PhotosUI

/// Photo + voice capture. Claude matches the meal to database foods, then the
/// review screen (MealEditorView) opens in the same sheet.
struct CaptureView: View {
    let defaultDate: Date

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserFood.lastUsed, order: .reverse) private var myFoods: [UserFood]

    @State private var photoData: Data?
    @State private var libraryItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var recorder = SpeechRecorder()
    @State private var transcript = ""
    @State private var isAnalysing = false
    @State private var progress = ""
    @State private var errorMessage: String?
    @State private var review: Review?

    struct Review {
        var drafts: [DraftItem]
        var photo: Data?
        var transcript: String
    }

    private var canAnalyse: Bool {
        !isAnalysing && (photoData != nil || !transcript.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        if let review {
            MealEditorView(
                defaultDate: defaultDate,
                drafts: review.drafts,
                photo: review.photo,
                transcript: review.transcript
            )
        } else {
            NavigationStack {
                Form {
                    photoSection
                    voiceSection
                    analyseSection
                }
                .navigationTitle("Log a meal")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            recorder.stop()
                            dismiss()
                        }
                    }
                }
                #if os(iOS)
                .fullScreenCover(isPresented: $showingCamera) {
                    CameraPicker { data in photoData = data }
                        .ignoresSafeArea()
                }
                #endif
                .onChange(of: libraryItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            photoData = data
                        }
                        libraryItem = nil
                    }
                }
                .onChange(of: recorder.transcript) { _, text in
                    if recorder.isRecording { transcript = text }
                }
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section("Photo") {
            if let photoData, let image = Image(imageData: photoData) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button("Remove photo", systemImage: "xmark", role: .destructive) {
                    self.photoData = nil
                }
            } else {
                #if os(iOS)
                Button("Take photo", systemImage: "camera") {
                    showingCamera = true
                }
                #endif
                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Label("Choose from library", systemImage: "photo")
                }
            }
        }
    }

    private var voiceSection: some View {
        Section {
            TextField("e.g. a sandwich with 1 fried egg, two turkey slices and mayo", text: $transcript, axis: .vertical)
                .lineLimit(3...6)
            Button {
                Task {
                    if recorder.isRecording {
                        recorder.stop()
                    } else {
                        await recorder.start(after: transcript)
                    }
                }
            } label: {
                Label(
                    recorder.isRecording ? "Stop recording" : "Describe it out loud",
                    systemImage: recorder.isRecording ? "stop.circle.fill" : "mic"
                )
                .foregroundStyle(recorder.isRecording ? Color.red : Color.accentColor)
            }
            if let message = recorder.errorMessage {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("What's in it")
        } footer: {
            Text("Say what the photo can't show: fillings, sauces, how it was cooked. You can fix any misheard words.")
        }
    }

    private var analyseSection: some View {
        Section {
            Button {
                Task { await analyse() }
            } label: {
                HStack {
                    Spacer()
                    if isAnalysing {
                        ProgressView()
                        Text(progress.isEmpty ? "Analysing…" : progress)
                    } else {
                        Label("Analyse meal", systemImage: "sparkles")
                            .font(.headline)
                    }
                    Spacer()
                }
            }
            .disabled(!canAnalyse)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } footer: {
            Text("Nutrition values always come from the food databases. You'll review every item before it's saved.")
        }
    }

    // MARK: - Analysis

    private func analyse() async {
        recorder.stop()
        guard let key = APIKeys.value(for: .claudeAPIKey) else {
            errorMessage = MealParserError.missingKey.errorDescription
            return
        }
        isAnalysing = true
        errorMessage = nil
        progress = ""
        defer { isAnalysing = false }

        let upload = photoData.flatMap { ImagePrep.jpegForUpload($0) }
        let spoken = transcript
        let parser = ClaudeMealParser(
            apiKey: key,
            engine: FoodSearchEngine(
                userFoods: myFoods.map(\.candidate),
                usdaKey: APIKeys.value(for: .usdaAPIKey)
            ),
            onProgress: { message in
                Task { @MainActor in progress = message }
            }
        )

        do {
            let items = try await parser.parse(imageJPEG: upload, transcript: spoken)
            review = Review(
                drafts: items.map { DraftItem(parsed: $0) },
                photo: upload,
                transcript: spoken
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    CaptureView(defaultDate: .now)
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self], inMemory: true)
}
