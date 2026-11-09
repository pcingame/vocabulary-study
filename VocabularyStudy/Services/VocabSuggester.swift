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
            .map { (row: $0, changes: changes(key, $0.term)) }
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

    /// Số ký tự phải thêm/bớt để biến a thành b, chỉ tính chữ cái (đổi 1 chữ = 2).
    static func changes(_ a: String, _ b: String) -> Int { Array(letters(a)).difference(from: Array(letters(b))).count }

    /// Từ AI đề xuất còn giống một trong các cách đọc (không quá 40% ký tự khác), để chặn AI đổi sang từ khác hẳn.
    /// Không ngắn hơn quá 10% (AI hay bỏ bớt chữ: "claim reimbursement" → "reimbursement").
    static func isClose(_ term: String, to readings: [String], ratio: Double = 0.4) -> Bool {
        readings.contains { r in
            let (a, b) = (letters(term).count, letters(r).count)
            return Double(changes(term, r)) <= ratio * Double(max(a, b)) && a * 10 >= b * 9
        }
    }

    /// Lọc câu trả lời của AI cho một dòng: phần nào còn giống chữ đọc được thì lấy, phần nào khác hẳn thì giữ của người viết.
    /// - Từ: phải gần giống chữ đọc được. AI chỉ cắt bớt chữ ("be directly related to" → "directly related") thì giữ từ gốc.
    /// - Nghĩa: lỏng hơn (nghĩa viết tay hay bị đọc sai nhiều), nhưng AI viết lại bằng từ khác ("hoàn trả" → "trả lại tiền") thì giữ nghĩa gốc.
    static func accept(term: String, meaning: String, for d: Draft) -> Suggestion? {
        let aiTerm = term.trimmingCharacters(in: .whitespaces)
        let aiMeaning = meaning.trimmingCharacters(in: .whitespaces)
        let trimmedByAI = letters(d.term).count > letters(aiTerm).count && letters(d.term).contains(letters(aiTerm))
        let termOK = !aiTerm.isEmpty && !trimmedByAI && isClose(aiTerm, to: termReadings(d))
        let meaningOK = !aiMeaning.isEmpty && isClose(aiMeaning, to: meaningReadings(d), ratio: 0.75)
        let s = Suggestion(term: termOK ? aiTerm : d.term, pos: d.pos, meaning: meaningOK ? aiMeaning : d.meaning, source: .ai)
        return (termOK || meaningOK) && s.differs(from: d) ? s : nil
    }

    /// Các cách viết của từ trong một dòng quét: chữ chính và từ trong các cách đọc khác.
    static func termReadings(_ d: Draft) -> [String] {
        [d.term] + d.readings.compactMap { OCR.parse([(text: $0, x: 0)]).first?.term }
    }

    static func meaningReadings(_ d: Draft) -> [String] {
        [d.meaning] + d.readings.compactMap { OCR.parse([(text: $0, x: 0)]).first?.meaning }
    }

    /// Máy có AI của Apple (iOS 26+, Apple Intelligence đang bật và đã tải xong mô hình).
    static var aiAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    /// Nạp sẵn mô hình khi mở màn quét, để lúc chụp xong AI trả lời nhanh hơn.
    @MainActor static func prewarm() {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), aiAvailable { PageFixer.prewarm() }
        #endif
    }

    /// Gửi cả trang cho AI trên máy sửa một lần (có ngữ cảnh chung nên sửa tốt hơn từng dòng). Trả về gợi ý theo id dòng.
    @MainActor static func ai(_ drafts: [Draft]) async -> [UUID: Suggestion] {
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
@MainActor private enum PageFixer {
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
        - Một số dòng kèm các cách máy đọc khác cho dòng đó; dùng chúng để đoán chữ đúng.
        - Không đổi sang từ khác. Không viết lại nghĩa bằng từ khác.
        """

    private static var warm: LanguageModelSession?

    static func prewarm() {
        guard warm == nil else { return }
        warm = LanguageModelSession(instructions: instructions)
        warm?.prewarm()
    }

    static func line(_ i: Int, _ d: Draft) -> String {
        // Không gửi kèm từ TOEIC gần giống: thử rồi, AI thay cả cụm bằng từ đó ("refund policy" → "refund"), đúng còn 3–5/15.
        let others = d.readings.map { "«\($0)»" }.joined(separator: "; ")
        return "\(i + 1). \(d.term): \(d.meaning)" + (others.isEmpty ? "" : " (máy còn đọc ra: \(others))")
    }

    static func fix(_ drafts: [Draft]) async -> [UUID: Suggestion] {
        let prompt = drafts.enumerated().map { line($0.offset, $0.element) }.joined(separator: "\n")
        let session = warm ?? LanguageModelSession(instructions: instructions)
        warm = nil  // mỗi phiên chỉ dùng 1 lần, không mang ngữ cảnh trang trước
        // greedy: cùng một trang luôn ra cùng gợi ý (mặc định có ngẫu nhiên, đúng 7–11/15 tuỳ lần)
        ScanLog.write("Gửi AI:\n" + prompt)
        let start = Date.now
        guard let page = try? await session.respond(to: prompt, generating: Page.self, options: GenerationOptions(sampling: .greedy))
        else { ScanLog.write("AI lỗi hoặc không trả lời"); return [:] }
        var out: [UUID: Suggestion] = [:]
        var log: [String] = []
        for f in page.content.fixes where drafts.indices.contains(f.line - 1) {
            let d = drafts[f.line - 1]
            let s = VocabSuggester.accept(term: f.term, meaning: f.meaning, for: d)
            out[d.id] = s
            log.append("\(f.line). \(d.term) → \(f.term): \(f.meaning)  [\(s == nil ? "BỎ" : "nhận")]")
        }
        ScanLog.write(String(format: "AI trả lời sau %.1fs:\n", Date.now.timeIntervalSince(start)) + log.joined(separator: "\n"))
        return out
    }
}
#endif

extension Suggestion {
    func differs(from d: Draft) -> Bool {
        // nghĩa so cả dấu: sửa "trưc" → "trực" cũng là gợi ý có ích
        Answer.normalize(term) != Answer.normalize(d.term) || folded(meaning) != folded(d.meaning)
    }

    private func folded(_ s: String) -> String {
        s.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
