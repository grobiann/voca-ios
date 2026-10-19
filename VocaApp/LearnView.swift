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

struct LearnView: View {
    @Environment(AppStore.self) private var store
    @State private var studying: Stack?
    @State private var creating = false
    private var next: Stack? { store.archive.stacks.first { !$0.words.isEmpty && !$0.isComplete } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack { Label("일본어", systemImage: "globe.asia.australia"); Image(systemName: "arrow.right"); Text("한국어") }
                        .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("조금씩,\n내 말이 되는 시간.").font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("오늘도 한 장부터 시작해 볼까요?").foregroundStyle(.secondary)
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(store.archive.stacks.reduce(0) { $0 + $1.words.count })").font(.system(size: 52, weight: .light, design: .rounded))
                                Text("내가 모은 단어").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 18).fill(Palette.accent.opacity(0.10)).frame(width: 94, height: 115).rotationEffect(.degrees(-13)).offset(x: -15, y: -3)
                                RoundedRectangle(cornerRadius: 18).fill(Palette.accent).frame(width: 94, height: 115).rotationEffect(.degrees(8))
                                Text("あ").font(.system(size: 52, weight: .medium)).foregroundStyle(.white).rotationEffect(.degrees(8))
                            }.padding(.trailing, 16).accessibilityHidden(true)
                        }.padding(.vertical, 18)
                        Button { studying = next } label: { Label("학습 시작", systemImage: "play.fill") }
                            .buttonStyle(PrimaryButton()).disabled(next == nil).opacity(next == nil ? 0.45 : 1)
                        Text(next.map { "\($0.title) · 양방향 학습" } ?? "모든 학습을 마쳤어요. 스택을 추가하거나 다시 학습해 보세요.")
                            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }.padding(24).background(.background, in: RoundedRectangle(cornerRadius: 28))
                    HStack {
                        Text("내 스택").font(.title2.bold()); Text("\(store.archive.stacks.count)").foregroundStyle(.secondary)
                        Spacer(); Button { creating = true } label: { Image(systemName: "plus").font(.title3) }.accessibilityLabel("스택 만들기")
                    }
                    if store.archive.stacks.isEmpty { EmptyState(icon: "rectangle.stack", title: "첫 스택을 만들어 보세요", message: "직접 카드를 추가하거나 라이브러리에서 가져올 수 있어요.") }
                    ForEach(store.archive.stacks) { stack in
                        NavigationLink { StackDetailView(stackID: stack.id) } label: { StackRow(stack: stack) }.buttonStyle(.plain)
                    }
                }.padding(22)
            }.background(Palette.canvas).navigationTitle("학습").toolbarTitleDisplayMode(.inline)
                .sheet(isPresented: $creating) { NameSheet(title: "새 스택", placeholder: "예: 여행에서 만나는 말") { name in
                    store.archive.stacks.append(Stack(title: name)); store.save()
                } }
                .fullScreenCover(item: $studying) { StudyView(stackID: $0.id) }
        }
    }
}
struct StackRow: View {
    var stack: Stack
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: stack.isComplete ? "checkmark.seal.fill" : "rectangle.stack.fill")
                .font(.title2).foregroundStyle(Palette.accent).frame(width: 48, height: 54)
                .background(Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 8) {
                Text(stack.title).font(.headline)
                Text("\(stack.words.count)개 단어 · \(stack.isComplete ? "학습 완료" : "\(Int(stack.progress * 100))% 학습")").font(.caption).foregroundStyle(.secondary)
                ProgressView(value: stack.progress).tint(Palette.accent)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }.padding(18).background(.background, in: RoundedRectangle(cornerRadius: 22))
    }
}
struct StackDetailView: View {
    @Environment(AppStore.self) private var store
    let stackID: UUID
    @State private var add = false
    @State private var study = false
    @State private var reset = false
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
                                HStack { Text(word.japanese).font(.headline).textSelection(.enabled); Spacer(); CopyJapaneseButton(text: word.japanese) }
                                Text(word.korean)
                                Text(word.example).font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 6)
                        }.onDelete { indices in
                            var updated = stack; updated.words.remove(atOffsets: indices); updated.prepare(poolSize: store.poolSize); store.update(updated)
                        }
                        Button { add = true } label: { Label("카드 추가", systemImage: "plus") }
                    }
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
            Button("다시 학습하기") { if var updated = stack { updated.reset(poolSize: store.poolSize); store.update(updated); study = true } }
        }
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
    @State private var japanese = ""; @State private var korean = ""; @State private var example = ""
    private var valid: Bool { [japanese, korean, example].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    var body: some View {
        NavigationStack {
            Form {
                Section("학습할 표현") { TextField("일본어", text: $japanese, axis: .vertical); TextField("한국어 뜻", text: $korean, axis: .vertical) }
                Section("문장으로 기억하기") { TextField("일본어 사용 예문", text: $example, axis: .vertical).lineLimit(3...6) }
            }.navigationTitle("카드 추가").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") {
                    onSave(Word(japanese: japanese.trimmingCharacters(in: .whitespacesAndNewlines), korean: korean.trimmingCharacters(in: .whitespacesAndNewlines), example: example.trimmingCharacters(in: .whitespacesAndNewlines))); dismiss()
                }.disabled(!valid) }
            }
        }
    }
}
