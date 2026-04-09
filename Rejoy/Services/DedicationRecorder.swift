import Foundation
import AVFoundation
import Speech

/// Live dictation via `AVAudioEngine` + `SFSpeechAudioBufferRecognitionRequest` (final transcript after stop; no partial UI).
/// Simulator: speech may be unavailable; same as before.
final class DedicationRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText: String?
    @Published var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var pendingStopCompletion: ((String?) -> Void)?
    private var finalizeFallback: DispatchWorkItem?

    var canRecord: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized &&
        AVAudioSession.sharedInstance().recordPermission == .granted
    }

    func startRecording() {
        errorMessage = nil
        transcribedText = nil
        cancelFinalizeFallback()
        pendingStopCompletion = nil

        tearDownAudioEngineSilently()

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        guard let recognizer = pickRecognizer() else {
            errorMessage = "Speech recognition unavailable"
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Could not start recording"
            return
        }

        let audioEngine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.handleRecognitionError(error)
                }
                return
            }
            guard let result = result else { return }
            let text = result.bestTranscription.formattedString
            DispatchQueue.main.async {
                self.transcribedText = text.isEmpty ? nil : text
                if result.isFinal {
                    self.deliverPendingStopIfNeeded(finalText: text.isEmpty ? nil : text)
                }
            }
        }

        let inputNode = audioEngine.inputNode
        var recordingFormat = inputNode.outputFormat(forBus: 0)
        if recordingFormat.sampleRate == 0 || recordingFormat.channelCount == 0 {
            recordingFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 44100,
                channels: 1,
                interleaved: false
            ) ?? inputNode.outputFormat(forBus: 0)
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        self.audioEngine = audioEngine

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Could not start recorder"
            tearDownAudioEngineSilently()
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
        }
    }

    func stopRecordingAndTranscribe(completion: @escaping (String?) -> Void) {
        guard isRecording else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        pendingStopCompletion = completion
        isRecording = false

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        recognitionRequest?.endAudio()

        let fallback = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let text = self.transcribedText
            self.deliverPendingStopIfNeeded(finalText: text)
        }
        finalizeFallback = fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: fallback)
    }

    private func handleRecognitionError(_ error: Error) {
        errorMessage = error.localizedDescription
        if pendingStopCompletion != nil {
            deliverPendingStopIfNeeded(finalText: transcribedText)
        } else if isRecording {
            tearDownAfterFailure()
        }
    }

    private func tearDownAfterFailure() {
        isRecording = false
        tearDownAudioEngineSilently()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch { }
    }

    private func deliverPendingStopIfNeeded(finalText: String?) {
        cancelFinalizeFallback()
        guard let completion = pendingStopCompletion else { return }
        pendingStopCompletion = nil

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch { }

        let trimmed = finalText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let out = (trimmed?.isEmpty == false) ? trimmed : nil
        transcribedText = out
        completion(out)
    }

    private func cancelFinalizeFallback() {
        finalizeFallback?.cancel()
        finalizeFallback = nil
    }

    private func tearDownAudioEngineSilently() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }

    private func pickRecognizer() -> SFSpeechRecognizer? {
        localesToTry()
            .lazy
            .compactMap { SFSpeechRecognizer(locale: $0) }
            .first { $0.isAvailable }
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
}
