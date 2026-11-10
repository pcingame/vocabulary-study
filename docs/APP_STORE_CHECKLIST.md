# Checklist đưa Mầm lên App Store

Làm theo khung của `korea_study/docs/APP_STORE_CHECKLIST.md` (Hangul Study đã nộp thành công), chỉnh cho app này.

| Mục | Giá trị |
|---|---|
| Tên hiển thị | `Mầm` |
| Bundle ID | `com.doanthanhphuong.VocabularyStudy` |
| Team ID | `P3MPHWPJ62` (Automatic signing) |
| Version / Build | `1.0` (1) — trong `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) |
| Deployment target | iOS 18.0 (AI gợi ý khi quét ảnh chỉ chạy từ iOS 26, máy cũ vẫn mở app được) |
| Thiết bị | Chỉ iPhone (`TARGETED_DEVICE_FAMILY: "1"`) |
| Frameworks | SwiftUI, SwiftData, Charts, AVFoundation (đọc), UserNotifications (nhắc học, local), Vision (đọc chữ trong ảnh, trên máy), FoundationModels (AI trên máy), PhotosUI. **Không SDK bên thứ ba, không mạng, không tài khoản, không tracking.** |
| Quyền | Camera (`NSCameraUsageDescription`: "Chụp trang sách để lấy từ vựng."), Thông báo. Chọn ảnh dùng `PhotosPicker` nên không cần quyền thư viện ảnh. |

---

## Trạng thái (cập nhật 2026-11-09)

- ✅ **Đã gửi review** ngày 2026-11-09, phiên bản 1.0 (build 1).
- ⏳ 2026-11-10: Apple hỏi **Guideline 2.1 — Information Needed** → làm theo mục 9.1.
- Nếu Apple hỏi thêm (**Guideline 2.1 — Information Needed**, Hangul Study từng bị): xem mục 9, chuẩn bị video quay trên máy thật < 10 MB.
- Mục 7 (kiểm thử trước khi nộp) **chưa làm đủ** — làm trước khi nộp bản cập nhật tiếp theo, hoặc ngay nếu bị từ chối.
- Còn trống: tên app và Apple ID ở mục 1.

## 1. Tài khoản & bản ghi app

- [x] Apple Developer Program Active (Team `P3MPHWPJ62`, dùng chung với Hangul Study)
- [x] Certificates, Identifiers & Profiles ▸ Identifiers: đăng ký Bundle ID `com.doanthanhphuong.VocabularyStudy` (có thể Xcode đã tự tạo khi build lên máy thật — kiểm tra trước)
- [x] App Store Connect ▸ My Apps ▸ **+ New App** (tên đã chọn và Apple ID: _chưa ghi — điền vào đây_):
  - Platform: iOS · Primary language: Vietnamese
  - Name: xem mục 6 (tên `Mầm` có thể đã có người dùng — App Store bắt tên duy nhất)
  - Bundle ID: như trên · SKU: `mam-001`

## 2. Cấu hình dự án (đã làm trong repo)

- [x] Tên hiển thị `Mầm`
- [x] `PrivacyInfo.xcprivacy` (khai `UserDefaults` lý do `CA92.1`, không tracking, không thu thập dữ liệu) — đã xác minh có trong `.app` bản Release
- [x] `ITSAppUsesNonExemptEncryption = NO` — Info.plist bản Release có `false`
- [x] Chỉ iPhone — hết cảnh báo "All interface orientations must be supported"
- [x] Icon 1024 sáng/tối/tinted, không alpha (`sips -g hasAlpha` → `no`)
- [x] Nhật ký quét ảnh `scan-log.txt` chỉ có trong bản Debug (không có trong binary Release)
- [x] Build Release sạch:
  ```bash
  xcodebuild build -scheme VocabularyStudy -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath build/release -allowProvisioningUpdates
  ```
- [ ] Mỗi lần upload build mới cho cùng version: tăng `CURRENT_PROJECT_VERSION` trong `project.yml` rồi `xcodegen generate`

## 3. Trang Privacy / Support (GitHub Pages)

Web nằm ở repo riêng **`pcingame/vocabulary-study-web`** (để repo code giữ private), thư mục local `../vocabulary-study-web`: `index.html`, `privacy.html`, `support.html`, `style.css`, `icon.png`. Song ngữ VI/EN, màu mint, tự theo sáng/tối.

- [x] Đẩy repo app lên GitHub: `pcingame/vocabulary-study`
- [x] Tạo và push 3 trang lên `pcingame/vocabulary-study-web`
- [x] Repo web để **public**, bật GitHub Pages: Settings ▸ Pages ▸ Source "Deploy from a branch" ▸ Branch `main`, thư mục `/ (root)` ▸ Save
- [x] Kiểm tra 3 URL trả `200 OK` (2026-11-09):
  - Marketing URL → `https://pcingame.github.io/vocabulary-study-web/`
  - Privacy Policy URL → `https://pcingame.github.io/vocabulary-study-web/privacy.html`
  - Support URL → `https://pcingame.github.io/vocabulary-study-web/support.html`

