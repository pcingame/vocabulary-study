import Foundation

/// Key và giá trị mặc định của các cài đặt (lưu trong UserDefaults / @AppStorage).
enum Settings {
    static let newPerDayKey = "newPerDay", defaultNewPerDay = 15
    static let reviewPerDayKey = "reviewPerDay", defaultReviewPerDay = 40
    static let maxNewPerDay = 30, maxReviewPerDay = 100
    static let roadmapAutoKey = "roadmapAuto", defaultRoadmapAuto = true
    static let reminderMinutesKey = "reminderMinutes", defaultReminderMinutes = 20 * 60
    static let studyModeKey = "studyMode"
    static let appearanceKey = "appearance"
    // Trạng thái app (không hiện trong màn Cài đặt).
    static let onboardedKey = "onboarded"
    static let grammarScoresKey = "grammarScores"
    static let lastSeenStageKey = "lastSeenStage"
    static let streakKey = "streak", lastStudyKey = "lastStudy", streakFreezeKey = "streakFreeze"
    static let voiceKey = "voice", defaultVoice = "en-US"
    static let speechRateKey = "speechRate", defaultSpeechRate = 0.5

    private static func value<T>(_ key: String, _ fallback: T) -> T { UserDefaults.standard.object(forKey: key) as? T ?? fallback }
    static var newPerDay: Int { value(newPerDayKey, defaultNewPerDay) }
    static var reviewPerDay: Int { value(reviewPerDayKey, defaultReviewPerDay) }
    static var voice: String { value(voiceKey, defaultVoice) }
    static var speechRate: Double { value(speechRateKey, defaultSpeechRate) }
    static var reminderMinutes: Int { value(reminderMinutesKey, defaultReminderMinutes) }
}
