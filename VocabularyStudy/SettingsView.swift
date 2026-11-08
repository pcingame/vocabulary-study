import SwiftUI
import UserNotifications

/// Key và giá trị mặc định của các cài đặt (lưu trong UserDefaults / @AppStorage).
enum Settings {
    static let newPerDayKey = "newPerDay", defaultNewPerDay = 15
    static let reviewPerDayKey = "reviewPerDay", defaultReviewPerDay = 40
    static let roadmapAutoKey = "roadmapAuto"
    static let voiceKey = "voice", defaultVoice = "en-US"
    static let speechRateKey = "speechRate", defaultSpeechRate = 0.5

    private static func value<T>(_ key: String, _ fallback: T) -> T { UserDefaults.standard.object(forKey: key) as? T ?? fallback }
    static var newPerDay: Int { value(newPerDayKey, defaultNewPerDay) }
    static var reviewPerDay: Int { value(reviewPerDayKey, defaultReviewPerDay) }
    static var voice: String { value(voiceKey, defaultVoice) }
    static var speechRate: Double { value(speechRateKey, defaultSpeechRate) }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Settings.newPerDayKey) private var newPerDay = Settings.defaultNewPerDay
    @AppStorage(Settings.reviewPerDayKey) private var reviewPerDay = Settings.defaultReviewPerDay
    @AppStorage("reminderMinutes") private var reminderMinutes = Reminder.defaultMinutes
    @AppStorage(Settings.roadmapAutoKey) private var roadmapAuto = true
    @AppStorage(Settings.voiceKey) private var voice = Settings.defaultVoice
    @AppStorage(Settings.speechRateKey) private var speechRate = Settings.defaultSpeechRate
    @State private var notificationStatus = UNAuthorizationStatus.authorized

    var body: some View {
        NavigationStack {
            Form {
                Section("Mỗi ngày") {
                    Stepper("Từ mới: \(newPerDay)", value: $newPerDay, in: 5...30)
                        .accessibilityIdentifier("newPerDayStepper")
                    Stepper("Từ ôn tối đa: \(reviewPerDay)", value: $reviewPerDay, in: 10...100, step: 5)
                        .accessibilityIdentifier("reviewPerDayStepper")
                }
                Section {
                    DatePicker("Giờ nhắc học", selection: Reminder.time($reminderMinutes), displayedComponents: .hourAndMinute)
                    if notificationStatus != .authorized {
                        Button("Bật thông báo") {
                            Task {
                                if notificationStatus == .notDetermined {
                                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                                    await Reminder.schedule()
                                    notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                                } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                    await UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                }
                Section {
                    Toggle("Tự thêm bộ từ của chặng", isOn: $roadmapAuto)
                } header: {
                    Text("Lộ trình TOEIC")
                } footer: {
                    Text("Tắt nếu chỉ muốn học từ của bạn (ví dụ từ trong sách).")
                }
                Section("Phát âm") {
                    Picker("Giọng đọc", selection: $voice) {
                        Text("Anh – Mỹ").tag("en-US")
                        Text("Anh – Anh").tag("en-GB")
                    }
                    VStack(alignment: .leading) {
                        Text("Tốc độ đọc")
                        Slider(value: $speechRate, in: 0.3...0.55) {
                            Text("Tốc độ đọc")
                        } minimumValueLabel: {
                            Image(systemName: "tortoise")
                        } maximumValueLabel: {
                            Image(systemName: "hare")
                        }
                    }
                    Button("Nghe thử", systemImage: "speaker.wave.2") {
                        Speaker.say("Welcome to your TOEIC vocabulary practice.")
                    }
                }
            }
            .navigationTitle("Cài đặt")
            .toolbar { Button("Xong") { dismiss() }.accessibilityIdentifier("settingsDone") }
            .task {
                notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            }
        }
    }
}
