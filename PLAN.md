# PLAN — App học từ vựng TOEIC

Kế hoạch chi tiết, đối chiếu từ `requirement/` và code hiện tại (commit `0387a40`).
Nguyên tắc: **làm đến đâu test đến đó**. Mỗi việc chỉ được tính là xong khi đã qua test tự động và test tay của chính việc đó.

Ký hiệu:
- **P0** = bắt buộc trước khi đưa cho người dùng
- **P1** = nên có
- **P2** = để sau
- Cỡ việc: **S** < 2 giờ · **M** nửa ngày · **L** 1–2 ngày

---

## 0. Quy trình cho mỗi việc

1. Viết code của việc đó (chỉ việc đó, không làm lẫn sang việc khác).
2. Viết hoặc cập nhật test tự động:
   - Logic (tính toán, lịch ôn, tách dữ liệu…) → **unit test** trong `VocabularyStudyTests/`.
   - Luồng màn hình (bấm, nhập, chuyển trang) → **UI test** trong `VocabularyStudyUITests/` (có từ Phase 0).
3. Chạy toàn bộ test, phải xanh hết, không có cảnh báo build mới.
4. Cài lên simulator và chạy hết mục **"Test tay"** của việc đó.
5. Commit, mỗi việc một commit, message ghi mã việc (ví dụ `1.1 Sửa từ`).

### Lệnh dùng thường xuyên

```sh
# Tạo lại project sau khi sửa project.yml hoặc thêm/xoá file
xcodegen generate

# Máy có nhiều simulator trùng tên "iPhone 17 Pro" → chỉ định bằng id (xem: xcrun simctl list devices)
SIM=8D060894-CC2B-4CE2-A4A6-52F02EB42E44

# Toàn bộ test (unit + UI)
xcodebuild test -project VocabularyStudy.xcodeproj -scheme VocabularyStudy \
  -destination "id=$SIM" -derivedDataPath build

# Chỉ unit test (nhanh, chạy liên tục khi đang code)
xcodebuild test ... -only-testing:VocabularyStudyTests

# Cài và mở app (dùng $SIM thay cho "booted" nếu đang bật nhiều simulator)
xcrun simctl install $SIM build/Build/Products/Debug-iphonesimulator/VocabularyStudy.app
xcrun simctl launch $SIM com.doanthanhphuong.VocabularyStudy

# Chụp màn hình trong UI test (các chỗ gọi snapshot("tên")) ra thư mục trên Mac
TEST_RUNNER_SNAPSHOT_DIR=/đường/dẫn xcodebuild test ... -only-testing:VocabularyStudyUITests

# Xoá dữ liệu app trên simulator (thử như lần cài đầu)
xcrun simctl uninstall $SIM com.doanthanhphuong.VocabularyStudy
```

### Định nghĩa "xong" cho mỗi phase

- Tất cả việc trong phase đều đã commit.
- Chạy **Checklist hồi quy** (mục 6) trên simulator, không có lỗi.
- Phase có thay đổi camera hoặc thông báo thì thử thêm trên iPhone thật.

---

## Phase 0 — Hạ tầng test (làm trước tiên)

Hiện app chỉ có unit test. Muốn test luồng màn hình tự động thì cần UI test và cách khởi động app với dữ liệu sạch.

### 0.1 Thêm target UI test · P0 · S ✅
- **File**: `project.yml`, tạo `VocabularyStudyUITests/`.
- **Các bước**:
  1. Thêm target `VocabularyStudyUITests` (`type: bundle.ui-testing`, phụ thuộc app).
  2. Thêm target đó vào `scheme.testTargets`.
  3. Chạy `xcodegen generate`.
- **Test tự động**: `testAppLaunches`, kiểm tra app mở được và thấy đủ 3 tab "Hôm nay", "Chủ đề", "Ngữ pháp".
- **Xong khi**: lệnh test chạy cả unit lẫn UI test, tất cả đều xanh.

### 0.2 Chế độ khởi động cho test · P0 · M ✅
- **File**: `VocabularyStudyApp.swift`, `Models.swift` (`Reminder`).
- **Các bước**: khi app nhận launch argument `-ui-testing`:
  - [x] Dùng `ModelConfiguration(isStoredInMemoryOnly: true)`, để mỗi lần chạy test là dữ liệu sạch.
  - [x] Xoá `UserDefaults` của app (streak, điểm ngữ pháp, cài đặt).
  - [x] Không xin quyền thông báo, không đặt lịch nhắc.
  - [x] Tắt animation (`UIView.setAnimationsEnabled(false)`) cho test nhanh và ổn định.
  - [x] Nếu có thêm argument `-seed`, tạo sẵn 1 chủ đề "Test" gồm 3 từ có đủ IPA, ví dụ, nghĩa.
