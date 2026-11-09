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