## 4. Metadata App Store Connect

Nội dung soạn sẵn để dán: `docs/APP_STORE_METADATA.md` (Promotional Text, Description, Keywords, URL).

- [ ] **Tên** (≤ 30 ký tự, phải duy nhất), ví dụ: `Mầm – Từ vựng & Ngữ pháp`
- [ ] **Subtitle** (≤ 30): ví dụ `Luyện thi TOEIC mỗi ngày`
- [ ] **Category**: Education (phụ: Reference)
- [x] **Description** (2519/4000, soạn sẵn trong `APP_STORE_METADATA.md`): lộ trình 10 chặng, lặp lại ngắt quãng, 4 chế độ học (lật thẻ / gõ từ / nghe – gõ / chọn nghĩa), 16 bộ từ (320 từ), 13 bài ngữ pháp (312 câu), quét sổ tay/sách, streak, nhắc học, sáng/tối
- [x] **Keywords** (93/100): `toeic,từ vựng,tiếng anh,ngữ pháp,flashcard,học từ,ôn thi,vocabulary,english,grammar,luyện thi`
- [x] **Promotional Text** (149/170): soạn sẵn trong `APP_STORE_METADATA.md`
- [x] **Ghi chú nhãn hiệu** (đã có ở cuối Description): TOEIC là nhãn hiệu của ETS. Không để "TOEIC" làm tên chính; nếu nhắc trong mô tả thì thêm dòng *"TOEIC is a registered trademark of ETS. This app is not endorsed or approved by ETS."* (tránh bị từ chối theo Guideline 5.2.1)
- [x] Support URL, Marketing URL: soạn sẵn trong `APP_STORE_METADATA.md`
- [x] Privacy Policy URL: điền ở **App Privacy ▸ Edit** → `https://pcingame.github.io/vocabulary-study-web/privacy.html`
- [ ] Copyright: `2026 Phuong Doan Thanh`

### Screenshots (bắt buộc)
- [x] 10 ảnh mỗi cỡ (Hôm nay, lật thẻ, chọn nghĩa, gõ từ, lộ trình, chủ đề, bài Thì, bài tập, thống kê, Hôm nay bản tối):
  - **iPhone 6.9" (bắt buộc)** 1320×2868 → `docs/screenshots/6.9/` (Simulator iPhone 17 Pro Max `63E9258D-E487-466D-9DE4-999AEC894C42`)
  - iPhone 6.3" 1206×2622 → `docs/screenshots/6.3/` (Simulator `8D060894-CC2B-4CE2-A4A6-52F02EB42E44`). Không bắt buộc: thiếu thì Apple tự thu nhỏ từ bản 6.9"
- Chụp lại (thay `<SIM>` và `<DIR>`):
  ```bash
  xcrun simctl status_bar <SIM> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
  TEST_RUNNER_SNAPSHOT_DIR=<DIR> xcodebuild test -scheme VocabularyStudy -destination id=<SIM> \
    -only-testing:VocabularyStudyUITests/VocabularyStudyUITests/testAppStoreScreenshots
  ```
  (cờ `-screenshots` tạo dữ liệu mẫu: qua chặng 1, đang học chặng 2, chuỗi 12 ngày, 2 tuần lịch sử)
