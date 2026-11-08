import SwiftUI
import SwiftData

struct TopicsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Topic.createdAt) private var topics: [Topic]
    @State private var adding = false
    @State private var browsingDecks = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(topics) { topic in
                    NavigationLink(value: topic) {
                        LabeledContent(topic.name, value: "\(topic.words.count) từ")
                    }
                }
                .onDelete { for i in $0 { context.delete(topics[i]) } }
            }
            .overlay {
                if topics.isEmpty {
                    ContentUnavailableView("Chưa có chủ đề", systemImage: "books.vertical",
                                           description: Text("Bấm + để tạo chủ đề hoặc thêm bộ từ TOEIC có sẵn."))
                }
            }
            .navigationTitle("Chủ đề")
            .navigationDestination(for: Topic.self) { TopicDetailView(topic: $0) }
            .toolbar {
                Menu("Thêm chủ đề", systemImage: "plus") {
                    Button("Bộ từ TOEIC có sẵn", systemImage: "star") { browsingDecks = true }
                    Button("Chủ đề mới", systemImage: "folder.badge.plus") { adding = true }
                }
                .accessibilityIdentifier("addTopicMenu")
            }
            .sheet(isPresented: $browsingDecks) { DecksView() }
            .alert("Chủ đề mới", isPresented: $adding) {
                TextField("Ví dụ: Lòng tốt", text: $newName)
                Button("Huỷ", role: .cancel) { newName = "" }
                Button("Thêm") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { context.insert(Topic(name: name)) }
                    newName = ""
                }
            }
        }
    }
}

struct DecksView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var topics: [Topic]

    var body: some View {
        NavigationStack {
            List(Content.vocab, id: \.name) { deck in
                let added = topics.contains { $0.name == deck.name }
                HStack {
                    VStack(alignment: .leading) {
                        Text(deck.name)
                        Text(deck.words.prefix(4).map { $0[0] }.joined(separator: ", ") + "…")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(added ? "Đã thêm" : "Thêm \(deck.words.count) từ") { Content.add(deck, to: context) }
                        .buttonStyle(.bordered)
                        .disabled(added)
                }
            }
            .navigationTitle("Bộ từ TOEIC")
            .toolbar { Button("Xong") { dismiss() } }
        }
    }
}

struct TopicDetailView: View {
    let topic: Topic
    @Environment(\.modelContext) private var context
    @State private var addingWord = false
    @State private var scanning = false
    @State private var studying = false
    @State private var flashcards = false

    var body: some View {
        let words = topic.words.sorted { $0.createdAt < $1.createdAt }
        List {
            Section {
                Button("Học chủ đề này") { studying = true }
                    .disabled(Word.todayQueue(topic.words).isEmpty)
                Button("Lật thẻ (không tính vào lịch ôn)") { flashcards = true }
                    .disabled(words.isEmpty)
                    .accessibilityIdentifier("flashcardButton")
            }
            Section("\(words.count) từ") {
                ForEach(words) { word in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(word.term).bold()
                            Text(word.ipa).foregroundStyle(.secondary)
                            Text(word.pos).italic().foregroundStyle(.secondary)
                            Spacer()
                            Button("Nghe", systemImage: "speaker.wave.2") { Speaker.say(word.term) }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                        }
                        Text(word.meaning).foregroundStyle(.secondary)
                        if !word.example.isEmpty {
                            Text(word.example).font(.caption).italic().foregroundStyle(.secondary)
                            if !word.exampleMeaning.isEmpty {
                                Text(word.exampleMeaning).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { for i in $0 { context.delete(words[i]) } }
            }
        }
        .navigationTitle(topic.name)
        .toolbar {
            Menu("Thêm từ", systemImage: "plus") {
                Button("Quét ảnh sách", systemImage: "camera") { scanning = true }
                Button("Nhập tay", systemImage: "square.and.pencil") { addingWord = true }
            }
            .accessibilityIdentifier("addWordMenu")
        }
        .sheet(isPresented: $addingWord) { AddWordView(topic: topic) }
        .sheet(isPresented: $scanning) { ScanView(topic: topic) }
        .fullScreenCover(isPresented: $studying) { StudyView(topic: topic) }
        .fullScreenCover(isPresented: $flashcards) { FlashcardView(words: words) }
    }
}

struct AddWordView: View {
    let topic: Topic
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var ipa = ""
    @State private var pos = ""
    @State private var meaning = ""
    @State private var example = ""
    @State private var exampleMeaning = ""
    @State private var added = 0
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Từ (vd: generous)", text: $term)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                TextField("Phiên âm (không bắt buộc, vd: /ˈdʒɛnərəs/)", text: $ipa)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Từ loại (n, v, adj…)", text: $pos)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Nghĩa (vd: hào phóng)", text: $meaning)
                TextField("Câu ví dụ (không bắt buộc)", text: $example, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                TextField("Nghĩa câu ví dụ (không bắt buộc)", text: $exampleMeaning, axis: .vertical)
                Button("Thêm") {
                    topic.words.append(Word(term: term.trimmingCharacters(in: .whitespaces), ipa: ipa, pos: pos,
                                            meaning: meaning, example: example, exampleMeaning: exampleMeaning))
                    term = ""; ipa = ""; pos = ""; meaning = ""; example = ""; exampleMeaning = ""
                    added += 1
                    focused = true
                }
                .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty || meaning.isEmpty)
            }
            .navigationTitle(added == 0 ? "Nhập từ" : "Đã thêm \(added) từ")
            .toolbar { Button("Xong") { dismiss() } }
            .onAppear { focused = true }
        }
    }
}
