import Foundation

/// Bản Debug: ghi chữ Vision đọc được và câu trả lời gốc của AI vào Documents/scan-log.txt,
/// để chỉnh bộ lọc gợi ý theo dữ liệu quét thật. Bản Release không ghi gì.
enum ScanLog {
    static let url = URL.documentsDirectory.appending(path: "scan-log.txt")

    static func write(_ text: String) {
        #if DEBUG
        let data = Data("[\(Date.now.formatted(date: .numeric, time: .standard))] \(text)\n".utf8)
        if let h = try? FileHandle(forWritingTo: url) {
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: data)
            try? h.close()
        } else {
            try? data.write(to: url)
        }
        #endif
    }
}
