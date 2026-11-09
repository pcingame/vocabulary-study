import Foundation
import SwiftData
import Testing
@testable import VocabularyStudy

/// Dòng OCR thật từ ảnh sách trong `requirement/`.
@Test func parseBookPage() {
    let lines: [(text: String, x: Double)] = [
        ("Tính từ (Adjectives)", 0.26),
        ("generous / dseneras/ (adj) - hào phóng", 0.24),
        ("kind-hearted/, katnd ha:rtd/", 0.23),
        ("(adj) - tốt bụng", 0.23),
        ("understanding /, andar 'staendy", 0.56),
        ("compassionate/kam pa/anat/", 0.23),
        ("(adj) - nhân ái, trắc ẩn", 0.23),
        ("(ad]) - thấu hiều", 0.56),
        ("fair /fcr/ (adi) công bằng", 0.55),
        ("sincere Istn str (ad))", 0.19),
        ("LÒNG TỐT", 0.23),
    ]
    #expect(OCR.parse(lines) == [
        Draft(term: "generous", pos: "adj", meaning: "hào phóng"),
        Draft(term: "kind-hearted", pos: "adj", meaning: "tốt bụng"),
        Draft(term: "understanding", pos: "adj", meaning: "thấu hiều"),
        Draft(term: "compassionate", pos: "adj", meaning: "nhân ái, trắc ẩn"),
        Draft(term: "fair", pos: "adj", meaning: "công bằng"),
    ])
}

@Test func scanDedupesAgainstTopic() {
    let found = [Draft(term: "Kind", pos: "adj", meaning: "tử tế"),
                 Draft(term: "fair", pos: "adj", meaning: "công bằng"),
                 Draft(term: "FAIR ", pos: "adj", meaning: "công bằng")]
    let (kept, skipped) = Draft.dedupe(found, existing: ["kind"])
    #expect(kept.map(\.term) == ["fair"] && skipped == 2)
}

@Test func scanEnrichesFromContent() {
    let w = Draft(term: "Agenda ", pos: "n", meaning: "chương trình họp").makeWord(createdAt: .now)
    #expect(w.term == "Agenda" && w.meaning == "chương trình họp")  // giữ nghĩa trong sách
    #expect(w.ipa == "/əˈdʒɛndə/" && w.example.contains("agenda") && !w.exampleMeaning.isEmpty)
    #expect(Draft(term: "zzz", pos: "", meaning: "x").makeWord(createdAt: .now).ipa.isEmpty)
}

@Test func downscaleKeepsAspect() {
    #expect(OCR.downscaledSize(CGSize(width: 8000, height: 6000)) == CGSize(width: 3000, height: 2250))
    #expect(OCR.downscaledSize(CGSize(width: 1200, height: 1600)) == CGSize(width: 1200, height: 1600))
}

/// Dòng Vision đọc thật từ trang sổ chép tay (photo_2026-11-09 19.54.54).
@Test func parseHandwrittenNotes() {
    let lines = ["shift", "Thứ", "ngày",
        "- repre sentative (a): đai diện",
        "- promotion (m) : Sự thăng chứa.",
        "= appre ciate (v): đánh giá",
        "- re im bur sement (m) : hoàn tra",
        "- eli gible ex pem ses (n): các hooi chi phí đượ hà hn",
        "- transpor tation (M) : chi phủ đi bải",
        "- accom modations (m) : chỗ ở",
        "- en vinam mentab regu la tioms (n) : quay đinh về môi ning",
        "- repund policy (n) : chinh sách hoàn trả",
        "- busimess - nelated costs: chi pheo hien quan đếu công vi",
        "- be direct ly relatid to: lien quan trưc tiếp",
        "- Proop of payment (m): dang từ theanh toar.",
        "- chaim reimbusse ment (a: yeu cầu loàn tẻ",
        "- Exceding : vượt quó",
        "eligible fon : đủ điều hiệm"].map { (text: $0, x: 0.1) }
    let drafts = OCR.parse(lines)
    #expect(drafts.count == 15)
    #expect(drafts[1] == Draft(term: "promotion", pos: "n", meaning: "Sự thăng chứa"))
    #expect(drafts[2] == Draft(term: "appre ciate", pos: "v", meaning: "đánh giá"))
    #expect(drafts[9] == Draft(term: "busimess - nelated costs", pos: "", meaning: "chi pheo hien quan đếu công vi"))
    #expect(drafts[12] == Draft(term: "chaim reimbusse ment", pos: "a", meaning: "yeu cầu loàn tẻ"))
    #expect(drafts[14] == Draft(term: "eligible fon", pos: "", meaning: "đủ điều hiệm"))
}