- **Test tự động**: `testSeedCreatesTopic`, mở app với `-seed`, vào tab Chủ đề, thấy chủ đề "Test · 3 từ".
- **Test tay**:
  - [x] Mở app bình thường (không có argument), thêm 1 chủ đề, tắt hẳn app rồi mở lại: chủ đề vẫn còn. Chế độ test không được ảnh hưởng dữ liệu thật.
- **Xong khi**: UI test chạy trên dữ liệu sạch và không bật hộp thoại xin quyền.

### 0.3 Accessibility identifier cho các nút chính · P0 · S ✅
- **File**: các View.
- **Các bước**: gắn `.accessibilityIdentifier` cho những nút mà UI test cần bấm: `startStudy`, `revealAnswer`, `answerRemember`, `answerForget`, `addTopicMenu`, `addWordMenu`, `flashcardButton`, `settingsButton`.
- **Test tự động**: `testStudyOneCard`:
  1. Mở app với `-seed`.
  2. Bấm "Bắt đầu học" → "Xem nghĩa" → "Nhớ".
  3. Số thẻ còn lại giảm đi 1.
  4. Quay về tab Hôm nay, streak hiện "1 ngày liên tiếp".
- **Xong khi**: test này xanh. Đây là test khung cho các phase sau.

---

## Phase 1 — Bản dùng thử (P0)

Mục tiêu: đưa app cho người dùng thật dùng hằng ngày mà không mất dữ liệu và không bỏ lỡ nhắc học.

### 1.1 Sửa từ · P0 · M ✅
- **Vấn đề**: hiện chỉ thêm hoặc xoá được từ, gõ sai thì không sửa được.
- **File**: `TopicsView.swift`.
- **Các bước**:
  1. Đổi `AddWordView` thành `WordFormView(topic:, word: Word?)`. `word == nil` là thêm mới, ngược lại là sửa.
  2. Chạm vào một dòng từ trong `TopicDetailView` → mở sheet sửa với các ô đã điền sẵn.
  3. Bấm "Lưu" mới cập nhật vào từ. Bấm "Huỷ" thì không đổi gì.
  4. Sửa nội dung từ **không** làm reset tiến độ ôn (`interval`, `due`, `learnedAt`).
- **Test tự động**:
  - [x] Unit `editKeepsSchedule`: tạo từ, trả lời Nhớ 2 lần, đổi nghĩa, kiểm tra `interval == 3` vẫn giữ nguyên.
  - [x] UI `testEditWord`: mở với `-seed` → vào chủ đề → chạm từ đầu tiên → đổi nghĩa thành "nghĩa mới" → Lưu → danh sách hiện "nghĩa mới".
  - [x] UI `testCancelEditKeepsWord`: sửa rồi bấm Huỷ, nghĩa cũ vẫn còn.
- **Test tay**:
  - [ ] Sửa IPA, câu ví dụ, nghĩa câu ví dụ, rồi mở Flashcard xem đã đổi chưa.
  - [x] Xoá trắng ô "Từ" thì nút Lưu bị mờ.

### 1.2 Xác nhận khi xoá chủ đề · P0 · S ✅
- **Vấn đề**: vuốt xoá chủ đề là mất luôn mọi từ bên trong mà không hỏi lại (`TopicsView.swift:19`).
- **Các bước**: vuốt xoá → hiện `confirmationDialog` "Xoá chủ đề X và N từ? Không thể hoàn tác." → chỉ xoá khi bấm nút "Xoá" màu đỏ.
- **Test tự động**: UI `testDeleteTopicAsksConfirmation`:
  1. Vuốt xoá → bấm Huỷ → chủ đề vẫn còn.
  2. Vuốt xoá lần nữa → bấm Xoá → chủ đề mất.
- **Test tay**:
  - [ ] Xoá một chủ đề TOEIC đang học trên lộ trình: app tự thêm lại bộ từ (đúng thiết kế), tiến độ cũ mất. Ghi chú hành vi này vào phần trợ giúp.

### 1.3 Màn hình Cài đặt · P0 · L ✅
- **File**: tạo `SettingsView.swift`, sửa `Models.swift`, `TodayView.swift`, `StudyView.swift` (`Speaker`), `RoadmapView.swift`.
- **Các bước**:
  1. Thêm nút bánh răng ở toolbar tab Hôm nay để mở Cài đặt.
  2. Các cài đặt, lưu bằng `@AppStorage`:
     - [x] Từ mới/ngày: Stepper 5–30, mặc định 15.
     - [x] Từ ôn/ngày: Stepper 10–100, mặc định 40.
     - [x] Giờ nhắc học (chuyển từ tab Hôm nay sang đây).
     - [x] Bật/tắt "Lộ trình tự thêm bộ từ TOEIC".
     - [x] Giọng đọc Mỹ (en-US) / Anh (en-GB), kèm nút nghe thử.
     - [x] Tốc độ đọc: Slider chậm ↔ bình thường.
     - [x] Nếu quyền thông báo đang tắt: hiện dòng "Bật thông báo" mở thẳng vào Settings của iOS.
  3. Đổi `Word.todayQueue(words, now:)` thành `todayQueue(words, newLimit:, reviewLimit:, now:)`, bỏ hằng số cố định.
  4. `Roadmap.prepare(..., enabled:)`: khi tắt thì không tự thêm bộ từ.
