import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Gợi ý sửa một dòng quét bị đọc sai (hay gặp với chữ viết tay). Chỉ là gợi ý, người dùng bấm mới thay.
struct Suggestion: Equatable {
    enum Source { case deck, spelling, ai }
    var term: String
    var pos: String
    var meaning: String
    var source: Source
}

enum VocabSuggester {
    /// Gợi ý từ bộ TOEIC: từ đọc được (bỏ dấu cách, gạch nối) gần giống một từ trong bộ.
    static func fromDeck(_ draft: Draft, rows: [VocabDeck.Entry] = Content.vocab.flatMap(\.words)) -> Suggestion? {
        let key = letters(draft.term)
        guard key.count >= 4 else { return nil }  // từ quá ngắn dễ khớp nhầm
        let limit = max(2, key.count / 4)  // số ký tự thêm/bớt cho phép (đổi 1 chữ = 2)
        let best = rows.lazy
            .map { (row: $0, changes: Array(key).difference(from: Array(letters($0.term))).count) }
            .filter { $0.changes <= limit }
            .min { $0.changes < $1.changes }
        guard let row = best?.row else { return nil }
        let s = Suggestion(term: row.term, pos: row.pos, meaning: row.meaning, source: .deck)
        return s.differs(from: draft) ? s : nil
    }

    /// Gợi ý chính tả tiếng Anh: ghép các mảnh bị tách ("repre sentative") hoặc sửa một từ đơn ("Exceding").
    /// Cụm nhiều từ sai thì bỏ qua, để AI lo.
    @MainActor static func spelling(_ draft: Draft) -> Suggestion? {
        let checker = UITextChecker()
        func isWord(_ w: String) -> Bool {
            checker.rangeOfMisspelledWord(in: w, range: NSRange(location: 0, length: w.utf16.count),
                                          startingAt: 0, wrap: false, language: "en_US").location == NSNotFound
        }
        let term = draft.term.trimmingCharacters(in: .whitespaces)
        let joined = term.split(separator: " ").joined()
        var fixed: String?
        if term.contains(" "), isWord(joined) {
            fixed = joined
        } else if !term.contains(" "), !isWord(term) {
            fixed = checker.guesses(forWordRange: NSRange(location: 0, length: term.utf16.count), in: term, language: "en_US")?.first
        }
        guard let fixed, fixed.lowercased() != term.lowercased() else { return nil }
        return Suggestion(term: fixed.lowercased(), pos: draft.pos, meaning: draft.meaning, source: .spelling)
    }

    private static func letters(_ s: String) -> String { Answer.normalize(s).filter(\.isLetter) }

    /// Máy có AI của Apple (iOS 26+, Apple Intelligence đang bật và đã tải xong mô hình).
    static var aiAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    /// Gửi cả trang cho AI trên máy sửa một lần (có ngữ cảnh chung nên sửa tốt hơn từng dòng). Trả về gợi ý theo id dòng.
    static func ai(_ drafts: [Draft]) async -> [UUID: Suggestion] {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), aiAvailable, !drafts.isEmpty {
            return await PageFixer.fix(drafts)
        }
        #endif
        return [:]
    }
}

#if canImport(FoundationModels)
@available(iOS 26, *)
private enum PageFixer {
    @Generable struct Fix {
        @Guide(description: "Số thứ tự dòng gốc") var line: Int
        @Guide(description: "Từ hoặc cụm từ tiếng Anh đúng chính tả, chữ thường") var term: String
        @Guide(description: "Nghĩa tiếng Việt đúng chính tả, có dấu") var meaning: String
    }
    @Generable struct Page { var fixes: [Fix] }

    static let instructions = """
        Bạn sửa lỗi do máy đọc nhầm chữ viết tay trong sổ từ vựng TOEIC. Mỗi dòng có số thứ tự, từ tiếng Anh và nghĩa tiếng Việt.
        Trả về đúng 1 kết quả cho mỗi dòng, cùng số thứ tự.
        - Chữ bị tách bởi dấu cách thường là 1 từ: "re im bur sement" là "reimbursement".
        - Máy hay đọc nhầm: n↔m, r↔n, f↔p, l↔h, cl↔ch, o↔a.
        - Nghĩa tiếng Việt thường thiếu hoặc sai dấu, sửa thành tiếng Việt đúng và khớp với từ tiếng Anh.
        - Không đổi sang từ khác. Không viết lại nghĩa bằng từ khác.
        """

    static func fix(_ drafts: [Draft]) async -> [UUID: Suggestion] {
        let prompt = drafts.enumerated().map { "\($0.offset + 1). \($0.element.term): \($0.element.meaning)" }.joined(separator: "\n")
        guard let page = try? await LanguageModelSession(instructions: instructions).respond(to: prompt, generating: Page.self) else { return [:] }
        var out: [UUID: Suggestion] = [:]
        for f in page.content.fixes where drafts.indices.contains(f.line - 1) {
            let d = drafts[f.line - 1]
            let s = Suggestion(term: f.term.trimmingCharacters(in: .whitespaces), pos: d.pos,
                               meaning: f.meaning.trimmingCharacters(in: .whitespaces), source: .ai)
            if !s.term.isEmpty, s.differs(from: d) { out[d.id] = s }
        }
        return out
    }
}
#endif

extension Suggestion {
    func differs(from d: Draft) -> Bool {
        Answer.normalize(term) != Answer.normalize(d.term) || Answer.normalize(meaning) != Answer.normalize(d.meaning)
    }
}