- [x] Upload lên App Store Connect: ô **6.9" bắt buộc** chỉ nhận 1320×2868 → dùng `docs/screenshots/6.9/` (ảnh 6.3" thả vào ô 6.9" sẽ báo "File dimensions are invalid")
- [x] Không cần ảnh iPad (đã tắt iPad)

## 5. App Privacy (nhãn dinh dưỡng)

- [x] Data Collection: **"No, we do not collect data from this app"** → Publish
  (không mạng, ảnh quét xử lý bằng Vision/FoundationModels ngay trên máy, dữ liệu học lưu bằng SwiftData/UserDefaults)

## 6. Age rating

- [x] Tất cả None / No → **4+**

## 7. Kiểm thử trước khi nộp

- [ ] Chạy **toàn bộ** test 1 lần (bình thường chỉ chạy phần liên quan, trước khi nộp thì chạy hết):
  ```bash
  xcodebuild test -scheme VocabularyStudy -destination id=8D060894-CC2B-4CE2-A4A6-52F02EB42E44
  ```
- [ ] Chạy bản **Release** trên iPhone thật (Product ▸ Scheme ▸ Run dùng Release, hoặc cài bản TestFlight)
- [ ] Cài mới (xoá app trước) → onboarding → học 1 buổi → kill app mở lại vẫn còn tiến độ
- [ ] Từ chối quyền camera / thông báo → app không crash, vẫn chọn ảnh từ thư viện được
- [ ] Quét ảnh trên máy **không có** Apple Intelligence (hoặc tắt) → vẫn ra kết quả, chỉ thiếu gợi ý AI
- [ ] Sáng / Tối / Hệ thống; chữ cỡ lớn nhất; iPhone nhỏ (SE)
- [ ] Các mục "Test tay" còn trống trong `PLAN.md`

## 8. Archive & upload

- [x] Archive bản Release 1.0 (1). Lệnh dòng lệnh: `xcodebuild archive -scheme VocabularyStudy -configuration Release -destination 'generic/platform=iOS' -archivePath build/Mam.xcarchive -allowProvisioningUpdates`, rồi `open build/Mam.xcarchive` để mở Organizer (export bằng `xcodebuild -exportArchive` báo "No Accounts" vì terminal không dùng được tài khoản Apple trong Xcode → phải Distribute trong Organizer)
- [ ] Organizer ▸ **Validate App** → không lỗi
- [x] **Distribute App ▸ App Store Connect ▸ Upload**
- [ ] (Tuỳ chọn) TestFlight nội bộ cài thử trước khi nộp review

## 9. Submit for Review

- [x] Gán build vào version 1.0
- [ ] App Review Information: không cần đăng nhập; liên hệ như Hangul Study
- [ ] Notes cho reviewer (gợi ý):
  > Ứng dụng học từ vựng và ngữ pháp tiếng Anh, không cần tài khoản, không kết nối mạng; dữ liệu lưu trên máy. Tính năng "Quét ảnh sách" dùng camera hoặc ảnh có sẵn, đọc chữ bằng Vision ngay trên máy; gợi ý sửa chữ bằng AI chỉ có trên iOS 26 với Apple Intelligence, máy khác vẫn dùng được mà không có gợi ý. Nhắc học là thông báo cục bộ.
- [ ] Chuẩn bị sẵn câu trả lời cho **Guideline 2.1 — Information Needed** (Hangul Study đã bị hỏi, xem mục 11.1 bên korea_study): mục đích/đối tượng, cách dùng, không có dịch vụ ngoài, giống nhau ở mọi khu vực, không dùng nội dung bên thứ ba được bảo hộ (bộ từ và câu hỏi tự soạn) + **video quay trên máy thật** (< 10 MB)
- [x] Add for Review → Submit (2026-11-09)

