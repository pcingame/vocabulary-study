import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Settings.newPerDayKey) private var newPerDay = Settings.defaultNewPerDay
    @AppStorage(Settings.reviewPerDayKey) private var reviewPerDay = Settings.defaultReviewPerDay
    @AppStorage(Settings.reminderMinutesKey) private var reminderMinutes = Settings.defaultReminderMinutes
    @AppStorage(Settings.roadmapAutoKey) private var roadmapAuto = Settings.defaultRoadmapAuto
    @AppStorage(Settings.voiceKey) private var voice = Settings.defaultVoice
    @AppStorage(Settings.speechRateKey) private var speechRate = Settings.defaultSpeechRate
    @State private var notificationStatus = UNAuthorizationStatus.authorized

    var body: some View {
        NavigationStack {
            Form {
                Section("Mỗi ngày") {
                    Stepper("Từ mới: \(newPerDay)", value: $newPerDay, in: 5...Settings.maxNewPerDay)
                        .accessibilityIdentifier("newPerDayStepper")
                    Stepper("Từ ôn tối đa: \(reviewPerDay)", value: $reviewPerDay, in: 10...Settings.maxReviewPerDay, step: 5)
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
                    Text("Tắt nếu chỉ muốn học từ của bạn (ví dụ từ trong sách). Khi đang bật, xoá bộ từ của chặng hiện tại thì app sẽ tự thêm lại bộ đó và tiến độ cũ bị mất.")
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
