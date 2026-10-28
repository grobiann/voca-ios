import SwiftUI
import VocaCore

struct CopyJapaneseButton: View {
    let text: String
    @State private var copied = false
    var body: some View {
        Button {
            UIPasteboard.general.string = text
            copied = true
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc").frame(width: 44, height: 44)
        }.buttonStyle(.borderless).accessibilityLabel(copied ? "일본어 복사 완료" : "일본어 복사")
            .onChange(of: text) { _, _ in copied = false }
    }
}

struct SearchJapaneseButton: View {
    @Environment(AppStore.self) private var store
    let text: String
    var body: some View {
        Button { store.searchJapanese(text) } label: {
            Image(systemName: "magnifyingglass").frame(width: 44, height: 44)
        }.buttonStyle(.borderless).accessibilityLabel("\(text) 구글 검색")
    }
}

struct LearnView: View {
    @Environment(AppStore.self) private var store
    @State private var studying: Stack?
    @State private var studyingDepth: Int?
    private var next: Stack? { store.archive.stacks.first { !$0.words.isEmpty && !$0.isComplete } }
    private var nextDepth: Int? {
        (1...store.reviewDepthCount).first { depth in
            guard let stack = store.reviewDepthStack(at: depth) else { return false }
            return !stack.words.isEmpty && !stack.isComplete
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("조금씩,\n내 말이 되는 시간.")
                                .font(.system(size: 27, weight: .bold, design: .rounded))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("오늘도 한 장부터 시작해 볼까요?")
                                .font(.caption).foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text("\(store.archive.stacks.reduce(0) { $0 + $1.words.count })")
                                    .font(.system(size: 30, weight: .light, design: .rounded))
                                Text("내가 모은 단어").font(.caption).foregroundStyle(.secondary)
                            }.padding(.top, 5)
                        }
                        Spacer(minLength: 0)
                        ZStack {
                            RoundedRectangle(cornerRadius: 17)
                                .fill(Palette.accent.opacity(0.12))
                                .frame(width: 76, height: 102)
                                .rotationEffect(.degrees(-12)).offset(x: -12, y: -3)
                            RoundedRectangle(cornerRadius: 17)
                                .fill(.background)
                                .overlay(RoundedRectangle(cornerRadius: 17).stroke(Palette.accent.opacity(0.18), lineWidth: 1))
                                .frame(width: 76, height: 102)
                                .rotationEffect(.degrees(-3)).offset(x: -5, y: 0)
                            RoundedRectangle(cornerRadius: 17)
                                .fill(Palette.accent)
                                .frame(width: 76, height: 102)
                                .rotationEffect(.degrees(7))
                            Text("あ")
                                .font(.system(size: 48, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                                .rotationEffect(.degrees(7))
                        }
                        .frame(width: 100, height: 116)
                        .accessibilityHidden(true)
                    }
                    .padding(20)
                    .background(.background, in: RoundedRectangle(cornerRadius: 24))
                    Button { studying = next } label: {
                        Label("학습 시작", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButton(height: 60))
                    .disabled(next == nil)
                    .opacity(next == nil ? 0.45 : 1)
                    Button { studyingDepth = nextDepth } label: {
                        Label("단계별 학습 시작", systemImage: "square.stack.3d.up.fill")
                    }
                    .buttonStyle(PrimaryButton(height: 60))
                    .disabled(nextDepth == nil)
                    .opacity(nextDepth == nil ? 0.45 : 1)
                    NavigationLink { MyStackListView() } label: {
                        compactEntry("내 스택", detail: "\(store.archive.stacks.count)개", icon: "rectangle.stack")
                    }.buttonStyle(.plain).accessibilityLabel("내 스택")
                    NavigationLink { ReviewDepthListView() } label: {
                        compactEntry("단계별 단어풀", detail: "\(store.reviewDepthStacks.reduce(0) { $0 + $1.words.count })개", icon: "square.stack.3d.up")
                    }.buttonStyle(.plain).accessibilityLabel("단계별 단어풀")
                }.padding(22)
            }
            .background(Palette.canvas)
            .navigationTitle("학습")
            .toolbarTitleDisplayMode(.inline)
            .fullScreenCover(item: $studying) { StudyView(stackID: $0.id) }
            .fullScreenCover(isPresented: Binding(
                get: { studyingDepth != nil },
                set: { if !$0 { studyingDepth = nil } }
            )) {
                if let depth = studyingDepth, let stack = store.reviewDepthStack(at: depth) {
                    StudyView(stackID: stack.id, reviewDepth: depth)
                }
            }
        }
    }
    private func compactEntry(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Palette.accent).frame(width: 28)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text(detail).font(.caption).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}