### 9.1 Guideline 2.1 — Information Needed (nhận 2026-11-10)

- [ ] Quay màn hình trên **iPhone thật** (iOS mới nhất): bắt đầu từ lúc mở app ở màn hình chính → onboarding → Hôm nay ▸ Bắt đầu học (lật thẻ, chọn Quên/Khó/Dễ, các chế độ gõ / nghe / chọn nghĩa) → lộ trình → tab Ngữ pháp (bài giảng + bài tập) → tab Chủ đề ▸ Quét ảnh sách → thống kê / cài đặt nhắc học. Không có tài khoản, UGC hay nội dung trả phí nên không cần quay mấy phần đó.
- [ ] Nén video < 10 MB: `ffmpeg -i in.MP4 -vf "scale=-2:1280" -c:v libx264 -crf 30 -preset slow -an mam-demo.mp4`
- [ ] App Store Connect ▸ Mầm ▸ App Review ▸ mở submission ▸ **Reply to App Review**: dán nội dung dưới + đính kèm video
- [ ] Dán cùng nội dung vào ô **Notes** của App Review Information (nối sau ghi chú cũ)

```
Hello App Review team,

Thank you for reviewing Mầm. A screen recording captured on a physical iPhone running the latest iOS is attached. It starts from launching the app and shows the typical flow. The app has no account registration or login, no user-generated content shared with others, and no paid content or in-app purchases.

1. Screen recording
Attached to this reply.

2. Purpose and target audience
Mầm helps Vietnamese-speaking learners study English vocabulary and grammar for the TOEIC exam in short daily sessions of about 10 minutes. The target audience is students and working adults in Vietnam preparing for TOEIC. The app solves two common problems: not knowing what to study next, and forgetting words soon after learning them. It provides a 10-stage roadmap (16 topic decks with 320 words, 13 grammar lessons with 312 practice questions) and spaced repetition that schedules each word for review right before it is likely to be forgotten.

3. How to access the main features
No login, account, or sample files are needed. All content is built into the app.
- On first launch, a short onboarding lets the user choose a daily goal and an optional reminder time.
- "Hôm nay" (Today) tab: tap "Bắt đầu học" (Start learning) to study new words and due reviews. Study modes: flashcards (with audio pronunciation), type the word, listen and type, and multiple choice. The user rates each card Forgot / Hard / Easy to schedule the next review. This tab also shows the roadmap, daily streak, and 30-day statistics.
- "Chủ đề" (Topics) tab: browse the 16 built-in decks, create personal topics, and add words manually. "Quét ảnh sách" (Scan book page) uses the camera or a photo from the library. Text is recognized on-device with the Vision framework, and the user reviews the detected words before saving.
- "Ngữ pháp" (Grammar) tab: short grammar lessons with TOEIC Part 5-style exercises and explanations. Users can retry the questions they answered incorrectly.

4. External services
None. The app makes no network requests and uses no third-party SDKs, analytics, advertising, authentication, payment, or cloud AI services. It uses only Apple frameworks on the device: SwiftUI, SwiftData (local storage), AVFoundation (system text-to-speech for pronunciation), Vision (on-device text recognition), UserNotifications (local daily reminders), PhotosUI, and Charts. On iOS 26 devices with Apple Intelligence, the on-device Foundation Models framework optionally suggests corrections to scanned text. Without Apple Intelligence, scanning works the same but without these suggestions.

5. Regional differences
None. The app works the same in all regions. All content is bundled with the app, and the interface is in Vietnamese.

6. Regulated industry / third-party material
The app does not operate in a regulated industry. All vocabulary lists, example sentences, grammar lessons, and practice questions were written by the developer. The app does not include any official ETS or TOEIC test material. TOEIC is mentioned only to describe the exam the content helps learners prepare for, and the App Store description includes the notice: "TOEIC® is a registered trademark of ETS. This app is not endorsed or approved by ETS."

Best regards,
Phuong Doan Thanh
```

## 10. Sau khi duyệt

- [ ] Kiểm tra app trên App Store
- [ ] `git tag v1.0 && git push --tags`
