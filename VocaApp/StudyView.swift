import SwiftUI
import VocaCore

struct StudyView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stackID: UUID
    @State private var stack = Stack(title: "")
    @State private var revealed = false
    @State private var offset: CGSize = .zero
    @State private var draggingHorizontally = false
    @State private var exiting = false
    @State private var undo: Stack?
    @State private var advanceTask: Task<Void, Never>?
    @State private var reporting = false
    private var item: ReviewItem? { stack.queue.first }
    private var word: Word? { stack.words.first { $0.id == item?.wordID } }
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
                        Text(stack.title).font(.subheadline.bold()).lineLimit(1)
                        Text("\(stack.mastered.count) / \(stack.words.count * 2) 완료").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        if let undo { stack = undo; store.update(stack); self.undo = nil; revealed = false; offset = .zero }
                    } label: { Image(systemName: "arrow.uturn.backward").frame(width: 44, height: 44) }.disabled(undo == nil || exiting).accessibilityLabel("이전 응답 취소")
                }
                ProgressView(value: stack.progress).tint(Palette.accent)
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
                                if stack.queue[1].direction == .japaneseToKorean {
                                    Text(nextWord.example).font(.body).foregroundStyle(.secondary)
                                }
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
                    HStack(spacing: 12) {
                        Button {
                            store.addMicroWord(word, sourceTitle: stack.title)
                        } label: {
                            Label(store.microEntry(for: word)?.status == .active ? "1-3-3 풀에 담김" : "1-3-3에 담기",
                                  systemImage: store.microEntry(for: word)?.status == .active ? "checkmark.circle.fill" : "bell.badge")
                        }
                        .disabled(store.microEntry(for: word)?.status == .active || exiting)
                        Button("오류 제보", systemImage: "flag") { reporting = true }
                            .disabled(exiting)
                    }
                    .buttonStyle(.bordered)
                    Text(revealed ? "모르면 왼쪽, 알면 오른쪽으로 밀어 주세요" : "카드를 누르면 뜻을 확인할 수 있어요")
                        .font(.caption).foregroundStyle(.secondary)
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
            if let saved = store.archive.stacks.first(where: { $0.id == stackID }) { stack = saved; stack.prepare(poolSize: store.poolSize); store.update(stack) }
        }.onDisappear { advanceTask?.cancel() }
        .sheet(isPresented: $reporting) {
            NavigationStack {
                WordReportComposer(library: sourceLibrary, stacks: [stack], initialWordID: word?.id)
            }
        }
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
            if (japaneseFirst || showingAnswer), let reading = word.reading, !reading.isEmpty {
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
            if (japaneseFirst || showingAnswer) && !word.example.isEmpty {
                Text(word.example).font(.system(size: 17 * scale)).foregroundStyle(.secondary)
                    .lineSpacing(compact ? 2 : 5)
                    .lineLimit(compact ? 5 : nil)
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
    private func answer(_ known: Bool, width: CGFloat) {
        guard revealed && !exiting else { return }
        exiting = true; store.feedback(.medium)
        withAnimation(reduceMotion ? .linear(duration: 0.1) : .easeIn(duration: 0.23)) {
            offset = CGSize(width: (known ? 1 : -1) * (width + 180), height: 40)
        }
        advanceTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 240)) } catch { return }
            undo = stack; stack.answer(known: known, poolSize: store.poolSize); store.update(stack)
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { revealed = false; offset = .zero; exiting = false }
        }
    }
}
