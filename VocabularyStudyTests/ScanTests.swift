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