- **Test tự động**:
  - [x] Unit `dailyQueueRespectsCustomLimits`: 30 từ đến hạn + 30 từ mới, giới hạn (5, 10) → hàng đợi có đúng 10 từ ôn + 5 từ mới.
  - [x] Unit `roadmapPrepareRespectsToggle`: dùng `ModelContainer` in-memory. `enabled: false` → không có chủ đề nào. `enabled: true` → có 1 chủ đề 20 từ.
  - [x] UI `testChangeNewWordLimit`: mở Cài đặt → giảm từ mới xuống 5 → quay lại → "Từ mới" hiện 5.
- **Test tay**:
  - [ ] Đổi giọng Anh rồi nghe thử: khác rõ với giọng Mỹ.
  - [ ] Kéo tốc độ chậm: thẻ học đọc chậm theo.
  - [ ] Tắt lộ trình, xoá bộ từ của chặng: app không tự thêm lại.

### 1.4 Cập nhật nội dung có sẵn cho bộ từ đã thêm · P0 · S ✅
- **Vấn đề**: bộ từ TOEIC thêm từ bản cũ không có IPA, câu ví dụ, nghĩa câu ví dụ.
- **File**: `GrammarView.swift` (`Content`), `VocabularyStudyApp.swift`.
- **Các bước**:
  1. Viết `Content.sync(topics:)`: với mỗi chủ đề trùng tên bộ có sẵn, điền các ô **đang trống** từ dữ liệu có sẵn, so khớp theo `term`.
  2. Không ghi đè những ô người dùng đã sửa (ô không trống thì giữ nguyên).
  3. Gọi hàm này 1 lần mỗi khi mở app.
- **Test tự động**:
  - [x] Unit `syncFillsMissingFields`: từ "agenda" thiếu IPA → sau sync có `/əˈdʒɛndə/`.
  - [x] Unit `syncKeepsUserEdits`: nghĩa câu ví dụ đã sửa thành "abc" → sau sync vẫn là "abc".
  - [x] Unit `syncIgnoresUserTopics`: chủ đề tự tạo, trùng một từ với bộ TOEIC → không bị đụng tới.

### 1.5 Nhắc học chắc chắn · P0 · M ✅
- **Vấn đề**: không mở app 30 ngày thì hết nhắc. Đây đúng lúc người dùng cần nhắc nhất.
- **File**: `Models.swift` (`Reminder`), `VocabularyStudyApp.swift`.
- **Các bước**:
  1. Tách phần tính ngày thành hàm thuần `Reminder.triggers(now:, minutes:, studiedToday:, days:) -> [DateComponents]` để test được.
  2. Đặt lịch 60 ngày (iOS cho tối đa 64 lời nhắc chờ).
  3. Đặt lại lịch mỗi khi app chuyển vào nền (`scenePhase == .background`).
  4. Lời nhắc ngày thứ 60 đổi nội dung thành "Lâu rồi bạn chưa học, quay lại giữ chuỗi nhé!".
  5. Chỉ đặt lịch khi đã có quyền thông báo. Việc xin quyền chuyển sang onboarding (1.6).
- **Test tự động**:
  - [x] Unit `triggersSkipTodayWhenStudied`: `studiedToday = true` → lời nhắc đầu tiên là ngày mai.
  - [x] Unit `triggersSkipTodayWhenTimePassed`: 21:00, giờ nhắc 20:00 → không có lời nhắc hôm nay.
  - [x] Unit `triggersCountAndTime`: có đúng 60 lời nhắc, giờ/phút đúng với cài đặt.
- **Test tay**:
  - [x] Đặt giờ nhắc sau 2 phút, ra màn hình chính, chờ: thông báo hiện ra.
  - [ ] Đặt giờ nhắc sau 2 phút, học 1 thẻ, ra màn hình chính, chờ: **không** có thông báo hôm nay.
  - [ ] Bấm vào thông báo: mở app ở tab Hôm nay.

### 1.6 Onboarding và xin quyền thông báo · P0 · M ✅
- **Vấn đề**: hộp thoại xin quyền của hệ thống bật ngay khi mở lần đầu, người dùng dễ bấm "Don't Allow".
- **File**: tạo `OnboardingView.swift`, sửa `VocabularyStudyApp.swift`.
- **Các bước**: chỉ hiện lần đầu (`@AppStorage("onboarded")`), gồm 3 trang:
  1. Giới thiệu: "Học từ vựng TOEIC theo lộ trình, mỗi ngày 10 phút".
  2. Chọn số từ mới mỗi ngày: 10 / 15 / 20.
  3. Chọn giờ nhắc + giải thích lý do cần thông báo → nút "Bật nhắc học" mới xin quyền của hệ thống. Có thêm nút "Để sau".
