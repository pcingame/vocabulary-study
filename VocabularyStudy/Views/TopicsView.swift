import SwiftUI
import SwiftData

struct TopicsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Topic.createdAt) private var topics: [Topic]
    @State private var adding = false
    @State private var browsingDecks = false
    @State private var newName = ""
    @State private var takenName: String?
    @State private var pendingDelete: Topic?
    @Query private var words: [Word]
    @State private var query = ""
    @State private var status: Word.Status?
    @State private var searching = false
    @AppStorage(Settings.grammarScoresKey) private var scores = GrammarScores()
    @AppStorage(Settings.roadmapAutoKey) private var roadmapAuto = Settings.defaultRoadmapAuto

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty && status == nil {
                    ForEach(topics) { topic in
                        NavigationLink(value: topic) { TopicRow(topic: topic) }
                            .contextMenu {  // nhấn giữ để xoá, ngoài cách vuốt sang trái
                                Button("Xoá chủ đề", systemImage: "trash", role: .destructive) { pendingDelete = topic }
                            }
                    }
                    .onDelete { pendingDelete = $0.first.map { topics[$0] } }
                } else {
                    let found = Word.search(words, query: query, status: status)
                    Section("\(found.count) từ") {
                        ForEach(found) { word in
                            NavigationLink(value: word.topic) {
                                VStack(alignment: .leading) {
                                    Text(word.term).bold()
                                    Text("\(word.meaning) · \(word.topic?.name ?? "")").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityIdentifier("result-\(word.term)")
                        }
                    }
                }
            }
            .searchable(text: $query, isPresented: $searching, prompt: "Tìm từ hoặc nghĩa")
            .onChange(of: searching) { if !searching { status = nil } }  // đóng ô tìm thì bỏ lọc, về danh sách chủ đề
            .searchScopes($status, activation: .onSearchPresentation) {
                Text("Tất cả").tag(Word.Status?.none)
                Text("Mới").tag(Word.Status?.some(.new))
                Text("Đang học").tag(Word.Status?.some(.learning))
                Text("Đã thuộc").tag(Word.Status?.some(.mastered))
            }
            .confirmationDialog("Xoá chủ đề?", isPresented: Binding { pendingDelete != nil } set: { if !$0 { pendingDelete = nil } },
                                titleVisibility: .visible, presenting: pendingDelete) { topic in
                Button("Xoá", role: .destructive) { context.delete(topic) }
                    .accessibilityIdentifier("confirmDeleteTopic")
                Button("Huỷ", role: .cancel) {}
            } message: { topic in
                let readds = Roadmap.readdsAfterDelete(topic, topics: topics, scores: scores, enabled: roadmapAuto)
                Text("Xoá \"\(topic.name)\" và \(topic.words.count) từ bên trong. Không thể hoàn tác."
                     + (readds ? "\n\nĐây là bộ từ của chặng đang học: app sẽ tự thêm lại bộ này và tiến độ cũ bị mất. Muốn bỏ hẳn thì tắt \"Tự thêm bộ từ của chặng\" trong Cài đặt." : ""))
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
                    if Topic.nameTaken(name, in: topics) { takenName = name }
                    else if !name.isEmpty { context.insert(Topic(name: name)) }
                    newName = ""
                }
            }
            .alert("Chủ đề “\(takenName ?? "")” đã có", isPresented: .constant(takenName != nil)) {
                Button("OK") { takenName = nil }
            } message: {
                Text("Hãy đặt tên khác, hoặc thêm từ vào chủ đề có sẵn.")
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
                        Text(deck.words.prefix(4).map(\.term).joined(separator: ", ") + "…")
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
    @State private var editing: Word?
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
                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(word.term).bold()
                                Text(word.ipa).foregroundStyle(.secondary)
                                Text(word.pos).italic().foregroundStyle(.secondary)
                            }
                            Text(word.meaning).foregroundStyle(.secondary)
                            if !word.example.isEmpty {
                                Text(word.example).font(.caption).italic().foregroundStyle(.secondary)
                                if !word.exampleMeaning.isEmpty {
                                    Text(word.exampleMeaning).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Chạm để sửa")
                        .accessibilityIdentifier("word-\(word.term)")
                        Spacer()
                        Button { Speaker.say(word.term) } label: {
                            Image(systemName: "speaker.wave.2")
                                .frame(width: 44, height: 44)  // vùng chạm tối thiểu 44pt
                                .contentShape(.rect)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Nghe \(word.term)")
                    }
                    .contentShape(.rect)
                    .onTapGesture { editing = word }  // chạm để sửa; nút nghe vẫn bấm riêng được
                    .contextMenu {
                        Button("Xoá từ", systemImage: "trash", role: .destructive) { context.delete(word) }
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
        .sheet(isPresented: $addingWord) { WordFormView(topic: topic) }
        .sheet(item: $editing) { WordFormView(topic: topic, word: $0) }
        .sheet(isPresented: $scanning) { ScanView(topic: topic) }
        .fullScreenCover(isPresented: $studying) { StudyView(topic: topic) }
        .fullScreenCover(isPresented: $flashcards) { FlashcardView(words: words) }
    }
}

/// Thêm từ (word == nil, thêm liên tục) hoặc sửa một từ có sẵn.
struct WordFormView: View {
    let topic: Topic
    let word: Word?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var confirmingDelete = false
    @State private var fields: WordFields
    @State private var added = 0
    @State private var confirmingDuplicate = false
    @FocusState private var focused: Bool

    init(topic: Topic, word: Word? = nil) {
        self.topic = topic
        self.word = word
        _fields = State(initialValue: word.map(WordFields.init) ?? WordFields())
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Từ (vd: generous)", text: $fields.term)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .accessibilityIdentifier("fieldTerm")
                TextField("Phiên âm (không bắt buộc, vd: /ˈdʒɛnərəs/)", text: $fields.ipa)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Từ loại (n, v, adj…)", text: $fields.pos)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Nghĩa (vd: hào phóng)", text: $fields.meaning)
                    .accessibilityIdentifier("fieldMeaning")
                TextField("Câu ví dụ (không bắt buộc)", text: $fields.example, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                TextField("Nghĩa câu ví dụ (không bắt buộc)", text: $fields.exampleMeaning, axis: .vertical)
                if word == nil {
                    Button("Thêm") {
                        let term = Answer.normalize(fields.term)
                        if topic.words.contains(where: { Answer.normalize($0.term) == term }) { confirmingDuplicate = true } else { add() }
                    }
                    .disabled(!fields.isValid)
                }
                if word != nil {
                    Section {
                        Button("Xoá từ", role: .destructive) { confirmingDelete = true }
                            .accessibilityIdentifier("deleteWord")
                    }
                }
            }
            .confirmationDialog("Xoá “\(word?.term ?? "")”?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Xoá", role: .destructive) {
                    if let word { context.delete(word) }
                    dismiss()
                }
                .accessibilityIdentifier("confirmDeleteWord")
            } message: {
                Text("Tiến độ học của từ này cũng bị xoá. Không thể hoàn tác.")
            }
            .navigationTitle(word != nil ? "Sửa từ" : added == 0 ? "Nhập từ" : "Đã thêm \(added) từ")
            .toolbar {
                if let word {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Huỷ") { dismiss() }.accessibilityIdentifier("cancelEdit")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lưu") { fields.apply(to: word); dismiss() }
                            .disabled(!fields.isValid)
                            .accessibilityIdentifier("saveWord")
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } }
                }
            }
            .onAppear { if word == nil { focused = true } }
            .alert("Từ đã có, vẫn thêm?", isPresented: $confirmingDuplicate) {
                Button("Vẫn thêm") { add() }
                Button("Huỷ", role: .cancel) {}
            } message: {
                Text("“\(fields.term.trimmingCharacters(in: .whitespaces))” đã có trong chủ đề này.")
            }
        }
    }

    private func add() {
        topic.words.append(fields.makeWord())
        fields = WordFields()
        added += 1
        focused = true
    }
}

/// Dòng chủ đề: tên, số từ, thanh tiến độ đã học và số từ đến hạn.
struct TopicRow: View {
    let topic: Topic

    var body: some View {
        let learned = topic.words.filter { $0.learnedAt != nil }.count
        let due = topic.words.filter { $0.learnedAt != nil && $0.due <= .now }.count
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(topic.name, value: "\(topic.words.count) từ")
            ProgressView(value: Double(learned), total: Double(max(1, topic.words.count)))
            Text("Đã học \(learned)/\(topic.words.count)" + (due > 0 ? " · \(due) từ đến hạn" : ""))
                .font(.caption)
                .foregroundStyle(due > 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(topic.name), \(topic.words.count) từ")
        .accessibilityValue("Đã học \(learned), \(due) từ đến hạn")
    }
}
