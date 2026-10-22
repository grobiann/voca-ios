import SwiftUI
import VocaCore
import UserNotifications
struct AccountView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 18) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 56)).foregroundStyle(Palette.accent)
                        VStack(alignment: .leading, spacing: 6) { Text("나만의 단어 생활").font(.title3.bold()); Text("이 기기에서 학습 중").font(.subheadline).foregroundStyle(.secondary) }
                    }.padding(.vertical, 16)
                }
                Section("학습 설정") {
                    Stepper("학습 풀 크기: \(store.poolSize)개", value: $store.poolSize, in: 1...100)
                    Text("기본 20개 · 1~100개 중 선택할 수 있어요. 모르는 카드는 풀 안에서 반복하고, 같은 단어의 반대 방향은 간격을 두고 보여 줍니다.").font(.caption).foregroundStyle(.secondary)
                    LabeledContent("학습 언어", value: "일본어")
                    LabeledContent("모국어", value: "한국어")
                    Toggle("카드 햅틱 피드백", isOn: $store.haptics).onChange(of: store.haptics) { _, value in UserDefaults.standard.set(value, forKey: "haptics") }
                    LabeledContent("완료 기준", value: "양방향 정답")
                }
                Section("1-3-3 알림") {
                    NavigationLink {
                        MicroReviewSettingsView()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1-3-3 알림")
                            Text("풀 \(store.activeMicroCount)개 · 완료 \(store.completedMicroCount)개")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.accessibilityIdentifier("microReviewSettings")
                }
                Section {
                    LabeledContent("로그인", value: "연결 없이 사용 중")
                    LabeledContent("구독", value: "개인용 · 무료")
                } header: { Text("계정") } footer: { Text("로그인과 구독은 아직 제공하지 않습니다. 카드와 학습 기록은 이 기기에 저장됩니다.") }
                Section("앱 정보") {
                    NavigationLink("단어 오류 제보함") { WordReportList() }
                    LabeledContent("voca-ios", value: "1.0")
                    Text("매일 한 장, 조금 더 가까운 일본어.").foregroundStyle(.secondary)
                }
            }.navigationTitle("계정")
        }
    }
}

