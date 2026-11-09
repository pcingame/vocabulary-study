import SwiftUI
import PhotosUI
import Vision

struct Draft: Identifiable, Equatable {
    let id = UUID()
    var term: String
    var pos: String
    var meaning: String

    static func == (a: Draft, b: Draft) -> Bool { (a.term, a.pos, a.meaning) == (b.term, b.pos, b.meaning) }

    /// Bỏ từ đã có (trong chủ đề hoặc đã quét trước đó) và từ trùng trong chính lần quét, không phân biệt hoa thường.
    static func dedupe(_ found: [Draft], existing: [String]) -> (kept: [Draft], skipped: Int) {
        var seen = Set(existing.map(Answer.normalize))
        let kept = found.filter { seen.insert(Answer.normalize($0.term)).inserted }
        return (kept, found.count - kept.count)
    }

    /// Tạo từ; nếu có trong bộ TOEIC thì tự điền phiên âm và câu ví dụ.
    func makeWord(createdAt: Date) -> Word {
        let t = term.trimmingCharacters(in: .whitespaces)
        let row = Content.vocab.lazy.flatMap(\.words).first { Answer.normalize($0.term) == Answer.normalize(t) }
        return Word(term: t, ipa: row?.ipa ?? "", pos: pos, meaning: meaning,
                    example: row?.example ?? "", exampleMeaning: row?.exampleMeaning ?? "", createdAt: createdAt)
    }
}

struct ScanView: View {
    let topic: Topic
    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var showCamera = false
    @State private var drafts: [Draft] = []
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Chụp trang sách", systemImage: "camera") { showCamera = true }
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("Chọn ảnh có sẵn", systemImage: "photo")
                    }
                } footer: {
                    Text(busy ? "Đang đọc chữ…" : message ?? "Có thể quét nhiều trang, từ sẽ được cộng dồn.")
                }
                if !drafts.isEmpty {
                    Section("Kiểm tra lại — vuốt để xoá dòng sai") {
                        ForEach($drafts) { $d in
                            VStack(alignment: .leading) {
                                TextField("Từ", text: $d.term).bold()
                                    .textInputAutocapitalization(.never)
                                HStack {
                                    TextField("loại", text: $d.pos).frame(width: 50).foregroundStyle(.secondary)
                                    TextField("Nghĩa", text: $d.meaning)
                                }
                            }
                        }
                        .onDelete { drafts.remove(atOffsets: $0) }
                    }
                }
            }
            .navigationTitle("Quét từ vựng")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu \(drafts.count) từ") { save() }.disabled(drafts.isEmpty)
                }
            }
            .onChange(of: photo) {
                guard let photo else { return }
                Task {
                    if let data = try? await photo.loadTransferable(type: Data.self) { await scan(data) }
                    self.photo = nil
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { data in Task { await scan(data) } }.ignoresSafeArea()
            }
        }
    }

    private func scan(_ data: Data) async {
        busy = true
        defer { busy = false }
        do {
            let found = try await OCR.words(from: data)
            let (kept, skipped) = Draft.dedupe(found, existing: topic.words.map(\.term) + drafts.map(\.term))
            drafts += kept
            message = found.isEmpty ? "Không tìm thấy từ nào, thử chụp thẳng và rõ hơn."
                : "Tìm thấy \(kept.count) từ mới." + (skipped > 0 ? " Đã bỏ qua \(skipped) từ trùng." : "")
        } catch {
            message = "Không đọc được ảnh: \(error.localizedDescription)"
        }
    }

    private func save() {
        let now = Date.now
        for (i, d) in drafts.enumerated() where !d.term.trimmingCharacters(in: .whitespaces).isEmpty {
            // createdAt tăng dần để giữ đúng thứ tự trong sách khi học
            topic.words.append(d.makeWord(createdAt: now.addingTimeInterval(Double(i) / 1000)))
        }
        dismiss()
    }
}

enum OCR {
    static let maxSide = 3000.0

    /// Kích thước sau khi thu nhỏ để cạnh dài ≤ `maxSide` (ảnh 48MP làm OCR chậm và tốn RAM).
    static func downscaledSize(_ size: CGSize, maxSide: Double = maxSide) -> CGSize {
        let scale = min(1, maxSide / max(size.width, size.height))
        return CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }

    static func words(from data: Data) async throws -> [Draft] {
        var image = data
        if let ui = UIImage(data: data), ui.size != downscaledSize(ui.size) {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let size = downscaledSize(ui.size)
            image = UIGraphicsImageRenderer(size: size, format: format)
                .jpegData(withCompressionQuality: 0.9) { _ in ui.draw(in: CGRect(origin: .zero, size: size)) }
        }
        var request = RecognizeTextRequest()
        request.recognitionLanguages = [Locale.Language(identifier: "vi-VN"), Locale.Language(identifier: "en-US")]
        let observations = try await request.perform(on: image)
        return parse(observations.compactMap { o in
            o.topCandidates(1).first.map { (text: $0.string, x: Double(o.boundingBox.cgRect.minX)) }
        })
    }

    /// Tách các dòng dạng `generous /ˈdʒɛnərəs/ (adj) – hào phóng`.
    /// Ô bị xuống dòng (`kind-hearted /…/` rồi `(adj) – tốt bụng`) được ghép theo cột gần nhất.
    /// Bỏ IPA vì OCR đọc sai gần hết; phát âm đã có giọng đọc của máy lo.
    static func parse(_ lines: [(text: String, x: Double)]) -> [Draft] {
        let entry = /^(?<head>[^(]*)\((?<pos>[^)\s]{1,4})(?:\)|$)(?<rest>.*)$/
        var drafts: [Draft] = []
        var pending: [(index: Int, x: Double)] = []  // dòng đầu chưa có nghĩa

        func term(_ head: Substring) -> String {
            String(head.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)[0])
                .trimmingCharacters(in: .whitespaces)
        }
        func meaning(_ rest: Substring) -> String {
            String(rest.drop { " -–—)".contains($0) }).trimmingCharacters(in: .whitespaces)
        }
        func pos(_ raw: Substring) -> String {
            let p = raw.lowercased().filter(\.isLetter)
            return p.hasPrefix("adv") ? "adv" : p.hasPrefix("ad") ? "adj" : p
        }

        for (raw, x) in lines {
            let text = raw.trimmingCharacters(in: .whitespaces)
            if let m = text.wholeMatch(of: entry) {
                let t = term(m.head)
                if t.isEmpty {
                    // phần sau của ô bị xuống dòng → ghép vào dòng đầu cùng cột
                    guard let k = pending.indices.min(by: { abs(pending[$0].x - x) < abs(pending[$1].x - x) }),
                          abs(pending[k].x - x) < 0.1 else { continue }
                    drafts[pending[k].index].pos = pos(m.pos)
                    drafts[pending[k].index].meaning = meaning(m.rest)
                    pending.remove(at: k)
                } else if t.contains(where: \.isLetter) {
                    drafts.append(Draft(term: t, pos: pos(m.pos), meaning: meaning(m.rest)))
                }
            } else if text.contains("/") {
                let t = term(Substring(text))
                guard t.contains(where: \.isLetter) else { continue }
                pending.append((drafts.count, x))
                drafts.append(Draft(term: t, pos: "", meaning: ""))
            }
        }
        return drafts.filter { !$0.meaning.isEmpty }  // ô thiếu nghĩa thường là trang bên cạnh bị cắt
    }
}

struct CameraView: UIViewControllerRepresentable {
    let onImage: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let data = (info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9) { parent.onImage(data) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