@Test func deckSuggestsCloseWord() {
    let s = VocabSuggester.fromDeck(Draft(term: "accom modations", pos: "m", meaning: "chỗ ở"))
    #expect(s?.term == "accommodation" && s?.pos == "n" && s?.source == .deck)
    #expect(VocabSuggester.fromDeck(Draft(term: "promotion", pos: "n", meaning: "Sự thăng chứa"))?.meaning == "sự thăng chức")
    #expect(VocabSuggester.fromDeck(Draft(term: "re im bur sement", pos: "n", meaning: "hoàn tra")) == nil)  // không ép về "reimburse"
    #expect(VocabSuggester.fromDeck(Draft(term: "accommodation", pos: "n", meaning: "chỗ ở")) == nil)  // đã đúng
}

@MainActor @Test func spellingJoinsAndFixes() {
    #expect(VocabSuggester.spelling(Draft(term: "repre sentative", pos: "n", meaning: ""))?.term == "representative")
    #expect(VocabSuggester.spelling(Draft(term: "Exceding", pos: "", meaning: ""))?.term == "exceeding")
    #expect(VocabSuggester.spelling(Draft(term: "busimess - nelated costs", pos: "", meaning: "")) == nil)
    #expect(VocabSuggester.spelling(Draft(term: "promotion", pos: "n", meaning: "")) == nil)
}

@Test func applySuggestionKeepsPosWhenMissing() {
    var d = Draft(term: "Exceding", pos: "v", meaning: "vượt quó")
    d.suggestion = Suggestion(term: "exceeding", pos: "", meaning: "vượt quá", source: .ai)
    d.apply(d.suggestion!)
    #expect(d == Draft(term: "exceeding", pos: "v", meaning: "vượt quá") && d.suggestion == nil)
}

@Test func attachReadingsFromSameLine() {
    let drafts = [Draft(term: "Proop of payment", pos: "n", meaning: "dang từ theanh toar")]
    let lines = [(text: "- Exceding : vượt quó", others: ["- Exceding : vượt quá"]),
                 (text: "- Proop of payment (m): dang từ theanh toar.", others: ["- Proof of payment (m): dang từ theanh toar."])]
    let out = OCR.attachReadings(drafts, lines: lines)
    #expect(out[0].readings == ["- Proof of payment (m): dang từ theanh toar."])
    #expect(VocabSuggester.termReadings(out[0]) == ["Proop of payment", "Proof of payment"])
}

/// Gợi ý AI phải còn giống chữ đọc được: sửa lỗi đọc thì nhận, đổi sang từ khác hẳn thì bỏ.
@Test func aiSuggestionMustStayClose() {
    #expect(VocabSuggester.isClose("refund policy", to: ["repund policy"]))
    #expect(VocabSuggester.isClose("environmental regulations", to: ["en vinam mentab regu la tioms"]))
    #expect(VocabSuggester.isClose("reimbursement", to: ["re im bur sement"]))
    #expect(VocabSuggester.isClose("business-related costs", to: ["busimess - nelated costs"]))
    #expect(!VocabSuggester.isClose("customer service", to: ["repund policy"]))
    #expect(!VocabSuggester.isClose("remittance", to: ["re im bur sement"]))
    // Câu trả lời sai thật của AI trên trang sổ mẫu
    #expect(!VocabSuggester.isClose("repayment policy", to: ["repund policy"]))
    #expect(!VocabSuggester.isClose("related costs", to: ["busimess - nelated costs"]))
    #expect(!VocabSuggester.isClose("reimbursement request", to: ["chaim reimbusse ment"]))
    // Cách đọc thứ 2 của Vision giúp nhận "proof"
    #expect(VocabSuggester.isClose("proof of payment", to: ["Proop of payment", "Proof of payment"]))
}
