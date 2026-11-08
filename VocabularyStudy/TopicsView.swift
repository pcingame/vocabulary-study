import SwiftUI
import SwiftData

struct TopicsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Topic.createdAt) private var topics: [Topic]
    @State private var adding = false
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
                                           description: Text("Bấm + để tạo chủ đề đầu tiên."))
                }
            }
            .navigationTitle("Chủ đề")
            .navigationDestination(for: Topic.self) { TopicDetailView(topic: $0) }
            .toolbar { Button("Thêm chủ đề", systemImage: "plus") { adding = true } }
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

struct TopicDetailView: View {
    let topic: Topic
    @Environment(\.modelContext) private var context
    @State private var addingWord = false
    @State private var scanning = false
    @State private var studying = false

    var body: some View {
        let words = topic.words.sorted { $0.createdAt < $1.createdAt }
        List {
            Section {
                Button("Học chủ đề này") { studying = true }
                    .disabled(Word.todayQueue(topic.words).isEmpty)
            }
            Section("\(words.count) từ") {
                ForEach(words) { word in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(word.term).bold()
                            Text(word.pos).italic().foregroundStyle(.secondary)
                        }
                        Text(word.meaning).foregroundStyle(.secondary)
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
        }
        .sheet(isPresented: $addingWord) { AddWordView(topic: topic) }
        .sheet(isPresented: $scanning) { ScanView(topic: topic) }
        .fullScreenCover(isPresented: $studying) { StudyView(topic: topic) }
    }
}

struct AddWordView: View {
    let topic: Topic
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var pos = ""
    @State private var meaning = ""
    @State private var added = 0
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Từ (vd: generous)", text: $term)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                TextField("Từ loại (n, v, adj…)", text: $pos)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Nghĩa (vd: hào phóng)", text: $meaning)
                Button("Thêm") {
                    topic.words.append(Word(term: term.trimmingCharacters(in: .whitespaces), pos: pos, meaning: meaning))
                    term = ""; pos = ""; meaning = ""
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