- **Test tự động**:
  - [x] UI `testOnboardingSavesChoice` (argument `-ui-testing -show-onboarding`): chọn 20 từ → hoàn tất → tab Hôm nay hiện "Từ mới 20" (bộ từ chặng 1 có đúng 20 từ), vào Cài đặt cũng thấy 20.
  - [x] UI `testOnboardingSkippedAfterDone`: không có `-show-onboarding` → vào thẳng tab Hôm nay.
- **Test tay**:
  - [ ] Cài mới, bấm "Để sau": app vẫn chạy bình thường, Cài đặt hiện dòng "Bật thông báo".
  - [x] Cài mới, bấm "Bật nhắc học" rồi "Allow": có lịch nhắc (thử như 1.5).

### 1.7 App icon và màu chủ đạo · P0 · S ✅
- **File**: tạo `VocabularyStudy/Assets.xcassets` (`AppIcon`, `AccentColor`), sửa `project.yml` nếu cần.
- **Các bước**:
  1. Icon 1024×1024, có bản sáng, tối và tinted của iOS 18. Ý tưởng: ngọn lửa + quyển sách, khớp với streak.
  2. Đặt `AccentColor` (cam, khớp ngọn lửa) và dùng thống nhất cho các nút chính.
- **Test tay**:
  - [ ] Màn hình chính simulator hiện icon đúng ở cả chế độ sáng và tối.
  - [x] Build không có cảnh báo về asset.
  - [x] Tên hiển thị dưới icon là "Từ vựng".

### 1.8 Đưa app lên TestFlight · P0 · M
- **Trạng thái**: đã có Apple Developer account. **Tạm hoãn**: hiện chỉ code và test trên simulator, làm việc này khi sẵn sàng thử trên máy thật.
- **Các bước**:
  1. Điền `DEVELOPMENT_TEAM` vào `project.yml`, đăng ký bundle id `com.doanthanhphuong.VocabularyStudy`.
  2. Tạo app trên App Store Connect và điền Privacy: "Không thu thập dữ liệu".
  3. Archive → Upload → thêm người dùng vào danh sách tester nội bộ.
- **Test tay trên iPhone thật**:
  - [ ] Cài qua TestFlight được.
  - [ ] Chụp 2 trang sách thật bằng camera: số từ đúng tương đương lúc test bằng ảnh có sẵn (khoảng 19/36 và 25/26).
  - [ ] Thông báo đến đúng giờ khi máy khoá.
  - [ ] Phát âm vẫn kêu khi bật công tắc im lặng.
  - [ ] Chạy hết Checklist hồi quy (mục 6).

**Kết thúc Phase 1** → gửi bản TestFlight cho người dùng và ghi lại phản hồi sau 1 tuần dùng.

---

## Phase 2 — Học sâu hơn (P1)

### 2.1 Ba mức trả lời: Quên / Khó / Dễ · P1 · M ✅
- **File**: `Models.swift`, `StudyView.swift`.
- **Quy tắc**:

  | Mức | Khoảng cách ôn (`interval`) | Hệ số `ease` |
  |---|---|---|
  | Quên | về 0, học lại ngay | −0.2 (tối thiểu 1.3) |
  | Khó | `max(1, interval × 1.2)` | −0.15 (tối thiểu 1.3) |
  | Dễ | như "Nhớ" hiện tại (1 → 3 → × ease) | +0.1 (tối đa 3.0) |

- **Test tự động**:
  - [x] Unit `gradeHard`: chuỗi trả lời Dễ, Dễ, Khó → interval lần lượt 1, 3, 4.
  - [x] Unit `gradeEaseBounds`: ease luôn nằm trong [1.3, 3.0] sau 50 lần trả lời ngẫu nhiên.
  - [x] Cập nhật `spacedRepetition` hiện có để dùng API mới.
  - [x] UI: `testStudyOneCard` dùng nút "Dễ".
- **Test tay**:
  - [x] 3 nút đủ lớn, dễ bấm bằng một tay.

### 2.2 Chế độ gõ từ (đáp ứng "học rồi viết luôn") · P1 · L ✅
- **File**: tạo `TypingView.swift`, sửa `TodayView.swift` (chọn chế độ học).
- **Các bước**:
  1. Tab Hôm nay có lựa chọn chế độ: **Lật thẻ** / **Gõ từ** / **Nghe – gõ**. App nhớ lựa chọn lần trước.
  2. *Gõ từ*: hiện nghĩa + từ loại → người dùng gõ từ tiếng Anh.
  3. *Nghe – gõ*: máy đọc từ (có nút nghe lại) → người dùng gõ.
  4. Kiểm tra đáp án bằng hàm `Answer.matches(input, term)`: không phân biệt hoa thường, bỏ khoảng trắng thừa, bỏ dấu (é = e).
  5. Gõ đúng thì tính là "Dễ". Gõ sai thì hiện đáp án đúng, tô những chữ gõ sai, tính là "Quên", và bắt gõ lại cho đúng mới được sang thẻ tiếp.