struct MicroReviewSettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var showQuickReview = false
    @State private var testScheduled = false
    @State private var alarmTestScheduled = false
    @State private var soundAllowed = false
    @State private var timeSensitiveAllowed = false
    private var settings: MicroReviewSettings { store.microSettings }
    private var active: [MicroReviewEntry] { store.microEntries.filter { $0.status == .active } }
    private var completed: [MicroReviewEntry] { store.microEntries.filter { $0.status == .completed } }
    private var stopped: [MicroReviewEntry] { store.microEntries.filter { $0.status == .stopped } }
    private func binding<Value>(_ keyPath: WritableKeyPath<MicroReviewSettings, Value>) -> Binding<Value> {
        Binding(get: { store.microSettings[keyPath: keyPath] }, set: { value in
            var updated = store.microSettings
            updated[keyPath: keyPath] = value
            store.microSettings = updated
        })
    }
    var body: some View {
        List {
            Section {
                HStack {
                    Label("현재 풀", systemImage: "rectangle.stack")
                    Spacer()
                    Text("\(active.count)개").bold()
                }
                Button("지금 1-3-3 확인", systemImage: "play.fill") { showQuickReview = true }
            } footer: { Text("기존 학습 화면에서 원하는 단어만 1-3-3 풀에 담을 수 있어요.") }
            Section {
                Toggle("1-3-3 알림 켜기", isOn: Binding(
                    get: { settings.enabled },
                    set: { enabled in Task { await store.setMicroEnabled(enabled) } }
                ))
                Picker("알림 간격", selection: binding(\.intervalMinutes)) {
                    ForEach([30, 60, 90, 120, 180], id: \.self) { minutes in Text("\(minutes)분").tag(minutes) }
                }
                Picker("시작 시간", selection: binding(\.startHour)) {
                    ForEach(0..<settings.endHour, id: \.self) { hour in Text(String(format: "%02d:00", hour)).tag(hour) }
                }
                Picker("종료 시간", selection: binding(\.endHour)) {
                    ForEach((settings.startHour + 1)..<25, id: \.self) { hour in Text(String(format: "%02d:00", hour)).tag(hour) }
                }
                Toggle("주말에도 알림", isOn: binding(\.includesWeekends))
            } header: { Text("알림 설정") } footer: { Text("기본은 매일 10:00~20:00, 60분 간격입니다. 하루 횟수 제한은 없습니다. 알림을 탭하면 짧은 확인 화면이 열립니다.") }
            Section("1-3-3 풀 · \(active.count)개") {
                if active.isEmpty { Text("아직 담은 단어가 없어요.").foregroundStyle(.secondary) }
                ForEach(active) { entry in
                    microRow(entry) {
                        Button("더 이상 알리지 않기", systemImage: "bell.slash", role: .destructive) { store.stopMicro(entry.id) }
                    }
                }
            }
            Section("학습완료단어목록 · \(completed.count)개") {
                if completed.isEmpty { Text("세 번 확인하면 이곳에 모여요.").foregroundStyle(.secondary) }
                ForEach(completed) { entry in
                    microRow(entry) {
                        Button("다시 1-3-3에 담기", systemImage: "arrow.counterclockwise") { store.restartMicro(entry.id) }
                    }
                }
            }
            if !stopped.isEmpty {
                Section("그만 보기 · \(stopped.count)개") {
                    ForEach(stopped) { entry in
                        microRow(entry) {
                            Button("다시 알리기", systemImage: "bell") { store.restartMicro(entry.id) }
                            Button("목록에서 삭제", systemImage: "trash", role: .destructive) { store.removeMicro(entry.id) }
                        }
                    }
                }
            }
            Section {
                if #available(iOS 26.0, *) {
                    Toggle("시스템 알람 사용", isOn: Binding(
                        get: { settings.usesSystemAlarm == true },
                        set: { enabled in Task { await store.setSystemAlarm(enabled) } }
                    ))
                    Text("알림을 켜면 위의 활동시간·간격대로 시스템 알람이 울립니다. 알람에서 ‘1-3-3 시작’을 누르면 바로 학습합니다. 일반 알림과 중복으로 울리지 않습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("10~20시 · 30분 간격 적용") {
                        var updated = store.microSettings
                        updated.startHour = 10; updated.endHour = 20; updated.intervalMinutes = 30
                        store.microSettings = updated
                    }
                    Text("종료 시각 전까지 울립니다. 10~20시 · 30분이면 10:00부터 19:30까지 하루 20회입니다.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("5초 후 시스템 알람 테스트") {
                        Task { alarmTestScheduled = await store.sendMicroTestAlarm() }
                    }
                    if alarmTestScheduled { Text("5초 뒤 알람의 ‘1-3-3 시작’을 눌러 보세요.").font(.caption) }
                }
                Text("단축어 앱에서도 voca-ios의 ‘1-3-3 학습 시작’ 동작을 사용할 수 있어요.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text("바로 학습하기") }
            Section {
                Button("5초 후 테스트 알림", systemImage: "bell.badge.fill") {
                    Task {
                        testScheduled = await store.sendMicroTestNotification()
                        await refreshNotificationSettings()
                    }
                }
                if testScheduled { Text("5초 뒤 알림이 옵니다. 알림을 탭해 짧은 확인 화면도 테스트해 보세요.").font(.caption).foregroundStyle(Palette.accent) }
                LabeledContent("소리", value: soundAllowed ? "허용" : "꺼짐")
                LabeledContent("시간 민감 알림", value: timeSensitiveAllowed ? "허용" : "꺼짐")
                Button("iPhone 알림 설정 열기", systemImage: "gearshape") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            } header: { Text("알림 테스트") } footer: { Text("알림 소리와 시간 민감 알림은 iPhone 설정에서도 허용해야 합니다. 집중 모드 등 기기 설정에 따라 표시 방식이 달라질 수 있어요.") }
        }
        .navigationTitle("1-3-3 알림")
        .fullScreenCover(isPresented: $showQuickReview) { MicroReviewSessionView() }
        .task { await refreshNotificationSettings() }
    }
    private func refreshNotificationSettings() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        soundAllowed = settings.soundSetting == .enabled
        timeSensitiveAllowed = settings.timeSensitiveSetting == .enabled
    }
    private func microRow<Actions: View>(_ entry: MicroReviewEntry, @ViewBuilder actions: () -> Actions) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.word.japanese).font(.headline).textSelection(.enabled)
                Text("\(entry.word.korean) · \(entry.successCount)/3 완료")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu { actions() } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                .accessibilityLabel("\(entry.word.japanese) 관리")
        }
    }
}

