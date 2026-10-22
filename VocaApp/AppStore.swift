import SwiftUI
import VocaCore
import AVFoundation
import UserNotifications
import AlarmKit

@MainActor @Observable final class AppStore {
    var archive: Archive
    var error: String?
    var haptics = true
    private let location: URL
    private var storageReadable = true
    private let speaker = AVSpeechSynthesizer()
    private var reminderTask: Task<Void, Never>?
    var microSettings: MicroReviewSettings {
        get { archive.microReviewSettings ?? MicroReviewSettings() }
        set {
            archive.microReviewSettings = newValue
            save()
            scheduleMicroNotifications()
        }
    }
    var microEntries: [MicroReviewEntry] { archive.microReviewEntries ?? [] }
    var activeMicroCount: Int { microEntries.filter { $0.status == .active }.count }
    var completedMicroCount: Int { microEntries.filter { $0.status == .completed }.count }
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
    func recordMeaningCorrection(library: Library?, stack: Stack, word: Word, correctedKorean: String) {
        guard storageReadable else { error = "원본 데이터 보호를 위해 제보 저장을 중단했습니다. 앱을 다시 실행해 주세요."; return }
        archive.recordMeaningCorrection(library: library, stack: stack, word: word, correctedKorean: correctedKorean)
        save()
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
        components.queryItems = [URLQueryItem(name: "q", value: text + " 한자 해석")]
        guard let webURL = components.url,
              var chrome = URLComponents(url: webURL, resolvingAgainstBaseURL: false) else { return }
        chrome.scheme = "googlechromes"
        guard let chromeURL = chrome.url else { return }
        UIApplication.shared.open(chromeURL, options: [:]) { opened in
            if !opened { UIApplication.shared.open(webURL) }
        }
    }
    func setMicroEnabled(_ enabled: Bool) async {
        if enabled {
            do {
                let granted: Bool
                if #available(iOS 26.0, *), microSettings.usesSystemAlarm == true {
                    granted = try await AlarmManager.shared.requestAuthorization() == .authorized
                } else {
                    granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                }
                guard granted else { error = "알림이 허용되지 않았습니다. iPhone 설정에서 voca-ios 알림을 허용해 주세요."; return }
            } catch { self.error = "알림 권한을 확인하지 못했습니다: \(error.localizedDescription)"; return }
        }
        var settings = microSettings
        settings.enabled = enabled
        microSettings = settings
    }
    func addMicroWord(_ word: Word, sourceTitle: String) {
        var entries = microEntries
        if let i = entries.firstIndex(where: { $0.word.japanese == word.japanese && $0.word.korean == word.korean }) {
            if entries[i].status == .active { return }
            entries[i].word = word
            entries[i].sourceTitle = sourceTitle
            entries[i].restart()
        } else { entries.append(MicroReviewEntry(word: word, sourceTitle: sourceTitle)) }
        archive.microReviewEntries = entries
        save(); scheduleMicroNotifications()
    }
    func microEntry(for word: Word) -> MicroReviewEntry? {
        microEntries.first { $0.word.japanese == word.japanese && $0.word.korean == word.korean }
    }
    func nextMicroEntry(excluding ids: Set<UUID> = []) -> MicroReviewEntry? {
        microEntries.filter { $0.status == .active && !ids.contains($0.id) }
            .shuffled().min { ($0.lastReviewedAt ?? .distantPast) < ($1.lastReviewedAt ?? .distantPast) }
    }
    func answerMicro(_ id: UUID, known: Bool) {
        guard var entries = archive.microReviewEntries,
              let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].answer(known: known)
        archive.microReviewEntries = entries
        save(); scheduleMicroNotifications()
    }
    func stopMicro(_ id: UUID) {
        guard var entries = archive.microReviewEntries,
              let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].stop()
        archive.microReviewEntries = entries
        save(); scheduleMicroNotifications()
    }
    func restartMicro(_ id: UUID) {
        guard var entries = archive.microReviewEntries,
              let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].restart()
        archive.microReviewEntries = entries
        save(); scheduleMicroNotifications()
    }
    func removeMicro(_ id: UUID) {
        archive.microReviewEntries?.removeAll { $0.id == id }
        save(); scheduleMicroNotifications()
    }
    func scheduleMicroNotifications() {
        let previous = reminderTask
        previous?.cancel()
        let settings = microSettings
        let entries = microEntries.filter { $0.status == .active }
        reminderTask = Task {
            _ = await previous?.result
            do {
                if #available(iOS 26.0, *) {
                    try await MicroAlarmScheduler.synchronize(settings: settings)
                }
                var notificationSettings = settings
                if settings.usesSystemAlarm == true { notificationSettings.enabled = false }
                try await MicroNotificationScheduler.synchronize(settings: notificationSettings, entries: entries)
            }
            catch is CancellationError { }
            catch { self.error = "1-3-3 알림을 예약하지 못했습니다: \(error.localizedDescription)" }
        }
    }
    func setSystemAlarm(_ enabled: Bool) async {
        guard #available(iOS 26.0, *) else { return }
        do {
            if enabled {
                guard try await AlarmManager.shared.requestAuthorization() == .authorized else {
                    error = "iPhone 설정에서 voca-ios의 알람을 허용해 주세요."; return
                }
            } else if microSettings.enabled {
                guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) else {
                    error = "일반 알림 권한을 허용해 주세요."; return
                }
            }
            var updated = microSettings
            updated.usesSystemAlarm = enabled
            microSettings = updated
        } catch { self.error = "알람 권한을 확인하지 못했습니다: \(error.localizedDescription)" }
    }
    func sendMicroTestAlarm() async -> Bool {
        guard #available(iOS 26.0, *) else { return false }
        do {
            guard try await AlarmManager.shared.requestAuthorization() == .authorized else {
                error = "iPhone 설정에서 voca-ios의 알람을 허용해 주세요."; return false
            }
            try await MicroAlarmScheduler.test()
            return true
        } catch { self.error = "테스트 알람을 예약하지 못했습니다: \(error.localizedDescription)"; return false }
    }
    func sendMicroTestNotification() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else {
                error = "알림이 허용되지 않았습니다. iPhone 설정에서 voca-ios 알림을 허용해 주세요."
                return false
            }
            try await MicroNotificationScheduler.scheduleTest(entries: microEntries.filter { $0.status == .active })
            return true
        } catch {
            self.error = "테스트 알림을 예약하지 못했습니다: \(error.localizedDescription)"
            return false
        }
    }
    func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        if haptics { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    }
}

