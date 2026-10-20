import SwiftUI
import VocaCore
import AVFoundation

@MainActor @Observable final class AppStore {
    var archive: Archive
    var error: String?
    var haptics = true
    private let location: URL
    private var storageReadable = true
    private let speaker = AVSpeechSynthesizer()
    var poolSize: Int {
        get { min(100, max(1, archive.studyPoolSize ?? Stack.poolLimit)) }
        set {
            archive.studyPoolSize = min(100, max(1, newValue))
            for i in archive.stacks.indices { archive.stacks[i].prepare(poolSize: poolSize) }
            save()
        }
    }
    init() {
        #if DEBUG
        let testing = ProcessInfo.processInfo.arguments.contains("--uitesting") || ProcessInfo.processInfo.arguments.contains("--uitesting-resume")
        location = testing ? URL.temporaryDirectory.appending(path: "voca-ui-tests.json") : URL.documentsDirectory.appending(path: "voca-data.json")
        if ProcessInfo.processInfo.arguments.contains("--uitesting") { try? FileManager.default.removeItem(at: location) }
        #else
        location = URL.documentsDirectory.appending(path: "voca-data.json")
        #endif
        do {
            if FileManager.default.fileExists(atPath: location.path) {
                archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: location))
            } else { archive = .sample }
        } catch {
            archive = Archive()
            storageReadable = false
            self.error = "저장된 데이터를 읽지 못했습니다. 원본 파일은 유지됩니다. 앱을 다시 실행해 주세요. \(error.localizedDescription)"
        }
        haptics = UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true
    }
    func save() {
        guard storageReadable else { error = "원본 데이터 보호를 위해 저장을 중단했습니다. 앱을 다시 실행해 주세요."; return }
        do { try JSONEncoder().encode(archive).write(to: location, options: .atomic) }
        catch { self.error = "저장하지 못했습니다: \(error.localizedDescription)" }
    }
    func update(_ stack: Stack) {
        guard let i = archive.stacks.firstIndex(where: { $0.id == stack.id }) else { return }
        archive.stacks[i] = stack; save()
    }
    func removeWord(_ wordID: UUID, from stackID: UUID) {
        guard let i = archive.stacks.firstIndex(where: { $0.id == stackID }) else { return }
        archive.stacks[i].words.removeAll { $0.id == wordID }
        archive.stacks[i].prepare(poolSize: poolSize)
        save()
    }
    func removeStack(_ stackID: UUID) {
        archive.stacks.removeAll { $0.id == stackID }
        save()
    }
    func removeLibrary(_ libraryID: UUID) {
        archive.libraries.removeAll { $0.id == libraryID }
        save()
    }
    func enroll(_ stack: Stack) {
        guard !isEnrolled(stack) else { return }
        var copy = Stack(title: stack.title, words: stack.words, sourceID: stack.id)
        copy.prepare(poolSize: poolSize); archive.stacks.append(copy); save()
    }
    func isEnrolled(_ stack: Stack) -> Bool { archive.stacks.contains { $0.sourceID == stack.id || $0.id == stack.id } }
    func publish(_ library: Library) {
        if let i = archive.server.firstIndex(where: { $0.id == library.id }) { archive.server[i] = library }
        else { archive.server.append(library) }
        save()
    }
    func speak(_ text: String) {
        speaker.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP"); utterance.rate = 0.43
        speaker.speak(utterance)
    }
    func searchJapanese(_ text: String) {
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: text)]
        guard let webURL = components.url,
              var chrome = URLComponents(url: webURL, resolvingAgainstBaseURL: false) else { return }
        chrome.scheme = "googlechromes"
        guard let chromeURL = chrome.url else { return }
        UIApplication.shared.open(chromeURL, options: [:]) { opened in
            if !opened { UIApplication.shared.open(webURL) }
        }
    }
    func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        if haptics { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    }
}
