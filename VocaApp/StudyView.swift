import SwiftUI
import VocaCore

struct StudyView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stackID: UUID
    private let initialReviewDepth: Int?
    @State private var activeReviewDepth: Int?
    @State private var activeStackID: UUID
    @State private var stack = Stack(title: "")
    @State private var stageTotal = 0
    @State private var stageCompleted = 0
    @State private var revealed = false
    @State private var offset: CGSize = .zero
    @State private var draggingHorizontally = false
    @State private var exiting = false
    @State private var undo: Stack?
    @State private var undoPromotion: (depth: Int, previousTarget: Stack)?
    @State private var undoAdvance: ReviewDepthAdvanceSnapshot?
    @State private var advanceTask: Task<Void, Never>?
    @State private var reporting = false
    @State private var deletingWord: Word?
    private var item: ReviewItem? { stack.queue.first }
    private var word: Word? { stack.words.first { $0.id == item?.wordID } }
    init(stackID: UUID, reviewDepth: Int? = nil) {
        self.stackID = stackID
        self.initialReviewDepth = reviewDepth
        _activeReviewDepth = State(initialValue: reviewDepth)
        _activeStackID = State(initialValue: stackID)
    }
    private func persist(_ updated: Stack) {
        if let activeReviewDepth { store.updateReviewDepthStack(updated, at: activeReviewDepth) }
        else { store.update(updated) }
    }
    private var sourceLibrary: Library? {
        (store.archive.libraries + store.archive.server).first { library in
            library.stacks.contains { $0.id == (stack.sourceID ?? stack.id) }
        }
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44).background(.background, in: Circle()) }.accessibilityLabel("학습 닫기")
                    Spacer()
                    VStack(spacing: 4) {
                        Text(activeReviewDepth.map { "\($0)단계" } ?? stack.title).font(.subheadline.bold()).lineLimit(1)
                        Text(activeReviewDepth.map { _ in "이번 단계 \(stageCompleted)/\(stageTotal)개 완료" } ?? "\(stack.mastered.count) / \(stack.words.count * 2) 완료")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        if let undo {
                            if let undoAdvance {
                                store.undoReviewDepthAdvance(undoAdvance, restore: undo)
                                activeReviewDepth = undoAdvance.sourceDepth
                                activeStackID = undo.id
                            } else if let undoPromotion {
                                store.restoreReviewDepths(source: nil,
                                                          sourceDepth: nil,
                                                          destination: undoPromotion.previousTarget,
                                                          destinationDepth: undoPromotion.depth)
                                persist(undo)
                            } else {
                                persist(undo)
                            }
                            stack = undo
                            self.undo = nil; undoPromotion = nil; undoAdvance = nil; revealed = false; offset = .zero
                        }
                    } label: { Image(systemName: "arrow.uturn.backward").frame(width: 44, height: 44) }.disabled(undo == nil || exiting).accessibilityLabel("이전 응답 취소")
                }
                    ProgressView(value: activeReviewDepth.map { _ in stageTotal == 0 ? 0 : Double(stageCompleted) / Double(stageTotal) } ?? stack.progress).tint(Palette.accent)
                if let word, let item {
                    HStack {
                        Text(item.direction.label).font(.caption.weight(.semibold))
                        Spacer(); Text("학습 풀 \(stack.queue.count)/\(store.poolSize) · 남은 \(stack.remainingCount)").font(.caption)
                    }.foregroundStyle(.secondary)
                    ZStack {
                        ForEach(0..<2) { index in
                            RoundedRectangle(cornerRadius: 30).fill(Color(uiColor: .secondarySystemGroupedBackground))
                                .overlay(RoundedRectangle(cornerRadius: 30).stroke(.primary.opacity(0.05)))
                                .rotationEffect(.degrees(index == 0 ? -3 : 3)).padding(.horizontal, 8).offset(y: 8)
                        }
                        if stack.queue.count > 1,
                           let nextWord = stack.words.first(where: { $0.id == stack.queue[1].wordID }) {
                            VStack(spacing: 24) {
                                Text(stack.queue[1].direction == .japaneseToKorean ? nextWord.japanese : nextWord.korean)
                                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                            }.multilineTextAlignment(.center).padding(28)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 30))
                                .scaleEffect(0.96 + min(abs(offset.width) / 400, 1) * 0.04)
                                .accessibilityHidden(true)
                        }
                        card(word, item: item)
                            .overlay(alignment: .top) {
                                HStack {
                                    swipeStamp("알았어요", color: Palette.accent, angle: -12)
                                        .opacity(revealed ? Double(min(max(offset.width, 0) / 90, 1)) : 0)
                                    Spacer()
                                    swipeStamp("다시 볼게요", color: Palette.orange, angle: 12)
                                        .opacity(revealed ? Double(min(max(-offset.width, 0) / 90, 1)) : 0)
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 92)
                                .allowsHitTesting(false)
                            }
                            .offset(offset).rotationEffect(.degrees(reduceMotion ? 0 : Double(offset.width / 22)))
                            .simultaneousGesture(revealed ? swipeGesture(width: geometry.size.width) : nil)
                    }.padding(.vertical, 8)
                    HStack(spacing: 14) {
                        responseButton("다시 볼게요", icon: "arrow.left", known: false, width: geometry.size.width)
                        responseButton("알았어요", icon: "arrow.right", known: true, width: geometry.size.width)
                    }.disabled(!revealed || exiting).opacity(revealed ? 1 : 0.35)
                    Menu {
                        if activeReviewDepth == nil {
                            Button("단계별 확인에 담기", systemImage: "square.stack.3d.up") {
                                answer(true, width: geometry.size.width, promoteTo: 1)
                            }
                        }
                        Button("오류 제보", systemImage: "flag") { reporting = true }
                        Button("세트에서 제거", systemImage: "trash", role: .destructive) { deletingWord = word }
                    } label: {
                        Label("관리", systemImage: "ellipsis.circle")
                            .font(.caption.weight(.medium)).padding(.horizontal, 14).padding(.vertical, 6)
                    }
                    .disabled(exiting)
                    Text(revealed ? "모르면 왼쪽, 알면 오른쪽으로 밀어 주세요" : "카드를 누르면 뜻을 확인할 수 있어요")
                        .font(.caption).foregroundStyle(.secondary)
                } else if stack.words.isEmpty && activeReviewDepth != nil {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 76)).foregroundStyle(Palette.accent)
                    Text("단계별 학습을 마쳤어요").font(.title.bold())
                    Text("완료한 단어는 별도 목록에 보관됩니다.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Spacer()
                    Button("학습 마치기") { dismiss() }.buttonStyle(PrimaryButton())
                } else if stack.words.isEmpty {
                    Spacer()
                    Image(systemName: "rectangle.stack.badge.minus").font(.system(size: 64)).foregroundStyle(Palette.accent)
                    Text("스택에 카드가 없어요").font(.title.bold())
                    Text("새 카드를 추가하거나 다른 스택을 선택해 주세요.").foregroundStyle(.secondary)
                    Spacer()
                    Button("학습 마치기") { dismiss() }.buttonStyle(PrimaryButton())
                } else {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 76)).foregroundStyle(Palette.accent)
                    Text("스택을 모두 익혔어요!").font(.title.bold())
                    Text("\(stack.words.count)개의 표현을 양방향으로 학습했어요.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Spacer()
                    Button("학습 마치기") { dismiss() }.buttonStyle(PrimaryButton())
                }
            }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity).background(Palette.canvas)
        }.onAppear {
            activeReviewDepth = initialReviewDepth
            activeStackID = stackID
            if let saved = initialReviewDepth.flatMap({ store.reviewDepthStack(at: $0) }) ?? store.archive.stacks.first(where: { $0.id == stackID }) {
                stack = saved; stack.prepare(poolSize: store.poolSize); persist(stack)
                if initialReviewDepth != nil { stageTotal = saved.words.count }
            }
        }.onDisappear { advanceTask?.cancel() }
        .sheet(isPresented: $reporting, onDismiss: {
            if let updated = activeReviewDepth.flatMap({ store.reviewDepthStack(at: $0) }) ?? store.archive.stacks.first(where: { $0.id == activeStackID }) { stack = updated }
        }) {
            NavigationStack {
                WordReportComposer(library: sourceLibrary, stacks: [stack], initialWordID: word?.id)
            }
        }
        .confirmationDialog("이 카드를 내 스택에서 제거할까요?", isPresented: Binding(
            get: { deletingWord != nil }, set: { if !$0 { deletingWord = nil } }
        ), titleVisibility: .visible) {
            if let deletingWord {
                Button("세트에서 제거", role: .destructive) { removeCurrentWord(deletingWord.id) }
            }
        } message: { Text("양방향 학습 대기열에서도 제거됩니다. 라이브러리의 원본은 유지됩니다.") }
    }
    private func card(_ word: Word, item: ReviewItem) -> some View {
        let japaneseFirst = item.direction == .japaneseToKorean
        return ZStack {
            if revealed {
                cardSurface(word, japaneseFirst: japaneseFirst, showingAnswer: true)
            } else {
                cardSurface(word, japaneseFirst: japaneseFirst, showingAnswer: false)
            }
        }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(.primary.opacity(0.06)))
            .shadow(color: .black.opacity(0.06), radius: 20, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: 30))
            .accessibilityIdentifier("studyCard")
            .onTapGesture { reveal() }
            .accessibilityAction(named: "정답 보기") { reveal() }
    }
    private func cardSurface(_ word: Word, japaneseFirst: Bool, showingAnswer: Bool) -> some View {
        VStack(spacing: 22) {
            HStack {
                Text(showingAnswer ? "ANSWER" : "THINK IN \(japaneseFirst ? "JAPANESE" : "KOREAN")")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
                Spacer()
                if japaneseFirst || showingAnswer {
                    CopyJapaneseButton(text: word.japanese).id(word.id)
                    SearchJapaneseButton(text: word.japanese)
                    Button { store.speak(word.japanese) } label: { Image(systemName: "speaker.wave.2").font(.title3).frame(width: 44, height: 44) }.accessibilityLabel("일본어 발음 듣기")
                }
            }
            ViewThatFits(in: .vertical) {
                cardFace(word, japaneseFirst: japaneseFirst, showingAnswer: showingAnswer, scale: 1)
                cardFace(word, japaneseFirst: japaneseFirst, showingAnswer: showingAnswer, scale: 0.82)
                cardFace(word, japaneseFirst: japaneseFirst, showingAnswer: showingAnswer, scale: 0.66)
                cardFace(word, japaneseFirst: japaneseFirst, showingAnswer: showingAnswer, scale: 0.58, compact: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            Label(showingAnswer ? "기억을 확인해 보세요" : "탭해서 뒤집기", systemImage: showingAnswer ? "sparkle" : "hand.tap")
                .font(.caption).foregroundStyle(.tertiary)
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func cardFace(_ word: Word, japaneseFirst: Bool, showingAnswer: Bool, scale: CGFloat, compact: Bool = false) -> some View {
        VStack(spacing: compact ? 10 : 20 * scale) {
            Text(japaneseFirst ? word.japanese : word.korean)
                .font(.system(size: (showingAnswer ? 24 : 38) * scale, weight: showingAnswer ? .medium : .semibold, design: .rounded))
                .foregroundStyle(showingAnswer ? .secondary : .primary)
                .lineLimit(compact ? 4 : nil)
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: false, vertical: true)
            if (showingAnswer || (japaneseFirst && store.showReadingOnFront)), let reading = word.reading, !reading.isEmpty {
                Text(reading).font(.system(size: 17 * scale)).foregroundStyle(.secondary)
                    .lineLimit(compact ? 2 : nil).fixedSize(horizontal: false, vertical: true)
            }
            if showingAnswer {
                Rectangle().fill(Palette.accent.opacity(0.15)).frame(width: 36, height: 3)
                Text(japaneseFirst ? word.korean : word.japanese)
                    .font(.system(size: 34 * scale, weight: .semibold, design: .rounded))
                    .lineLimit(compact ? 4 : nil).minimumScaleFactor(0.65)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.vertical, 8)
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
                let threshold = min(110.0, width * 0.27)
                let translation = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let flick = abs(translation) > 35 && abs(predicted) > 220 && translation.sign == predicted.sign
                if draggingHorizontally && (abs(translation) > threshold || flick) {
                    answer(translation > 0, width: width)
                } else { withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { offset = .zero } }
            }
    }
    private func swipeStamp(_ title: String, color: Color, angle: Double) -> some View {
        Text(title).font(.title2.bold()).foregroundStyle(color)
            .padding(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 3))
            .rotationEffect(.degrees(angle))
    }
    private func responseButton(_ title: String, icon: String, known: Bool, width: CGFloat) -> some View {
        Button { answer(known, width: width) } label: {
            Label(title, systemImage: icon).font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 18)
                .foregroundStyle(known ? Palette.accent : Palette.orange)
                .background((known ? Palette.accent : Palette.orange).opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
        }
    }
    private func answer(_ known: Bool, width: CGFloat, promoteTo promotionDepth: Int? = nil) {
        guard revealed && !exiting else { return }
        let answeredWord = word
        exiting = true; store.feedback(.medium)
        withAnimation(reduceMotion ? .linear(duration: 0.1) : .easeIn(duration: 0.23)) {
            offset = CGSize(width: (known ? 1 : -1) * (width + 180), height: 40)
        }
        advanceTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 240)) } catch { return }
            undo = stack
            undoPromotion = nil
            undoAdvance = nil
            if let activeReviewDepth, known, let answeredWord {
                var updated = stack
                updated.answer(known: true, poolSize: store.poolSize)
                let directions = Direction.allCases.map { ReviewItem(wordID: answeredWord.id, direction: $0) }
                if directions.allSatisfy({ updated.mastered.contains($0) }),
                   let snapshot = store.advanceReviewDepthWord(answeredWord, updatedSource: updated, from: activeReviewDepth) {
                    undoAdvance = snapshot
                    stageCompleted += 1
                    stack = store.reviewDepthStack(at: activeReviewDepth) ?? updated
                    if activeReviewDepth < store.reviewDepthCount,
                       let next = store.reviewDepthStack(at: activeReviewDepth + 1),
                       next.words.contains(where: { $0.id == answeredWord.id }) {
                        self.activeReviewDepth = activeReviewDepth + 1
                        activeStackID = next.id
                        stack = next
                        stageTotal = next.words.count
                        stageCompleted = 0
                    } else if stack.words.isEmpty {
                        advanceToNextStageIfAvailable()
                    }
                } else {
                    stack = updated
                    persist(updated)
                }
            } else {
                if known, let depth = promotionDepth, let answeredWord, let previousTarget = store.reviewDepthStack(at: depth),
                   store.addToReviewDepth(answeredWord, at: depth) {
                    undoPromotion = (depth, previousTarget)
                }
                stack.answer(known: known, poolSize: store.poolSize)
                persist(stack)
            }
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { revealed = false; offset = .zero; exiting = false }
        }
    }
    private func advanceToNextStageIfAvailable() {
        guard let activeReviewDepth else { return }
        guard activeReviewDepth < store.reviewDepthCount else { return }
        for depth in (activeReviewDepth + 1)...store.reviewDepthCount {
            guard let next = store.reviewDepthStack(at: depth), !next.words.isEmpty else { continue }
            self.activeReviewDepth = depth
            activeStackID = next.id
            stack = next
            stageTotal = next.words.count
            stageCompleted = 0
            return
        }
    }
    private func removeCurrentWord(_ wordID: UUID) {
        guard !exiting, stack.words.contains(where: { $0.id == wordID }) else { deletingWord = nil; return }
        advanceTask?.cancel()
        if let activeReviewDepth { store.removeReviewDepthWord(wordID, at: activeReviewDepth) }
        else { store.removeWord(wordID, from: activeStackID) }
        if let updated = activeReviewDepth.flatMap({ store.reviewDepthStack(at: $0) }) ?? store.archive.stacks.first(where: { $0.id == activeStackID }) { stack = updated }
        undo = nil
        undoPromotion = nil
        revealed = false
        offset = .zero
        deletingWord = nil
    }
}
