import SwiftUI
import UserNotifications

/// Màn giới thiệu lần đầu: chọn số từ mới, giờ nhắc, rồi mới xin quyền thông báo.
struct OnboardingView: View {
    @AppStorage("onboarded") private var onboarded = false
    @AppStorage(Settings.newPerDayKey) private var newPerDay = Settings.defaultNewPerDay
    @AppStorage("reminderMinutes") private var reminderMinutes = Reminder.defaultMinutes
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            step(icon: "flame.fill", title: "Học từ vựng TOEIC",
                 text: "Học theo lộ trình, mỗi ngày khoảng 10 phút. App tự xếp lịch ôn để bạn nhớ lâu.") {
                Button("Tiếp tục") { page = 1 }.accessibilityIdentifier("onboardingNext1")
            }
            .tag(0)
            step(icon: "square.stack.3d.up.fill", title: "Mỗi ngày bao nhiêu từ mới?",
                 text: "Có thể đổi sau trong Cài đặt.") {
                Picker("Từ mới mỗi ngày", selection: $newPerDay) {
                    ForEach([10, 15, 20], id: \.self) { Text("\($0) từ").tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("onboardingNewPerDay")
                Button("Tiếp tục") { page = 2 }.accessibilityIdentifier("onboardingNext2")
            }
            .tag(1)
            step(icon: "bell.badge.fill", title: "Nhắc học mỗi ngày",
                 text: "Học đều mỗi ngày mới giữ được chuỗi. App chỉ nhắc 1 lần/ngày, và không nhắc nếu hôm đó bạn đã học.") {
                DatePicker("Giờ nhắc học", selection: Reminder.time($reminderMinutes), displayedComponents: .hourAndMinute)
                Button("Bật nhắc học") {
                    Task {
                        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                        await Reminder.schedule()
                        onboarded = true
                    }
                }
                .accessibilityIdentifier("onboardingEnableReminders")
                Button("Để sau") { onboarded = true }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("onboardingLater")
            }
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private func step(icon: String, title: String, text: String, @ViewBuilder actions: () -> some View) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon).font(.system(size: 64)).foregroundStyle(.tint)
            Text(title).font(.title.bold()).multilineTextAlignment(.center)
            Text(text).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
            actions()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(32)
        .padding(.bottom, 40)
    }
}
