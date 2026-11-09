import SwiftUI

/// Thẻ trắc nghiệm: xem từ, chọn 1 trong 4 nghĩa. Đúng = Dễ, sai = Quên (hiện đáp án rồi bấm Tiếp).
struct ChoiceCard: View {
    let word: Word
    let onDone: (Word.Grade) -> Void
    @State private var choices: [String]  // giữ thứ tự trộn lần đầu, không đổi khi view vẽ lại
    @State private var picked: String?

    init(word: Word, choices: [String], onDone: @escaping (Word.Grade) -> Void) {
        self.word = word
        self.onDone = onDone
        _choices = State(initialValue: choices)
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            WordFront(word: word)
            Spacer()
            ForEach(choices, id: \.self) { choice in
                Button { pick(choice) } label: { Text(choice).frame(maxWidth: .infinity) }
                    .tint(color(choice))
                    .disabled(picked != nil)
            }
            if picked != nil {
                Button { onDone(.forgot) } label: { Text("Tiếp").frame(maxWidth: .infinity) }
                    .accessibilityIdentifier("choiceNext")
            }
        }
        .pastelProminent()
        .controlSize(.large)
        .padding()
        .task { Speaker.say(word.term) }
    }

    private func pick(_ choice: String) {
        if choice == word.meaning { onDone(.easy) } else { picked = choice }
    }

    private func color(_ choice: String) -> Color {
        guard let picked else { return .accentFill }
        return choice == word.meaning ? .easy : choice == picked ? .forgot : Color(.systemGray5)
    }
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
                .pastelProminent()
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
            piece.foregroundColor = same ? .primary : .forgotInk
            result += piece
        }
        return result
    }
}
