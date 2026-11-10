# تغييرات المرحلة الأولى (إصلاحات إلزامية)

## ما تم
1. **supabase/migrations/002_security_hardening.sql**: إعادة كتابة كل سياسات RLS:
   - الطالب لا يستطيع رصد درجة أو ملاحظات لنفسه (سياسة + مشغّل).
   - إعادة التسليم مسموحة قبل موعد الاستحقاق وقبل رصد الدرجة.
   - الدرجة يجب أن تكون بين 0 والدرجة العظمى للتكليف (مشغّل في القاعدة).
   - الطالب لا يرى المحاضرات غير المنشورة.
   - الإعلانات تحترم `audience` وربطها بمقرر.
   - المدرس يرى ويعدّل مقرراته وطلاب مقرراته فقط.
   - الحساب الموقوف لا يقرأ بيانات (عدا ملفه الشخصي ليظهر له سبب الرفض).
   - الدالة `current_role()` استُبدلت بـ `app_current_role()` مع دوال مساعدة ثابتة `search_path`.
   - تفرّد `student_number`.
2. **supabase/functions/set-user-status**: دالة للإدارة فقط تحدّث `is_active` وتحظر المستخدم في Supabase Auth. التطبيق يستدعيها بدل التعديل المباشر.
3. **lib/main.dart**: رابط Supabase والمفتاح العام يُقرآن من `--dart-define` فقط (أُزيلا من الكود).
4. **.github/workflows/build-apk.yml**: إصلاح خطأ `\\` في أمر البناء، ونقل رابط المشروع إلى GitHub Variable، وإضافة خطوة توقيع اختيارية.
5. **android/app/build.gradle**: توقيع الإصدار من `android/key.properties` إن وُجد.
6. **.gitignore**: منع مفاتيح التوقيع.
7. **supabase/tests/**: اختبارات صلاحيات تعمل على PostgreSQL محلي.

## ما يجب عليك فعله
1. نفّذ `002_security_hardening.sql` في SQL Editor (جرّبه أولًا على مشروع تجريبي).
2. انشر الدالة الجديدة: `supabase functions deploy set-user-status`.
3. في GitHub: Settings > Secrets and variables > Actions:
   - Variable: `SUPABASE_URL`
   - Secret: `SUPABASE_ANON_KEY`
   - (للتوقيع الحقيقي) Secrets: `ANDROID_KEYSTORE_BASE64` و`ANDROID_KEYSTORE_PASSWORD` و`ANDROID_KEY_ALIAS` و`ANDROID_KEY_PASSWORD`.
4. أنشئ keystore مرة واحدة واحفظ نسخة منه بعيدًا؛ فقدانه يعني عدم إمكانية تحديث التطبيق:
   `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
5. للتشغيل المحلي: `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

## لم يُنفَّذ (ينتظر قرارك أو بيئة بناء)
- **اسم الحزمة** ما زال `com.example.academic_platform`. تغييره يجعل أندرويد يعتبره تطبيقًا مختلفًا، فوافق عليه صراحة أولًا.
- **خطوة `flutter create` في workflow** تُركت كما هي لأنني لم أستطع تجربة البناء؛ إن ظهر تعارض ملفات Gradle (`build.gradle` مع `build.gradle.kts`) احذف الخطوة.
- لم يُشغَّل `flutter analyze` ولا `flutter test` ولا بناء APK (لا يوجد Flutter SDK في بيئتي). شغّلها عندك.
- الإعلانات التي أنشأها حساب لا يراه الطالب قد يظهر اسم ناشرها فارغًا (الطالب لا يقرأ ملفات غير المدرسين).
- التقارير والترقيم والرفع إلى Storage من المراحل التالية.

---

# المرحلة الثانية (تقسيم الملف الضخم)

قُسّم `lib/main.dart` (2650 سطرًا) إلى 23 ملفًا داخل `lib/core/` و`lib/features/` باستخدام `part` / `part of`.
- الكود نُقل حرفيًا بلا أي تغيير في السلوك. تحققت برمجيًا أن إعادة تجميع الأجزاء تطابق الملف الأصلي سطرًا بسطر.
- بقي `main.dart` فيه الاستيرادات وإعداد Supabase والألوان وتطبيق `AcademicPlatformApp` فقط.
- هذا تقسيم تنظيمي آمن وليس إعادة هيكلة كاملة: الملفات ما زالت مكتبة واحدة تتشارك الأسماء الخاصة، ولم تُفصل طبقات data/domain/presentation ولا نماذج البيانات بعد.
- لم يُجرَّ تحويل إلى Riverpod. لم أشغّل `flutter analyze` (لا يوجد Flutter SDK عندي)، فشغّله أولًا، وإن ظهر خطأ فارسله لي.

---

# المرحلة الثالثة (جزء قاعدة البيانات): Storage

- **supabase/migrations/003_storage_buckets.sql**: حاويتان خاصتان `lectures` و`submissions` (حد 20 ميغابايت، PDF وWord وPowerPoint وExcel وصور وZIP) مع سياسات:
  - المحاضرات: الرفع للإدارة وللمدرس صاحب المقرر؛ الطالب يقرأ ملف محاضرة **منشورة** في مقرر مسجل به فقط.
  - التسليمات: الطالب يرفع داخل مجلده فقط، لتكليف في مقرر مسجل به، ولا يعدّل أو يحذف بعد رصد الدرجة؛ يقرؤها المدرس صاحب المقرر والإدارة وصاحب الملف.
  - الحساب الموقوف لا يقرأ ولا يرفع.
- **مسارات الملفات الإلزامية** (على التطبيق الالتزام بها):
  - `lectures`: `<course_id>/<اسم_الملف>` ويُخزَّن المسار نفسه في `lectures.file_path`.
  - `submissions`: `<assignment_id>/<student_id>/<اسم_الملف>`.
- **الاختبارات**: `bash supabase/tests/run_local.sh` تشغّل الآن 47 فحصًا للجداول و22 فحصًا لـStorage على PostgreSQL محلي (محاكاة لمخطط storage في Supabase، فجرّبها على مشروع تجريبي حقيقي أيضًا).
- **لم يُنفَّذ بعد (كود Flutter)**: فتح الروابط (`url_launcher`)، اختيار الملف ورفعه، الروابط الموقّعة `createSignedUrl`. يحتاج `flutter pub get` وتجربة على جهاز.
