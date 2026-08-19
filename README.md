# VideoDownloaderPro (Video Pro)

تطبيق iOS باللغة العربية: متصفح مدمج مع **مانع إعلانات** و**كاشف فيديوهات** وإمكانية **تحميل الفيديوهات** وتشغيلها محلياً.

## المميزات

- 🌐 متصفح مبني على `WKWebView` مع شريط تنقّل وبحث
- 🛡️ حظر إعلانات وتتبّع (fetch / XHR / WebSocket / عناصر DOM / النوافذ المنبثقة + زر "تخطي الإعلان" في يوتيوب)
- 🎬 اكتشاف تلقائي للفيديوهات في الصفحة:
  - ملفات مباشرة: `MP4 / M4V / MOV / WEBM / AVI / 3GP`، وكذلك روابط الوسائط التي لا تحمل امتداداً عندما يكشفها عنصر الفيديو أو الخادم
  - بث HLS (`.m3u8`) — يُحمَّل **كفيديو كامل قابل للتشغيل** (صيغة `.movpkg`) عبر `AVAssetDownloadURLSession`
  - مراقبة عناصر الوسائط وطلبات `fetch/XHR` وموارد الصفحة المتأخرة؛ لذلك تعمل مع عدد أكبر من مشغلات المواقع الحديثة
- 📥 تنزيلات بأسماء نظيفة مأخوذة من عنوان الصفحة مع ترويسات متصفح حقيقية (`User-Agent` + `Referer`) وملفات تعريف ارتباط من جلسة الموقع عند الحاجة
- 🔒 لا يتحايل التطبيق على DRM أو جدران الدفع أو وسائل حماية المواقع؛ تظهر هذه الحالات كغير مدعومة بدلاً من محاولة كسرها
- 📚 مكتبة للتشغيل والحذف مع مشغّل `AVPlayerViewController` بأزرار تحكم كاملة
- ⚙️ إعدادات: معلومات التطبيق، مسح التحميلات، المشاركة

## البنية

```
VideoDownloaderPro/
├── project.yml                     # مواصفات XcodeGen (يولّد مشروع Xcode)
└── VideoDownloaderPro/
    ├── AppDelegate.swift           # نقطة الدخول + شريط التبويبات
    ├── BrowserViewController.swift # المتصفح + حقن السكربتات + واجهة التحميل
    ├── Scripts.swift               # سكربتات JS: مانع الإعلانات + كاشف الفيديو
    ├── DownloadManager.swift       # تحميل الملفات المباشرة وبث HLS
    ├── LibraryViewController.swift # المكتبة + المشغّل
    ├── SettingsViewController.swift
    └── Info.plist
```

> ملاحظة: لا يوجد `VideoDownloaderPro.xcodeproj` في المستودع — يتم توليده تلقائياً عبر [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## البناء

### عبر GitHub Actions

ادفع إلى `main` أو شغّل الـ workflow يدوياً (*Actions → Build VideoDownloaderPro → Run workflow*).
سيتم رفع ملف `VideoDownloaderPro.ipa` كـ Artifact، وعند الدفع إلى `main` يُنشأ Release تلقائياً.

### محلياً (macOS)

```bash
brew install xcodegen
cd VideoDownloaderPro
xcodegen
open VideoDownloaderPro.xcodeproj
```

أو من سطر الأوامر (بناء غير موقّع للتجربة):

```bash
xcodebuild \
  -project VideoDownloaderPro.xcodeproj \
  -scheme VideoDownloaderPro \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## التثبيت على الجهاز

ملف الـ IPA الناتج **غير موقّع**. لتثبيته على جهاز غير مكسور الحماية تحتاج لإعادة توقيعه بشهادة مطوّر عبر إحدى الأدوات: [Sideloadly](https://sideloadly.io) أو [AltStore](https://altstore.io) (بحساب Apple مجاني تنتهي الشهادة بعد 7 أيام).

## القيود المعروفة

- ❌ **يوتيوب وجوجل فيديو**: روابط الفيديو محمية بتوقيعات ولا تحمل امتداداً واضحاً — لن يكتشفها التطبيق (وتحميل محتوى يوتيوب يخالف شروط الخدمة).
- ❌ **DASH (`.mpd`)**: غير مدعوم — AVFoundation لا يحمّل بث DASH.
- ⚠️ بعض المواقع تحمي ملفاتها بتوكنز قصيرة العمر أو تتطلب تسجيل دخول — قد يفشل التحميل منها رغم اكتشاف الرابط.
- ⚠️ ملفات `WEBM` تُحمَّل لكن تشغيلها في AVPlayer غير مضمون.

## تنبيه قانوني

هذا التطبيق أداة تقنية لأغراض شخصية. حمّل فقط المحتوى الذي تملك حق تحميله. المطوّر غير مسؤول عن أي استخدام يخالف شروط خدمات المواقع أو قوانين الملكية الفكرية في بلدك.