- **Test tự động**:
  - [x] Unit `matchesIgnoresCaseSpaceAccent`: `" Resume "` khớp với `"résumé"`.
  - [x] Unit `matchesRejectsPartial`: `"in charge"` không khớp với `"in charge of"`.
  - [x] UI `testTypingCorrect` (`-seed`): chọn Gõ từ → gõ đúng → sang thẻ tiếp.
  - [x] UI `testTypingWrongShowsAnswer`: gõ sai → thấy đáp án đúng.
- **Test tay**:
  - [x] Bàn phím tự bật, không tự viết hoa, không tự sửa chính tả.
  - [ ] Nghe – gõ: nút nghe lại hoạt động, giọng và tốc độ theo Cài đặt.

### 2.3 Trắc nghiệm nghĩa từ · P1 · M ✅
- **Các bước**: hiện từ + IPA, chọn 1 trong 4 nghĩa. Đáp án nhiễu lấy từ cùng chủ đề, nếu không đủ thì lấy từ toàn bộ. Có ít hơn 4 từ thì không cho chọn chế độ này.
- **Test tự động**:
  - [x] Unit `choicesContainAnswerAndAreUnique`: 4 lựa chọn, không trùng nhau, có đáp án đúng.
  - [x] Unit `choicesNilWhenPoolTooSmall`: chỉ có 3 từ → trả về nil.
- **Test tay**:
  - [ ] Vị trí đáp án đúng thay đổi ngẫu nhiên giữa các lần.

### 2.4 Mở rộng ngữ pháp và ôn câu sai · P1 · L ✅
- **File**: `toeic_grammar.json`, `GrammarView.swift`.
- **Các bước**:
  1. Mỗi bài có 15–20 câu (nội dung cần người dùng hoặc giáo viên duyệt lại).
  2. Mỗi lần làm bài lấy ngẫu nhiên 8 câu. Đạt khi đúng ≥ 80% số câu đã làm.
  3. Lưu lại câu đã làm sai. Mỗi bài có nút "Ôn N câu sai", trả lời đúng thì câu đó ra khỏi danh sách.
- **Test tự động**:
  - [x] Unit content: mỗi bài ≥ 15 câu, không trùng đề, đáp án nằm trong 4 lựa chọn (mở rộng test `bundledContentIsValid`).
  - [x] Unit `passedWithEightQuestions`: 7/8 đạt, 6/8 không đạt.
  - [x] Unit `wrongAnswersTracked`: sai câu 3 → có trong danh sách; ôn lại đúng → không còn.
- **Test tay**:
  - [ ] Làm 2 lần liên tiếp thì ra bộ câu khác nhau.
  - [ ] Lộ trình mở chặng mới đúng khi bài đạt.

### 2.5 Quét ảnh tốt hơn · P1 · M ✅
- **File**: `ScanView.swift`.
- **Các bước**:
  1. Bỏ qua từ đã có trong chủ đề và từ bị trùng trong chính lần quét (so không phân biệt hoa thường).
  2. Tự điền IPA, câu ví dụ, nghĩa câu ví dụ nếu từ có trong bộ TOEIC.
  3. Thu nhỏ ảnh xuống cạnh dài ≤ 3000px trước khi chạy OCR.
  4. Hiện "Đã bỏ qua N từ trùng".
- **Test tự động**:
  - [x] Unit `scanDedupesAgainstTopic`: chủ đề có "kind" → quét ra "Kind" bị loại.
  - [x] Unit `scanEnrichesFromContent`: quét ra "agenda" → có IPA và câu ví dụ.
  - [x] Unit `downscaleKeepsAspect`: ảnh 8000×6000 → 3000×2250.
  - [x] Giữ test `parseBookPage` hiện có.
- **Test tay (iPhone thật)**:
  - [ ] Quét cùng một trang 2 lần: lần 2 báo bỏ qua toàn bộ, không thêm từ trùng.
  - [x] Ảnh 48MP quét không bị treo app, ra kết quả dưới 3 giây.

### 2.6 Thống kê · P1 · L ✅
- **File**: tạo `StatsView.swift`, sửa `Models.swift`.
- **Các bước**:
  1. Ghi số thẻ đã học mỗi ngày (`[ngày: số thẻ]`, lưu một key giống `GrammarScores`).
  2. Phân loại trạng thái từ: **mới** (chưa học), **đang học** (interval < 21 ngày), **đã thuộc** (interval ≥ 21 ngày).
  3. Màn hình thống kê gồm:
     - [x] 3 ô số theo trạng thái trên.
     - [x] Biểu đồ cột 30 ngày (Swift Charts).
     - [x] Lịch các ngày đã học dạng heatmap.