struct MicroReviewSessionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentID: UUID?
    @State private var seenIDs = Set<UUID>()
    @State private var revealed = false
    @State private var handled = 0
    @State private var sessionTotal = 0
    @State private var continuing = false
    @State private var started = false
    @State private var offset: CGSize = .zero
    @State private var draggingHorizontally = false
    @State private var exiting = false
    @State private var advanceTask: Task<Void, Never>?
    @State private var closeTask: Task<Void, Never>?
    @State private var completionDeadline: Date?
    private var current: MicroReviewEntry? { store.microEntries.first { $0.id == currentID && $0.status == .active } }
    private var hasMoreWords: Bool { store.microEntries.contains { $0.status == .active && !seenIDs.contains($0.id) } }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44).background(.background, in: Circle())
                    }.accessibilityLabel("닫기")
                    Spacer()
                    Text("1-3-3 알림").font(.subheadline.bold())
                    Spacer()
                    Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
                }
                ProgressView(value: Double(handled), total: Double(max(sessionTotal, 1))).tint(Palette.accent)
                HStack {
                    Text("이번 카드 \(current == nil ? handled : handled + 1) / \(sessionTotal)")
                        .accessibilityIdentifier("microSessionProgress")
                    Spacer()
                    Text("전체 풀 \(store.activeMicroCount)개")
                }.font(.caption).foregroundStyle(.secondary)
                if let current {
                    ZStack {
                        ForEach(0..<2) { index in
                            RoundedRectangle(cornerRadius: 30).fill(Color(uiColor: .secondarySystemGroupedBackground))
                                .overlay(RoundedRectangle(cornerRadius: 30).stroke(.primary.opacity(0.05)))
                                .rotationEffect(.degrees(index == 0 ? -3 : 3)).padding(.horizontal, 8).offset(y: 8)
                                .accessibilityHidden(true)
                        }
                        card(current)
                            .overlay(alignment: .top) {
                                HStack {
                                    stamp("알았어요", color: Palette.accent, angle: -12)
                                        .opacity(revealed ? Double(min(max(offset.width, 0) / 90, 1)) : 0)
                                    Spacer()
                                    stamp("다시 볼게요", color: Palette.orange, angle: 12)
                                        .opacity(revealed ? Double(min(max(-offset.width, 0) / 90, 1)) : 0)
                                }.padding(.horizontal, 24).padding(.top, 92).allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                            .offset(offset).rotationEffect(.degrees(reduceMotion ? 0 : Double(offset.width / 22)))
                            .simultaneousGesture(revealed ? swipeGesture(width: geometry.size.width) : nil)
                    }.padding(.vertical, 8)
                    HStack(spacing: 14) {
                        responseButton("다시 볼게요", known: false, width: geometry.size.width)
                        responseButton("알았어요", known: true, width: geometry.size.width)
                    }.disabled(!revealed || exiting).opacity(revealed ? 1 : 0.35)
                    Button("이 단어 그만 보기", role: .destructive) { stopCurrent() }
                        .font(.subheadline).buttonStyle(.bordered).disabled(exiting)
                    Text(revealed ? "모르면 왼쪽, 알면 오른쪽으로 밀어 주세요" : "카드를 누르면 뜻을 확인할 수 있어요")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    if handled > 0 {
                        Button { finishReview() } label: {
                            VStack(spacing: 18) {
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 48)).foregroundStyle(Palette.accent)
                                Text("이번 확인을 마쳤어요").font(.subheadline).foregroundStyle(.secondary)
                                Text("터치하여 학습 화면으로").font(.title2.bold()).foregroundStyle(.primary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("microFinishReview")
                        if hasMoreWords {
                            Button("조금 더 학습하기") {
                                closeTask?.cancel()
                                completionDeadline = nil
                                continuing = true
                                sessionTotal = handled + store.microEntries.filter { $0.status == .active && !seenIDs.contains($0.id) }.count
                                advance()
                            }
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                        }
                        HStack {
                            Spacer()
                            if let completionDeadline {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    Text("\(max(0, Int(ceil(completionDeadline.timeIntervalSince(context.date)))))초 후 마침")
                                        .font(.caption2).monospacedDigit().foregroundStyle(.tertiary)
                                }
                            }
                        }
                    } else {
                        Spacer()
                        Image(systemName: "tray").font(.system(size: 56)).foregroundStyle(Palette.accent)
                        Text("1-3-3 풀이 비었어요").font(.title2.bold())
                        Text("학습 중인 카드에서 ‘1-3-3에 담기’를 누르면 다음 알림부터 만날 수 있어요.")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary)
                        Button("학습 화면으로 돌아가기") { dismiss() }.buttonStyle(PrimaryButton())
                        Spacer()
                    }
                }
            }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity).background(Palette.canvas)
        }.onAppear {
            guard !started else { return }
            started = true
            sessionTotal = min(2, store.activeMicroCount)
            advance()
        }.onDisappear { closeTask?.cancel(); advanceTask?.cancel() }
    }
    private func card(_ entry: MicroReviewEntry) -> some View {
        VStack(spacing: 22) {
            HStack {
                Text(revealed ? "ANSWER" : "THINK IN JAPANESE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
                Spacer()
            }.frame(height: 44)
            ViewThatFits(in: .vertical) {
                face(entry.word, scale: 1)
                face(entry.word, scale: 0.8)
                face(entry.word, scale: 0.6)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            HStack {
                Spacer()
                Text("이 단어 학습 완료 \(entry.successCount)/3회")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(.primary.opacity(0.06)))
            .shadow(color: .black.opacity(0.06), radius: 20, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: 30))
            .accessibilityIdentifier("microReviewCard")
            .onTapGesture { reveal() }
            .accessibilityAction(named: "정답 보기") { reveal() }
    }
    private func face(_ word: Word, scale: CGFloat) -> some View {
        VStack(spacing: 20 * scale) {
            Text(word.japanese)
                .font(.system(size: (revealed ? 24 : 38) * scale, weight: revealed ? .medium : .semibold, design: .rounded))
                .foregroundStyle(revealed ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
            if revealed {
                if let reading = word.reading, !reading.isEmpty {
                    Text(reading).font(.system(size: 17 * scale)).foregroundStyle(.secondary)
                        .accessibilityIdentifier("microReading")
                }
                Rectangle().fill(Palette.accent.opacity(0.15)).frame(width: 36, height: 3)
                Text(word.korean).font(.system(size: 34 * scale, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 8)
    }
    private func reveal() {
        guard !revealed && !exiting else { return }
        revealed = true
    }
    private func swipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard revealed && !exiting else { return }
                if !draggingHorizontally {
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    draggingHorizontally = true
                }
                offset = CGSize(width: value.translation.width, height: value.translation.height * 0.15)
            }
            .onEnded { value in
                guard revealed && !exiting else { return }
                defer { draggingHorizontally = false }
                let translation = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let flick = abs(translation) > 35 && abs(predicted) > 220 && translation.sign == predicted.sign
                if draggingHorizontally && (abs(translation) > min(110, width * 0.27) || flick) {
                    answer(translation > 0, width: width)
                } else { withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { offset = .zero } }
            }
    }
    private func stamp(_ title: String, color: Color, angle: Double) -> some View {
        Text(title).font(.title2.bold()).foregroundStyle(color).padding(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 3)).rotationEffect(.degrees(angle))
    }
    private func responseButton(_ title: String, known: Bool, width: CGFloat) -> some View {
        Button { answer(known, width: width) } label: {
            Label(title, systemImage: known ? "arrow.right" : "arrow.left")
                .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 18)
                .foregroundStyle(known ? Palette.accent : Palette.orange)
                .background((known ? Palette.accent : Palette.orange).opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
        }
    }
    private func answer(_ known: Bool, width: CGFloat) {
        guard revealed && !exiting, let currentID else { return }
        exiting = true
        store.feedback(.medium)
        withAnimation(reduceMotion ? .linear(duration: 0.1) : .easeIn(duration: 0.23)) {
            offset = CGSize(width: (known ? 1 : -1) * (width + 180), height: 40)
        }
        advanceTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 240)) } catch { return }
            store.answerMicro(currentID, known: known)
            finishCard(currentID)
        }
    }
    private func stopCurrent() {
        guard !exiting, let currentID else { return }
        store.stopMicro(currentID)
        seenIDs.insert(currentID)
        revealed = false
        offset = .zero
        draggingHorizontally = false
        let remaining = store.microEntries.filter { $0.status == .active && !seenIDs.contains($0.id) }.count
        sessionTotal = min(sessionTotal, handled + remaining)
        advance()
    }
    private func finishCard(_ id: UUID) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            seenIDs.insert(id)
            handled += 1
            revealed = false
            offset = .zero
            exiting = false
            draggingHorizontally = false
            advance()
        }
    }
    private func finishReview() {
        closeTask?.cancel()
        completionDeadline = nil
        dismiss()
        NotificationCenter.default.post(name: .finishMicroReview, object: nil)
    }
    private func advance() {
        currentID = handled >= sessionTotal && !continuing ? nil : store.nextMicroEntry(excluding: seenIDs)?.id
        if currentID == nil && handled > 0 {
            closeTask?.cancel()
            completionDeadline = Date().addingTimeInterval(30)
            closeTask = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                if !Task.isCancelled { finishReview() }
            }
        }
    }
}