@MainActor private enum MicroNotificationScheduler {
    static let prefix = "voca.micro."
    static func content(entries: [MicroReviewEntry], index: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if entries.isEmpty {
            content.title = "1-3-3 풀이 비었어요"
            content.body = "학습 중인 카드에서 단어를 담아 보세요."
        } else {
            let entry = entries[index % entries.count]
            content.title = "1-3-3 · \(entry.successCount)/3 확인"
            content.body = entry.word.japanese
        }
        content.userInfo = ["vocaMicroReview": true]
        content.sound = .default
        content.badge = 1
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1
        return content
    }
    static func scheduleTest(entries: [MicroReviewEntry]) async throws {
        let request = UNNotificationRequest(identifier: "voca.test.micro", content: content(entries: entries, index: 0),
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        try await UNUserNotificationCenter.current().add(request)
    }
    static func synchronize(settings: MicroReviewSettings, entries: [MicroReviewEntry]) async throws {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests()
        try Task.checkCancellation()
        center.removePendingNotificationRequests(withIdentifiers: existing.map(\.identifier).filter { $0.hasPrefix(prefix) })
        guard settings.enabled else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        let dates = settings.upcomingDates(after: Date())
        let slotsPerDay = Int(ceil(Double((settings.endHour - settings.startHour) * 60) / Double(settings.intervalMinutes)))
        let repeating = slotsPerDay * (settings.includesWeekends ? 1 : 5) <= 60
        var usedSlots = Set<String>()
        for (index, date) in dates.enumerated() {
            try Task.checkCancellation()
            let fields: Set<Calendar.Component> = repeating
                ? (settings.includesWeekends ? [.hour, .minute] : [.weekday, .hour, .minute])
                : [.year, .month, .day, .hour, .minute]
            let parts = Calendar.current.dateComponents(fields, from: date)
            let slotKey = settings.includesWeekends && repeating
                ? "\(parts.hour ?? 0):\(parts.minute ?? 0)"
                : "\(parts.weekday ?? 0):\(parts.hour ?? 0):\(parts.minute ?? 0)"
            if repeating && !usedSlots.insert(slotKey).inserted { continue }
            let content = content(entries: entries, index: index)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: repeating)
            let request = UNNotificationRequest(identifier: prefix + String(Int(date.timeIntervalSince1970)), content: content, trigger: trigger)
            try await center.add(request)
            if repeating && usedSlots.count == slotsPerDay * (settings.includesWeekends ? 1 : 5) { break }
        }
    }
}