- **Test tự động**:
  - [x] Unit `dailyLogIncrements`: học 3 thẻ → hôm nay = 3. Sang ngày mới → ngày mới đếm lại từ 0.
  - [x] Unit `wordStatusThresholds`: interval 20 → đang học, interval 21 → đã thuộc.
- **Test tay**:
  - [x] Biểu đồ hiển thị đúng ở chế độ tối và với cỡ chữ lớn.

### 2.7 Badge và số từ trong thông báo · P1 · S ✅
- **Các bước**:
  1. Khi app vào nền, đặt badge = số từ đến hạn hôm nay (`setBadgeCount`).
  2. Nội dung thông báo hôm nay ghi "Có N từ cần ôn". Các ngày sau giữ câu chung.
- **Test tự động**: unit `dueCountToday`.
- **Test tay**:
  - [x] Badge trên icon đúng số. Học xong buổi → badge về 0.

### 2.8 Tìm và lọc từ · P1 · M ✅
- **Các bước**:
  1. Tab Chủ đề có `.searchable`, tìm theo từ hoặc nghĩa trên toàn bộ từ đã lưu.
  2. Lọc theo trạng thái: mới / đang học / đã thuộc.
- **Test tự động**:
  - [x] UI `testSearchFindsWord` (`-seed`): gõ một phần nghĩa → thấy đúng từ.
  - [x] Unit `searchMatchesMeaningWithoutAccents`: "hao phong" tìm được "hào phóng".

**Kết thúc Phase 2** → chạy Checklist hồi quy, gửi bản TestFlight mới.

---

## Phase 3 — UI/UX và animation (P1)

Quy tắc chung cho mọi animation: đọc `@Environment(\.accessibilityReduceMotion)`. Khi bật Reduce Motion thì chỉ dùng hiệu ứng mờ dần (fade).

### 3.1 Tab Hôm nay mới · P1 · M ✅
- **Các bước**:
  1. Thẻ lớn ở đầu: ngọn lửa streak (nảy lên bằng `symbolEffect(.bounce)` khi chuỗi tăng) và vòng tiến độ "đã học / tổng thẻ hôm nay" (dùng dữ liệu từ 2.6).
  2. Nút "Bắt đầu học" to, màu chủ đạo, có chế độ học đang chọn.
  3. Các con số chuyển mượt bằng `.contentTransition(.numericText())`.
- **Test tự động**: các UI test ở Phase 0–2 vẫn xanh. Giữ nguyên identifier.
- **Test tay**:
  - [x] Xem ở chế độ sáng, tối, và cỡ chữ lớn: không bị cắt chữ (ảnh chụp từ UI test).
  - [ ] Học 1 thẻ rồi quay lại: lửa nảy, vòng tiến độ chạy mượt.

### 3.2 Màn học mới: thẻ, vuốt, lật 3D · P1 · L ✅
- **File**: `StudyView.swift`.
- **Các bước**:
  1. Thẻ có khung giống Flashcard, lật 3D (dùng lại hiệu ứng của `FlashcardView`).
  2. Thanh tiến độ của buổi học ở đầu màn hình.
  3. Sau khi lật thẻ: vuốt phải = Dễ, vuốt trái = Quên. Thẻ nghiêng theo tay, màu xanh/đỏ hiện dần.
  4. Thẻ cũ bay ra theo hướng vuốt, thẻ mới trượt vào.
  5. Rung nhẹ khi trả lời (`.sensoryFeedback`).
- **Test tự động**:
  - [x] Unit `swipeDecision`: kéo +120pt → Dễ, −120pt → Quên, ±60pt → không chọn (thẻ bật về chỗ cũ).
  - [x] UI `testSwipeRightAnswers`: lật thẻ → vuốt phải → số thẻ còn lại giảm.
- **Test tay**:
  - [ ] Lật và vuốt mượt, không giật khi đi qua 20 thẻ liên tiếp.
  - [ ] Bật Reduce Motion: không có xoay 3D hay bay ra, chỉ mờ dần.
  - [x] Vẫn bấm được nút như cũ, không bắt buộc phải vuốt.

### 3.3 Tổng kết sau buổi học · P1 · M ✅
- **Các bước**:
  1. Học xong hiện số từ Dễ/Khó/Quên, danh sách các từ đã quên, và "Chuỗi: N ngày (+1)".
  2. Đạt mốc chuỗi 7/30/100 ngày thì bắn pháo giấy (tự vẽ bằng `Canvas`, không thêm thư viện ngoài).
