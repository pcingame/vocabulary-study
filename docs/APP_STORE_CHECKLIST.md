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

## 1. Tài khoản & bản ghi app

- [x] Apple Developer Program Active (Team `P3MPHWPJ62`, dùng chung với Hangul Study)
- [ ] Certificates, Identifiers & Profiles ▸ Identifiers: đăng ký Bundle ID `com.doanthanhphuong.VocabularyStudy` (có thể Xcode đã tự tạo khi build lên máy thật — kiểm tra trước)
- [ ] App Store Connect ▸ My Apps ▸ **+ New App**:
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

- [ ] **Tên** (≤ 30 ký tự, phải duy nhất), ví dụ: `Mầm – Từ vựng & Ngữ pháp`
- [ ] **Subtitle** (≤ 30): ví dụ `Luyện thi TOEIC mỗi ngày`
- [ ] **Category**: Education (phụ: Reference)
- [ ] **Description**: lộ trình 10 chặng, lặp lại ngắt quãng, 4 chế độ học (lật thẻ / gõ từ / nghe – gõ / chọn nghĩa), 16 bộ từ (320 từ), 13 bài ngữ pháp (312 câu), quét sổ tay/sách, streak, nhắc học, sáng/tối
- [ ] **Keywords** (≤ 100 ký tự), ví dụ: `toeic,từ vựng,tiếng anh,ngữ pháp,flashcard,học từ,ôn thi,english,vocabulary`
- [ ] **Ghi chú nhãn hiệu**: TOEIC là nhãn hiệu của ETS. Không để "TOEIC" làm tên chính; nếu nhắc trong mô tả thì thêm dòng *"TOEIC is a registered trademark of ETS. This app is not endorsed or approved by ETS."* (tránh bị từ chối theo Guideline 5.2.1)
- [ ] Privacy Policy URL, Support URL, Marketing URL (từ mục 3)
- [ ] Copyright: `2026 Phuong Doan Thanh`

### Screenshots (bắt buộc)
- [ ] iPhone 6.9" — chụp trên Simulator **iPhone 17 Pro Max** (1320×2868), 3–10 ảnh: Hôm nay, lật thẻ, chọn nghĩa, lộ trình, ngữ pháp, quét ảnh, thống kê; có cả bản tối
- [ ] Seed dữ liệu cho đẹp (launch argument `-seed` đang dùng cho UI test là điểm bắt đầu)
- [ ] Không cần ảnh iPad (đã tắt iPad)

## 5. App Privacy (nhãn dinh dưỡng)

- [ ] Data Collection: **"No, we do not collect data from this app"** → Publish
  (không mạng, ảnh quét xử lý bằng Vision/FoundationModels ngay trên máy, dữ liệu học lưu bằng SwiftData/UserDefaults)

## 6. Age rating

- [ ] Tất cả None / No → **4+**

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

- [ ] Xcode: destination **Any iOS Device (arm64)** ▸ Product ▸ **Archive**
- [ ] Organizer ▸ **Validate App** → không lỗi
- [ ] **Distribute App ▸ App Store Connect ▸ Upload**
- [ ] (Tuỳ chọn) TestFlight nội bộ cài thử trước khi nộp review

## 9. Submit for Review

- [ ] Gán build vào version 1.0
- [ ] App Review Information: không cần đăng nhập; liên hệ như Hangul Study
- [ ] Notes cho reviewer (gợi ý):
  > Ứng dụng học từ vựng và ngữ pháp tiếng Anh, không cần tài khoản, không kết nối mạng; dữ liệu lưu trên máy. Tính năng "Quét ảnh sách" dùng camera hoặc ảnh có sẵn, đọc chữ bằng Vision ngay trên máy; gợi ý sửa chữ bằng AI chỉ có trên iOS 26 với Apple Intelligence, máy khác vẫn dùng được mà không có gợi ý. Nhắc học là thông báo cục bộ.
- [ ] Chuẩn bị sẵn câu trả lời cho **Guideline 2.1 — Information Needed** (Hangul Study đã bị hỏi, xem mục 11.1 bên korea_study): mục đích/đối tượng, cách dùng, không có dịch vụ ngoài, giống nhau ở mọi khu vực, không dùng nội dung bên thứ ba được bảo hộ (bộ từ và câu hỏi tự soạn) + **video quay trên máy thật** (< 10 MB)
- [ ] Add for Review → Submit

## 10. Sau khi duyệt

- [ ] Kiểm tra app trên App Store
- [ ] `git tag v1.0 && git push --tags`
