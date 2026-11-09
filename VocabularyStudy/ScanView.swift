import SwiftUI
import PhotosUI
import Vision

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