struct MyStackListView: View {
    @Environment(AppStore.self) private var store
    @State private var studying: Stack?
    @State private var creating = false
    @State private var restarting: Stack?
    @State private var showRestartConfirmation = false
    @State private var completedExpanded = false
    @State private var confirmingRemoveAll = false
    private var activeStacks: [Stack] { store.archive.stacks.filter { !$0.isComplete } }
    private var completedStacks: [Stack] { store.archive.stacks.filter(\.isComplete) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("내 스택").font(.title2.bold())
                    Text("\(store.archive.stacks.count)").foregroundStyle(.secondary)
                    Spacer()
                    if !store.archive.stacks.isEmpty {
                        Button(role: .destructive) { confirmingRemoveAll = true } label: {
                            Image(systemName: "trash").font(.body).frame(width: 44, height: 44)
                        }.accessibilityLabel("내 스택 전체 제거")
                    }
                    Button { creating = true } label: { Image(systemName: "plus").font(.title3) }
                        .accessibilityLabel("스택 만들기")
                }
                if store.archive.stacks.isEmpty {
                    EmptyState(icon: "rectangle.stack", title: "첫 스택을 만들어 보세요", message: "직접 카드를 추가하거나 라이브러리에서 가져올 수 있어요.")
                } else {
                    stackSection("진행 중", stacks: activeStacks)
                    VStack(alignment: .leading, spacing: 10) {
                        Button { withAnimation(.easeInOut(duration: 0.2)) { completedExpanded.toggle() } } label: {
                            HStack {
                                Text("완료").font(.headline)
                                Text("\(completedStacks.count)").foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: completedExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel("완료된 스택 \(completedStacks.count)개 \(completedExpanded ? "접기" : "펼치기")")
                        if completedExpanded { stackSectionRows(completedStacks, completed: true) }
                    }
                }
            }.padding(22)
        }
        .background(Palette.canvas)
        .navigationTitle("내 스택")
        .sheet(isPresented: $creating) { NameSheet(title: "새 스택", placeholder: "예: 여행에서 만나는 말") { name in
            store.archive.stacks.append(Stack(title: name)); store.save()
        } }
        .fullScreenCover(item: $studying) { StudyView(stackID: $0.id) }
        .confirmationDialog("현재 내 스택의 카드로 다시 학습할까요?", isPresented: $showRestartConfirmation, titleVisibility: .visible) {
            Button("다시 학습하기") {
                if let stack = restarting, store.restartStack(stack.id) {
                    studying = store.archive.stacks.first { $0.id == stack.id }
                }
                restarting = nil
            }
        } message: { Text("삭제한 카드는 제외하고 수정한 내용은 그대로 사용합니다.") }
        .confirmationDialog("내 스택을 모두 제거할까요?", isPresented: $confirmingRemoveAll, titleVisibility: .visible) {
            Button("모든 내 스택과 학습 기록 삭제", role: .destructive) { store.removeAllStacks() }
        } message: { Text("내 스택과 학습 기록이 삭제됩니다. 라이브러리 원본은 유지됩니다.") }
    }
    private func stackSection(_ title: String, stacks: [Stack]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(title).font(.headline); Text("\(stacks.count)").foregroundStyle(.secondary) }
            stackSectionRows(stacks, completed: false)
        }
    }
    @ViewBuilder private func stackSectionRows(_ stacks: [Stack], completed: Bool) -> some View {
        if stacks.isEmpty {
            Text(completed ? "완료한 스택이 없어요." : "진행 중인 스택이 없어요.")
                .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 12)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(stacks.enumerated()), id: \.element.id) { index, stack in
                    HStack(spacing: 0) {
                        NavigationLink { StackDetailView(stackID: stack.id) } label: { StackRow(stack: stack) }
                            .buttonStyle(.plain)
                        if completed {
                            Button { restarting = stack; showRestartConfirmation = true } label: { Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44) }
                                .buttonStyle(.plain).foregroundStyle(Palette.accent)
                                .accessibilityLabel("\(stack.title) 다시 학습하기")
                        }
                    }
                    if index < stacks.count - 1 { Divider().padding(.leading, 52) }
                }
            }.background(.background, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
struct ReviewDepthListView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            Section {
                ForEach(1...store.reviewDepthCount, id: \.self) { depth in
                    if let stack = store.reviewDepthStack(at: depth) {
                        NavigationLink { ReviewDepthDetailView(depth: depth) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(depth)단계").font(.headline)
                                Text("\(stack.words.count)개 단어 · \(stack.isComplete ? "학습 완료" : "\(Int(stack.progress * 100))% 완료")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                }
            } footer: {
                Text("학습 중 ‘알았어요 · 다음 단계에 담기’를 누른 단어만 모입니다. 각 단계는 내 스택 및 라이브러리와 별도로 저장됩니다.")
            }
        }.navigationTitle("단계별 단어")
    }
}
struct ReviewDepthDetailView: View {
    @Environment(AppStore.self) private var store
    let depth: Int
    @State private var studying = false
    @State private var restarting = false
    @State private var deletingWord: Word?
    private var stack: Stack? { store.reviewDepthStack(at: depth) }
    var body: some View {
        List {
            if let stack {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(stack.mastered.count) / \(stack.words.count * 2) 방향 완료")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ProgressView(value: stack.progress).tint(Palette.accent)
                        Button(stack.isComplete ? "이 단계 다시 학습" : "이 단계 학습 시작") {
                            if stack.isComplete { restarting = true } else { studying = true }
                        }.buttonStyle(PrimaryButton()).disabled(stack.words.isEmpty)
                    }.padding(.vertical, 8)
                }
                Section("단어 \(stack.words.count)개") {
                    if stack.words.isEmpty { Text("학습 중 다음 단계에 담은 단어가 이곳에 표시됩니다.").foregroundStyle(.secondary) }
                    ForEach(stack.words) { word in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(word.japanese).font(.headline).textSelection(.enabled)
                                Text(word.korean).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { deletingWord = word } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                                .buttonStyle(.borderless).accessibilityLabel("\(word.japanese) 단계에서 제거")
                        }
                    }
                }
            }
        }
        .navigationTitle("\(depth)단계 단어")
        .fullScreenCover(isPresented: $studying) {
            if let stack { StudyView(stackID: stack.id, reviewDepth: depth) }
        }
        .confirmationDialog("이 단계의 학습 기록을 초기화할까요?", isPresented: $restarting, titleVisibility: .visible) {
            Button("다시 학습하기") { if store.restartReviewDepth(at: depth) { studying = true } }
        }
        .confirmationDialog("이 단어를 \(depth)단계에서 제거할까요?", isPresented: Binding(
            get: { deletingWord != nil }, set: { if !$0 { deletingWord = nil } }
        ), titleVisibility: .visible) {
            if let deletingWord {
                Button("단어 제거", role: .destructive) {
                    store.removeReviewDepthWord(deletingWord.id, at: depth)
                    self.deletingWord = nil
                }
            }
        } message: { Text("다른 단계와 원래 스택의 카드는 유지됩니다.") }
    }
}
struct StackRow: View {
    var stack: Stack
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: stack.isComplete ? "checkmark.seal.fill" : "rectangle.stack.fill")
                .font(.body).foregroundStyle(Palette.accent).frame(width: 32, height: 32)
                .background(Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(stack.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(stack.words.count)개 단어 · \(stack.isComplete ? "학습 완료" : stack.words.isEmpty ? "카드 없음" : "\(Int(stack.progress * 100))% 완료")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }.padding(.leading, 12).padding(.trailing, 8).padding(.vertical, 9)
    }
}
struct StackDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let stackID: UUID
    @State private var add = false
    @State private var study = false
    @State private var reset = false
    @State private var deletingStack = false
    @State private var deletingWord: Word?
    private var stack: Stack? { store.archive.stacks.first { $0.id == stackID } }
    var body: some View {
        Group {
            if let stack {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(stack.isComplete ? "모든 방향을 익혔어요!" : "한 장씩, 차근차근").font(.title2.bold())
                            ProgressView(value: stack.progress)
                            Text("\(stack.mastered.count) / \(stack.words.count * 2) 방향 완료").font(.caption).foregroundStyle(.secondary)
                            Button(stack.isComplete ? "다시 학습하기" : "학습 시작") {
                                if stack.isComplete { reset = true } else { study = true }
                            }.buttonStyle(PrimaryButton()).disabled(stack.words.isEmpty)
                        }.padding(.vertical, 12)
                    }
                    Section("카드 \(stack.words.count)개") {
                        ForEach(stack.words) { word in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(word.japanese).font(.headline).textSelection(.enabled)
                                    Spacer()
                                    CopyJapaneseButton(text: word.japanese)
                                    SearchJapaneseButton(text: word.japanese)
                                    Button(role: .destructive) { deletingWord = word } label: {
                                        Image(systemName: "trash").frame(width: 44, height: 44)
                                    }.buttonStyle(.borderless).accessibilityLabel("\(word.japanese) 카드 삭제")
                                }
                                Text(word.korean)
                            }.padding(.vertical, 6)
                        }.onDelete { indices in
                            var updated = stack; updated.words.remove(atOffsets: indices); updated.prepare(poolSize: store.poolSize); store.update(updated)
                        }
                        Button { add = true } label: { Label("카드 추가", systemImage: "plus") }
                    }
                    Section {
                        Button("내 스택에서 제거", systemImage: "trash", role: .destructive) { deletingStack = true }
                    } footer: { Text("스택을 제거하면 이 스택의 학습 기록도 삭제됩니다. 라이브러리의 원본은 유지됩니다.") }
                }.navigationTitle(stack.title).toolbar {
                    NavigationLink {
                        WordReportComposer(library: (store.archive.libraries + store.archive.server).first { $0.stacks.contains { $0.id == (stack.sourceID ?? stack.id) } }, stacks: [stack])
                    } label: { Label("틀린 단어 제보", systemImage: "flag") }
                }
            }
        }
        .sheet(isPresented: $add) { CardEditor { word in
            guard var updated = stack else { return }; updated.words.append(word); updated.prepare(poolSize: store.poolSize); store.update(updated)
        } }
        .fullScreenCover(isPresented: $study) { StudyView(stackID: stackID) }
        .confirmationDialog("완료 기록을 초기화하고 다시 학습할까요?", isPresented: $reset, titleVisibility: .visible) {
            Button("다시 학습하기") { if store.restartStack(stackID) { study = true } }
        } message: { Text("삭제한 카드는 제외하고 수정한 내용은 그대로 사용합니다.") }
        .confirmationDialog("내 스택에서 제거할까요?", isPresented: $deletingStack, titleVisibility: .visible) {
            Button("스택과 학습 기록 삭제", role: .destructive) { store.removeStack(stackID); dismiss() }
        } message: { Text("라이브러리의 원본 카드는 그대로 남습니다.") }
        .confirmationDialog("\(deletingWord?.japanese ?? "") 카드를 삭제할까요?", isPresented: Binding(
            get: { deletingWord != nil }, set: { if !$0 { deletingWord = nil } }
        ), titleVisibility: .visible) {
            if let deletingWord {
                Button("카드 삭제", role: .destructive) { store.removeWord(deletingWord.id, from: stackID); self.deletingWord = nil }
            }
        } message: { Text("이 카드의 학습 기록도 지워집니다. 라이브러리의 원본은 유지됩니다.") }
    }
}
struct NameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String; let placeholder: String; var onSave: (String) -> Void
    @State private var name = ""
    var body: some View {
        NavigationStack {
            Form { TextField(placeholder, text: $name) }.navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("만들기") { onSave(name.trimmingCharacters(in: .whitespacesAndNewlines)); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
        }.presentationDetents([.medium])
    }
}
struct CardEditor: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Word) -> Void
    @State private var japanese = ""; @State private var korean = ""
    private var valid: Bool { [japanese, korean].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    var body: some View {
        NavigationStack {
            Form {
                Section("학습할 표현") { TextField("일본어", text: $japanese, axis: .vertical); TextField("한국어 뜻", text: $korean, axis: .vertical) }
            }.navigationTitle("카드 추가").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") {
                    onSave(Word(japanese: japanese.trimmingCharacters(in: .whitespacesAndNewlines), korean: korean.trimmingCharacters(in: .whitespacesAndNewlines), example: "")); dismiss()
                }.disabled(!valid) }
            }
        }
    }
}
