import Foundation

enum StudyMode: String, CaseIterable {
    case flip, typing, listening, choice
    var title: String { ["Lật thẻ", "Gõ từ", "Nghe – gõ", "Chọn nghĩa"][Self.allCases.firstIndex(of: self)!] }
}

enum Answer {
    /// Bỏ hoa thường, dấu (é = e, đ = d) và khoảng trắng thừa.
    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "đ", with: "d")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func matches(_ input: String, _ term: String) -> Bool { normalize(input) == normalize(term) }

    /// 4 nghĩa (1 đúng + 3 nhiễu, không trùng), nhiễu ưu tiên lấy từ `pool` (cùng chủ đề) rồi tới `fallback`.
    /// Không đủ 3 nghĩa nhiễu → nil.
    static func choices(for word: Word, pool: [Word], fallback: [Word]) -> [String]? {
        var seen: Set<String> = [normalize(word.meaning)]
        var wrong: [String] = []
        for w in pool.shuffled() + fallback.shuffled() where wrong.count < 3 {
            if seen.insert(normalize(w.meaning)).inserted { wrong.append(w.meaning) }
        }
        return wrong.count == 3 ? (wrong + [word.meaning]).shuffled() : nil
    }
}