- **Test tự động**:
  - [x] Unit `summaryCountsForgottenOnce`: một từ quên 2 lần trong buổi chỉ tính 1 lần trong danh sách quên.
  - [x] UI `testSummaryAfterSession`: học hết 3 thẻ → thấy "3 từ" trong tổng kết.
- **Test tay**:
  - [ ] Pháo giấy chỉ bắn ở đúng mốc. Bật Reduce Motion thì không bắn.

### 3.4 Tiến độ trong danh sách chủ đề · P1 · S ✅
- **Các bước**: mỗi chủ đề có thanh tiến độ "đã học / tổng" và số từ đến hạn.
- **Test tay**:
  - [x] Học 1 từ → thanh tiến độ của chủ đề đó tăng (UI `testTopicProgressUpdates`).

### 3.5 Lộ trình dạng timeline · P1 · M ✅
- **Các bước**:
  1. Vẽ đường dọc nối các chặng. Mỗi chặng là một nút tròn: đã xong ✓, đang học (nhấp nháy nhẹ), bị khoá 🔒.
  2. Chạm vào chặng để mở chi tiết.
  3. Hoàn thành chặng thì nút mở khoá có animation, chạy 1 lần (nhớ chặng đã xem bằng `lastSeenStage`).
- **Test tự động**: các test của `Roadmap` vẫn xanh.
- **Test tay**:
  - [ ] Cho đạt bài ngữ pháp và học hết từ chặng 1 (dùng `-seed` với dữ liệu đã học sẵn): chặng 2 mở khoá có animation, mở lại app thì không chạy lại.

### 3.6 Bài giảng ngữ pháp dễ đọc hơn · P1 · M
- **Các bước**:
  1. Đổi `lesson` trong JSON từ một chuỗi dài thành danh sách khối: `text`, `formula` (khung màu), `example` (khung ví dụ, có nút nghe).
  2. Cập nhật test nội dung.
- **Test tự động**: unit content kiểm tra mọi khối đều có `type` hợp lệ.
- **Test tay**:
  - [ ] Đọc hết 10 bài ở chế độ tối, công thức và ví dụ rõ ràng.

### 3.7 Animation cho trắc nghiệm ngữ pháp · P1 · S
- **Các bước**: đáp án sai rung lắc (`keyframeAnimator`), đáp án đúng sáng lên, thanh tiến độ câu hỏi chạy mượt.
- **Test tay**:
  - [ ] Hiệu ứng đúng/sai rõ ràng. Có Reduce Motion thì chỉ đổi màu.

### 3.8 Accessibility, Dark Mode, Dynamic Type · P1 · M
- **Các bước**:
  1. Nhãn VoiceOver cho mọi nút chỉ có icon.
  2. Kiểm tra bằng Accessibility Inspector (Xcode → Open Developer Tool).
  3. Sửa các chỗ bị cắt chữ.
- **Test tự động**: UI `testLargeTextSmoke`: chạy luồng học 1 thẻ với argument `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL`.
- **Test tay**:
  - [ ] Bật VoiceOver và học được 1 thẻ chỉ bằng thao tác VoiceOver.

**Kết thúc Phase 3** → quay video màn hình các luồng chính và gửi người dùng xem trước khi phát hành.

---

## Phase 4 — Tối ưu (P1, làm khi dữ liệu lớn hoặc khi thấy chậm)

### 4.1 Dữ liệu lớn để đo hiệu năng · P1 · S
- **Các bước**: thêm launch argument `-seed-large` tạo 50 chủ đề × 200 từ = 10.000 từ, với tiến độ ngẫu nhiên.
- **Test tự động**: unit performance `measure { todayQueue(10_000 từ) }` để lấy mốc trước khi tối ưu.

### 4.2 Fetch theo điều kiện thay vì lọc cả bảng · P1 · M
- **Vấn đề**: `todayQueue` lọc toàn bộ từ mỗi lần vẽ lại `TodayView` và `TopicDetailView`.
- **Các bước**:
  1. Dùng `FetchDescriptor` với `#Predicate` (`learnedAt != nil && due <= now`), có `fetchLimit`.
  2. Các con số dùng `fetchCount`.
- **Test tự động**:
  - [ ] Unit: kết quả mới giống hệt kết quả cũ trên cùng dữ liệu mẫu.
  - [ ] Performance test nhanh hơn mốc ở 4.1.
- **Test tay**:
  - [ ] Với `-seed-large`, tab Hôm nay mở dưới 0,5 giây. Đo bằng Instruments (SwiftUI + Time Profiler).

### 4.3 Tính lộ trình 1 lần mỗi lần vẽ · P1 · S
- **Vấn đề**: `Roadmap.current` bị gọi 2 lần mỗi lần render tab Hôm nay, mỗi lần duyệt hết từ của mọi chủ đề.
- **Các bước**: tính một `RoadmapState` duy nhất trong `TodayView`, rồi truyền xuống `RoadmapSection` và `.task(id:)`.
- **Test tự động**: các test `roadmap` vẫn xanh.