struct WordReportList: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            Section {
                ForEach((store.archive.wordReports ?? []).reversed()) { report in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(report.word.japanese).font(.headline).textSelection(.enabled)
                        Text("\(report.libraryTitle ?? "내 스택") · \(report.stackTitle)").font(.caption).foregroundStyle(.secondary)
                        if let corrected = report.correctedKorean {
                            Text("\(report.word.korean) → \(corrected)")
                        } else {
                            Text(report.message)
                        }
                        Text(report.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        ShareLink(item: report.shareText) { Label("제보 공유", systemImage: "square.and.arrow.up") }
                    }.padding(.vertical, 6)
                }
                if (store.archive.wordReports ?? []).isEmpty { Text("저장된 제보가 없어요.").foregroundStyle(.secondary) }
            } footer: { Text("제보는 이 기기에 저장됩니다. 공유 버튼으로 내용을 전달할 수 있습니다.") }
        }.navigationTitle("단어 오류 제보함")
    }
}

struct WordReportComposer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let library: Library?
    let stacks: [Stack]
    let initialWordID: UUID?
    @State private var selectedStackID: UUID?
    @State private var selectedWordID: UUID?
    @State private var correctedKorean = ""
    @State private var query = ""
    init(library: Library?, stacks: [Stack], initialWordID: UUID? = nil) {
        self.library = library
        self.stacks = stacks
        self.initialWordID = initialWordID
        _selectedStackID = State(initialValue: stacks.first?.id)
        _selectedWordID = State(initialValue: initialWordID)
    }
    private var stack: Stack? { stacks.first { $0.id == selectedStackID } ?? stacks.first }
    private var word: Word? { stack?.words.first { $0.id == selectedWordID } }
    private var isInMyCards: Bool {
        guard let stack, let word else { return false }
        return store.archive.stacks.contains { mine in
            (mine.id == stack.id || mine.sourceID == stack.id) && mine.words.contains { $0.id == word.id }
        }
    }
    var body: some View {
        Form {
            Section("제보 위치") {
                Text(library?.title ?? "내 스택")
                Picker("스택", selection: $selectedStackID) {
                    ForEach(stacks) { Text($0.title).tag(Optional($0.id)) }
                }.onChange(of: selectedStackID) { _, _ in selectedWordID = nil; query = "" }
            }
            if initialWordID == nil {
                Section("틀린 단어 선택") {
                    TextField("일본어 · 한국어 검색", text: $query)
                    ForEach((stack?.words ?? []).filter { query.isEmpty || $0.japanese.localizedCaseInsensitiveContains(query) || $0.korean.localizedCaseInsensitiveContains(query) }) { candidate in
                        Button { selectedWordID = candidate.id } label: {
                            HStack {
                                VStack(alignment: .leading) { Text(candidate.japanese); Text(candidate.korean).font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                if selectedWordID == candidate.id { Image(systemName: "checkmark.circle.fill") }
                            }
                        }.foregroundStyle(.primary)
                    }
                }
            }
            if let word {
                Section("선택한 카드") { Text(word.japanese); Text(word.korean); Text(word.example) }
            }
            Section {
                TextField("올바른 한국어 뜻을 적어 주세요", text: $correctedKorean, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("reportMessage")
                Button(isInMyCards ? "제보 저장 및 내 카드 수정" : "제보 저장") {
                    guard let stack, let word else { return }
                    store.recordMeaningCorrection(library: library, stack: stack, word: word, correctedKorean: correctedKorean)
                    if store.error == nil { dismiss() }
                }.disabled(word == nil || correctedKorean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: { Text("올바른 뜻") } footer: { Text("제보는 기기에 저장됩니다. 내 카드에 있는 단어는 뜻이 즉시 수정되며, 라이브러리 원본은 유지됩니다.") }
        }
        .navigationTitle("틀린 단어 제보")
        .toolbar {
            if initialWordID != nil {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
        }
    }
}