@available(iOS 26.0, *)
private struct MicroAlarmMetadata: AlarmMetadata {}

@available(iOS 26.0, *)
@MainActor private enum MicroAlarmScheduler {
    private static let prefix = "13300000-0000-4000-8000-"
    private static let testID = UUID(uuidString: "13300000-0000-4000-9000-000000000000")!
    private static func configuration(_ schedule: Alarm.Schedule, id: UUID) -> sending AlarmManager.AlarmConfiguration<MicroAlarmMetadata> {
        let open = AlarmButton(text: "1-3-3 시작", textColor: .white, systemImageName: "play.fill")
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = .init(title: "잠깐, 일본어 두 단어", secondaryButton: open, secondaryButtonBehavior: .custom)
        } else {
            alert = .init(title: "잠깐, 일본어 두 단어",
                          stopButton: .init(text: "그만", textColor: .white, systemImageName: "stop.fill"),
                          secondaryButton: open, secondaryButtonBehavior: .custom)
        }
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert),
                                         metadata: MicroAlarmMetadata(), tintColor: Palette.accent)
        return .alarm(schedule: schedule, attributes: attributes, secondaryIntent: OpenMicroReviewIntent(alarmID: id.uuidString))
    }
    static func test() async throws {
        _ = try await AlarmManager.shared.schedule(id: testID, configuration: configuration(.fixed(Date().addingTimeInterval(5)), id: testID))
    }
    static func synchronize(settings: MicroReviewSettings) async throws {
        let manager = AlarmManager.shared
        // Never request permission during a background refresh.
        guard manager.authorizationState == .authorized else { return }
        let existing = try manager.alarms.filter { $0.id.uuidString.lowercased().hasPrefix(prefix) }
        var wanted: [UUID: Alarm.Schedule] = [:]
        if settings.enabled && settings.usesSystemAlarm == true {
            let weekdays: [Locale.Weekday] = settings.includesWeekends
                ? [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
                : [.monday, .tuesday, .wednesday, .thursday, .friday]
            for minute in stride(from: settings.startHour * 60, to: settings.endHour * 60, by: max(30, settings.intervalMinutes)) {
                let id = UUID(uuidString: prefix + String(format: "%012d", minute))!
                wanted[id] = .relative(.init(time: .init(hour: minute / 60, minute: minute % 60), repeats: .weekly(weekdays)))
            }
        }
        for (id, schedule) in wanted {
            try Task.checkCancellation()
            if existing.contains(where: { $0.id == id && $0.schedule == schedule }) { continue }
            _ = try await manager.schedule(id: id, configuration: configuration(schedule, id: id))
        }
        for alarm in existing where wanted[alarm.id] == nil {
            try Task.checkCancellation()
            try manager.cancel(id: alarm.id)
        }
    }
}
