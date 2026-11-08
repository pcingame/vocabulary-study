import SwiftUI

enum StudyMode: String, CaseIterable {
    case flip, typing, listening
    var title: String { ["Lật thẻ", "Gõ từ", "Nghe – gõ"][Self.allCases.firstIndex(of: self)!] }
}

enum Answer {
    /// Bỏ hoa thường, dấu (é = e) và khoảng trắng thừa.
    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func matches(_ input: String, _ term: String) -> Bool { normalize(input) == normalize(term) }
}

/// Thẻ gõ từ: xem nghĩa (hoặc nghe) rồi gõ từ tiếng Anh.
/// Gõ đúng ngay = Dễ. Gõ sai: hiện đáp án, tính Quên, phải gõ lại đúng mới sang thẻ tiếp.
struct TypingCard: View {
    let word: Word
    let listening: Bool
    let onDone: (Word.Grade) -> Void
    @State private var typed = ""
    @State private var wrongAttempt: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            if listening {
                Button("Nghe lại", systemImage: "speaker.wave.2.fill") { Speaker.say(word.term) }
                    .font(.title)
                    .accessibilityIdentifier("listenAgain")
            } else {
                if !word.pos.isEmpty { Text(word.pos).italic().foregroundStyle(.secondary) }
                Text(word.meaning).font(.title).multilineTextAlignment(.center)
            }
            if let wrongAttempt {
                VStack(spacing: 6) {
                    Text("Bạn gõ: \(wrongAttempt)").strikethrough().foregroundStyle(.secondary)
                    Text(highlighted(wrongAttempt)).font(.largeTitle.bold())
                        .accessibilityIdentifier("correctAnswer")
                    if !word.ipa.isEmpty { Text(word.ipa).foregroundStyle(.secondary) }
                    if listening { Text(word.meaning) }
                    Text("Gõ lại cho đúng để tiếp tục").font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer()
            TextField("Gõ từ tiếng Anh", text: $typed)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .textFieldStyle(.roundedBorder)
                .font(.title2)
                .multilineTextAlignment(.center)
                .onSubmit(check)
                .accessibilityIdentifier("typingField")
            Button { check() } label: { Text("Kiểm tra").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("typingCheck")
        }
        .padding()
        .onAppear {
            focused = true
            if listening { Speaker.say(word.term) }
        }
    }

    private func check() {
        if Answer.matches(typed, word.term) {
            onDone(wrongAttempt == nil ? .easy : .forgot)
        } else {
            wrongAttempt = typed
            typed = ""
            focused = true
            Speaker.say(word.term)
        }
    }

    /// Đáp án đúng, tô đỏ những chữ khác với chữ đã gõ ở cùng vị trí.
    // ponytail: so theo vị trí, gõ thiếu/thừa 1 chữ ở đầu sẽ tô đỏ cả phần sau; dùng diff (LCS) nếu thấy khó hiểu.
    private func highlighted(_ attempt: String) -> AttributedString {
        let given = Array(Answer.normalize(attempt))
        var result = AttributedString()
        for (i, ch) in word.term.enumerated() {
            var piece = AttributedString(String(ch))
            let same = i < given.count && Answer.normalize(String(ch)) == String(given[i])
            piece.foregroundColor = same ? .primary : .red
            result += piece
        }
        return result
    }
}
