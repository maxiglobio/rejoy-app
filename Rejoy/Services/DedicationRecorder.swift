import Foundation
import AVFoundation
import Speech

/// Records voice and transcribes to text. Simulator fallback: returns nil for transcription.
final class DedicationRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText: String?
    @Published var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recognitionTask: SFSpeechRecognitionTask?

    var canRecord: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized &&
        AVAudioSession.sharedInstance().recordPermission == .granted
    }

    func startRecording() {
        errorMessage = nil
        transcribedText = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            errorMessage = "Could not start recording"
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent(UUID().uuidString + ".m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            errorMessage = "Could not start recorder"
        }
    }

    func stopRecordingAndTranscribe(completion: @escaping (String?) -> Void) {
        guard isRecording, let recorder = audioRecorder, let url = recordingURL else {
            completion(nil)
            return
        }

        recorder.stop()
        isRecording = false
        audioRecorder = nil

        transcribe(url: url) { [weak self] text in
            DispatchQueue.main.async {
                self?.transcribedText = text
                completion(text)
            }
        }
    }

    /// Fallback locales when no explicit preference is set.
    private static let fallbackLocales: [Locale] = [
        Locale(identifier: "ru-RU"),
        Locale(identifier: "ru"),
        Locale.current,
        Locale(identifier: "en-US"),
        Locale(identifier: "en")
    ]

    private func localesToTry() -> [Locale] {
        let preferred = AppSettings.recognitionLocaleIdentifier
        if !preferred.isEmpty {
            return [Locale(identifier: preferred)] + Self.fallbackLocales
        }
        return Self.fallbackLocales
    }

    private func transcribe(url: URL, completion: @escaping (String?) -> Void) {
        let recognizer = localesToTry()
            .lazy
            .compactMap { SFSpeechRecognizer(locale: $0) }
            .first { $0.isAvailable }

        guard let recognizer = recognizer else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            if let result = result, result.isFinal {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async { completion(text.isEmpty ? nil : text) }
            } else if let result = result, !result.isFinal, !result.bestTranscription.formattedString.isEmpty {
                DispatchQueue.main.async { completion(result.bestTranscription.formattedString) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}
