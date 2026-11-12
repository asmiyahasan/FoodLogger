import Foundation
import Speech
import AVFoundation
import Observation

/// Records from the microphone and turns speech into text, on-device when possible.
@Observable
final class SpeechRecorder {
    var transcript = ""
    var isRecording = false
    var errorMessage: String?

    private var session: RecognitionSession?

    /// Starts listening. New words are added after `existingText`.
    func start(after existingText: String) async {
        errorMessage = nil
        guard await SpeechPermissions.request() else {
            errorMessage = "Microphone or speech recognition access is off. Turn it on in Settings → FoodLogger."
            return
        }
        let prefix = existingText.isEmpty ? "" : existingText + " "
        transcript = existingText
        let box = WeakRecorder(self)
        do {
            session = try RecognitionSession { text in
                Task { @MainActor in
                    box.recorder?.transcript = prefix + text
                }
            }
            isRecording = true
        } catch {
            errorMessage = "Couldn't start recording: \(error.localizedDescription)"
        }
    }

    func stop() {
        session?.stop()
        isRecording = false
    }
}

/// Lets the audio callback update the recorder without keeping it alive.
private final class WeakRecorder: @unchecked Sendable {
    weak var recorder: SpeechRecorder?
    init(_ recorder: SpeechRecorder) { self.recorder = recorder }
}

nonisolated enum SpeechPermissions {
    static func request() async -> Bool {
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechAllowed else { return false }
        #if os(iOS) || os(visionOS)
        return await AVAudioApplication.requestRecordPermission()
        #else
        return await AVCaptureDevice.requestAccess(for: .audio)
        #endif
    }
}

nonisolated enum RecordingError: LocalizedError {
    case recognizerUnavailable
    var errorDescription: String? { "Speech recognition isn't available right now." }
}

/// The audio engine + recogniser for one recording. Runs off the main thread.
nonisolated final class RecognitionSession: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private var task: SFSpeechRecognitionTask?

    init(onText: @escaping @Sendable (String) -> Void) throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-AU")) ?? SFSpeechRecognizer(),
              recognizer.isAvailable
        else { throw RecordingError.recognizerUnavailable }

        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true   // private: audio stays on the phone
        }

        #if os(iOS) || os(visionOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let request = self.request
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { result, _ in
            if let result {
                onText(result.bestTranscription.formattedString)
            }
        }
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request.endAudio()
        task?.finish()   // lets the final words arrive
        #if os(iOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