### 4.4 Index SwiftData · P2 · S
- **Các bước**: thêm `#Index<Word>([\.due], [\.learnedAt])`.
- **Test tự động**: performance test ở 4.2 không chậm đi. Mở app có dữ liệu cũ không bị mất dữ liệu (migration).

### 4.5 Cấu hình audio 1 lần · P2 · S
- **Các bước**: chuyển `AVAudioSession.setCategory` từ mỗi lần đọc (`StudyView.swift:162`) sang lúc mở app.
- **Test tay**:
  - [ ] Bật im lặng vẫn nghe được.
  - [ ] Đang mở nhạc nền: app đọc xong thì nhạc tiếp tục phát.

### 4.6 Chặn trùng chủ đề và trùng từ · P1 · S
- **Các bước**:
  1. Không cho tạo chủ đề trùng tên: báo lỗi trong alert.
  2. Nhập tay trùng từ trong cùng chủ đề: hỏi "Từ đã có, vẫn thêm?".
- **Test tự động**: unit `rejectsDuplicateTopicName`. UI `testDuplicateTopicShowsError`.

### 4.7 UI test luồng chính từ đầu đến cuối · P1 · M
- **Test tự động**: `testFullJourney`:
  1. Onboarding.
  2. Chặng 1 tự thêm bộ từ.
  3. Học hết thẻ hôm nay.
  4. Làm bài ngữ pháp đạt.
  5. Xem tiến độ lộ trình.
  6. Streak = 1.

### 4.8 CI chạy test tự động · P2 · S
- **Cần người dùng quyết**: tạo repo GitHub (private) và push code lên.
- **Các bước**: GitHub Actions trên runner macOS: cài XcodeGen → `xcodegen generate` → `xcodebuild test`.
- **Xong khi**: mỗi lần push đều thấy dấu ✓ xanh.

### 4.9 Dọn code · P2 · S
- **Các bước**:
  1. Tách `Content`/`VocabDeck` ra file `Content.swift`.
  2. Đổi từ vựng trong JSON từ mảng `[String]` sang object có tên trường (`term`, `ipa`, `pos`…), để sửa nội dung không bị nhầm vị trí.
- **Test tự động**: `bundledContentIsValid` và các test hiện có vẫn xanh, không đổi hành vi.

---

## Phase 5 — Để sau (P2, chọn theo phản hồi người dùng)

- [ ] Widget màn hình chính: streak và số từ cần ôn. *Test*: widget cập nhật sau khi học.
- [ ] Sao lưu: xuất/nhập file CSV/JSON. *Test*: xuất → xoá app → nhập lại → dữ liệu và tiến độ giống hệt.
- [ ] "Đóng băng chuỗi": nghỉ 1 ngày mỗi tuần không mất chuỗi. *Test*: unit cho `Streak` với ngày nghỉ.
- [ ] Mục tiêu học: điểm TOEIC muốn đạt và ngày thi → gợi ý số từ mới mỗi ngày. *Test*: unit cho công thức gợi ý.
- [ ] Thêm bộ từ TOEIC: Part 1 mô tả tranh, sức khoẻ, bất động sản…
- [ ] Hỗ trợ iPad (bố cục 2 cột).
- [ ] Đồng bộ iCloud, chỉ làm khi người dùng thật sự dùng nhiều máy.

---

## 6. Checklist hồi quy (chạy cuối mỗi phase)

Chạy trên simulator sau khi đã xoá app và cài lại (giống lần cài đầu):

- [x] Lần đầu mở app: onboarding (từ Phase 1) → tab Hôm nay có chặng 1 và 15 từ mới.
- [ ] Học hết thẻ hôm nay → tổng kết → streak = 1 → hết thẻ cần học.
- [ ] Mở bài ngữ pháp của chặng, làm đạt → dấu ✓ ở tab Hôm nay và Ngữ pháp.
- [x] Tab Chủ đề: thêm bộ TOEIC khác, thêm chủ đề tự tạo, nhập tay 1 từ, sửa từ, xoá từ.
- [ ] Quét ảnh: chọn ảnh trang sách trong thư viện → kiểm tra lại → lưu → từ hiện trong chủ đề.
- [ ] Flashcard: vuốt, lật, trộn, nghe.
- [ ] Phát âm: nút nghe ở danh sách từ, trên thẻ, ở câu ví dụ.
- [ ] Cài đặt: đổi giới hạn từ, giọng đọc, giờ nhắc. Tắt hẳn app rồi mở lại vẫn giữ.
- [x] Đặt giờ nhắc sau 2 phút → có thông báo.
- [x] Chế độ tối và cỡ chữ lớn: không vỡ bố cục ở 3 tab chính.
- [ ] Tắt hẳn app rồi mở lại: dữ liệu, streak, điểm ngữ pháp còn nguyên.
