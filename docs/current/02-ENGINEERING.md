# LAYER SORT — ENGINEERING / FIREBASE SPARK / QUALITY / RISK

> **الملف:** `docs/current/02-ENGINEERING.md` | **المصدر:** LS-MASTER-1.3 — مقتطع حرفيًا من الحزمة المعتمدة دون تغيير في القرارات.
> **المحتوى:** Firebase Spark والحالة والاستعادة والاختبارات وسجل المخاطر والمراقبة.
> **بادئة المعرّفات عند الإشارة من ملف آخر:** `ENG-` (مثال: عند ذكر Q01 من هذا الملف اكتب `ENG-Q01`) لتجنب تكرار المعرّفات بين الملفات.
> **ملفات `docs/current/`:** `00-START-HERE.md` (قرارات مركزية) · `01-UX-ART.md` (واجهة وفن وصوت) · `02-ENGINEERING.md` (هندسة وFirebase ومخاطر) · `03-PRODUCTION.md` (بوابات وخطة وتسليم)

**المعرف:** LS-TECH-1.3 | **الحالة:** أساس تنفيذي معتمد بعد مراجعة متطلبات Godot 4/GDScript/Android/Firebase | **تاريخ:** 24 أكتوبر 2026

## 1. Firebase — التزام Spark المجانية دون استثناء مالي

### F01 — هل Firebase مجانية بالكامل بالنسبة لنا؟
**القرار:** نستخدم **Firebase Spark** فقط و**لا نربط Billing Account** ولا نحول إلى Blaze ولا نفعل منتجات تتطلبها. الخدمات المعتمدة: Analytics، Crashlytics، Remote Config وApp Distribution وفق شروطها وحصصها وقت التفعيل. لا نفعّل Cloud Functions/Cloud Run أو Google Cloud المدفوعة أو تصدير BigQuery. لا يجري الوكيل عمليات إنشاء/ربط/دفع من حساب المستخدم دون إجراء صريح منه. **ملاحظة دقيقة:** بعض منتجات Spark التي تستخدم حصصًا مجانية قد تتوقف بعد بلوغ حدودها حتى تجدد الحصة، ولا يعني Spark أن كل خدمات Google مجانية بلا سقف. مصدر رسمي: https://firebase.google.com/pricing وhttps://firebase.google.com/docs/projects/billing/firebase-pricing-plans وhttps://firebase.google.com/support/faq .

### F02 — ماذا لو خلصت الحصة أو Firebase وقع؟
**القرار:** لا أثر على Core Game: مستويات محلية، نظام حفظ محلي، Undo، Map، Audio، Tutorials. Remote Config يعيد Default config محليًا وقديمًا صالحًا بعد التحقق من Schema؛ Analytics يفقد أحداثًا غير حرجة، وCrashlytics قد لا يرسل تقريرًا؛ diagnostics المحلية تعمل. لا تفعيل/تشغيل سيرفر لتكملة المستوى. **اختبار:** Airplane Mode وDNS failure وinvalid SDK configuration وSpark quota mock.

### F03 — كيف يدخل Firebase إلى Godot/GDScript؟
**القرار:** Godot game domain يكتب GDScript فقط؛ SDK Android عادة يحتاج Native Plugin (Java/Kotlin + Gradle/Android SDK) عبر Adapter، ويربط GDScript إلى واجهة مستقلة. لا نفترض وجود Firebase GDScript رسمي كامل من Godot؛ نفحص SDK/plugin الدقيق وربطه ونظام تراخيصه وABI والتوقيع وقت Spike Firebase. الأسماء مثل `TelemetryPort`, `CrashPort`, `RemoteConfigPort` تعبير عن عقود الفصل وليست APIs موجودة مسبقًا. **اختبار:** Noop Adapter يعمل بمفرده، ثم Native Adapter يحصل على تقرير Crash/Fake event في بيئة تجريبية.

### F04 — هل Firebase يرصد كل أخطاء GDScript تلقائيًا؟
**الإجابة:** لا يمكن ضمان ذلك. Crashlytics يغطي Android/native وبعض الأخطاء غير الفادحة التي تُرسل صراحة وفق الربط؛ الـGDScript script errors غير الملتقطة قد تظهر في Godot logs دون تقرير Crashlytics تلقائي. `ErrorReporter` يحوّل أخطاء Domain/Level/Save المتوقعة إلى أحداث `nonfatal` منظّفة، مع Logcat وملفات Debug؛ خُلق نسخة تجريبية تؤدي إلى Error معروف ويُتحقق من ظهوره قبل الادعاء بالتغطية. مرجع: https://firebase.google.com/docs/crashlytics/android/get-started .

### F05 — هل نجمع بيانات اللاعب من أول فتح؟
**القرار:** لا بيانات تحليلات اختيارية قبل إتاحة إفصاح واضح وإجراء الموافقة أو أساس المعالجة القانوني المناسب للسوق والجمهور الفعلي؛ إلى أن يُراجَع السوق المستهدف نحافظ على `Analytics=false` افتراضيًا. Crash collection خاضع لسياسة الخصوصية والتكامل؛ وضع privacy default conservative. لا اسم/هاتف/إيميل/معرّفات شخصية مخصصة ضمن أحداث لعبنا. Settings > Privacy: شرح/تبديل إتاحة جمع التشخيص والتحليلات وفق الضوابط، مع خيار `Not now` غير خادع؛ الرفض لا يحرم اللعب.

### F06 — ماذا عن بيانات مستخدمين أقل من العمر المحدد؟
**القرار:** جمهور كاجوال واسع، لكن **تصنيف عمر متجر وتغطية الأطفال ليسا محسومين قانونيًا بعد** ولا يجوز ادعاء أن الـSDK مناسب للأطفال تلقائيًا؛ قبل Beta عامة تُجرى مراجعة Families/GDPR-K والولايات الأخرى. إذا ظهرت متطلبات خاصة، إما نمنع جمعًا غير ملائم ونلتزم بها أو نراجع الفئة المستهدفة. لا استخدام Advertising ID في Core MVP.

### F07 — كيف نعرف أن التحليلات صحيحة؟
**القرار:** قاموس أحداث Allowlist بإصدارات schema (`session_start`, `level_start`, `level_complete`, `level_restart`, `level_exit`, `hint_used`, `undo_used`, `timer_expired`, `chapter_unlock`, `save_recovered`, `loading_error`) وخصائص non-PII: `app_version`, `level_id`, `chapter`, `mechanic_set`, `difficulty_bucket`, `duration_bucket`, `moves_bucket`, `graphics_tier`. لا نرسل تاريخ نقل كل طبقة أو raw save. Test events تتحقق من cardinality، duplicate completion، offline behavior، وفصل تجربة QA عن الإنتاج.

### F08 — كيف نراقب الاستخدام والتكلفة ونحن على Spark فقط؟
**القرار:** مراجعة إعداد `Spark` في Firebase Console عند تهيئة المشروع وفي كل مراجعة شهرية، فحص حدود الخدمات المستخدمة وتحذيرات الحصة، منع حسابات الفوترة وCloud Functions في CI/دليل الإنشاء، وقائمة خدمات Allowlist. `firebase.json` وGradle Plugins لا تُفعّل شيئًا خارج allowlist. لا أعِد بإشعار من Firebase لكل حالة حصص إلا بعد اختبار وجوده فعليًا؛ نظهر Dashboard شهرية يراجعها المالك.

## 2. تصميم state/recovery — إجابات على الفجوات

### S01 — ما المصدر الوحيد لحالة اللعبة؟
**القرار:** `GameState` immutable أو منسوخ بشكل مضبوط، يحوي tubes, capacity, active_mechanics, gate_latches, frozen flags, shift charges, links, move_count, timer_mode, event_sequence, level_id/version/seed. لا Scene Node هي المصدر الحقيقي للطبقات؛ العرض مشتق من الحالة. كل أمر يمر من `GameController.submit_command` بعد Validation. **اختبار:** State hash قبل وبعد Undo/Redo (حيث يوجد) ومقارنة bit-exact للمنطق.

**توضيح ADR-0002:** لا تُستنتج `active_mechanics` من رقم المستوى وحده: مستويات Classic عادية تتناوب مع Circuit من 16–29 وتستمر لاحقًا، لذا بيانات المستوى تصرّح بمجموعة الميكانيكيات والقواعد/نسخة المحتوى صراحة. لا يضيف هذا التوضيح ميكانيكية إلى نطاق G2 (Classic فقط).

### S02 — إيه حالة اللعبة أثناء السكب؟
**القرار:** State machine `LOADING → READY → COMMITTING → ANIMATING → READY / WON / TIMED_OUT`, مع `PAUSED` و`RECOVERY`؛ تنفيذ الأمر والنتيجة يُحسمان مرة واحدة قبل بدء الأنيميشن، ثم يمنع إدخال حركة ثانية أثناء ANIMATING. الأنيميشن ليس مصدرًا للتغيير ويُلغى/يسوّى إلى committed state عند فقد التطبيق للتركيز. **اختبار:** 100 taps/second و2-finger gestures وRestart أثناء animation.

### S03 — ما سياسة إنهاء اللعبة فجأة أثناء حفظ/سكب؟
**القرار:** كتابة `save.tmp` + flush/close آمن وفق API متاح + atomic rename إن دعمت المنصة أو استراتيجية ملفات دورية `save_a/save_b` مع version/checksum/sequence، مع last-known-good snapshot. نخزّن committed state فقط مع pending save queue؛ عند الاسترداد نختار آخر نسخة كاملة صالحة، وإذا لم يمكن استعادة الحالة نعود لنقطة فصل آمنة ولا نفقد unlocks المكتملة. خطأ الكتابة لا يُسكت، وتظهر رسالة مناسبة. **اختبار:** force-stop أثناء السكب والحفظ، وملف مقطوع، وتلف checksum، وانعدام مساحة.

### S04 — كيف نحدّث schema دون كسر حفظ اللاعبين؟
**القرار:** `save_schema_version` + migration functions متدرجة + tests بملفات حقيقية قديمة محاكاة، وقاعدة `unknown fields ignored safely`, وعدم تنزيل نسخة جديدة إلا إذا قدرنا استعادة الحفظ لنسخة القديمة المعتمدة. تغير المحتوى يحتفظ بـ`level_id/content_version` مع fallback إلى packaged previous level أو completion mapping. **اختبار:** migration snapshots من كل نسخة Release سابقة، دون إجراء downgrade APK كحل مضمون.

### S05 — هل تشفير ملف الحفظ مطلوب الآن؟
**القرار:** لا حماية زائفة بتشفير بمفتاح مدفون في التطبيق؛ في لعبة أوفلاين كل ذلك قابل للتجاوز. نعطي الأولوية لسلامة البيانات وChecksum وBackup. لا حسابات مدفوعة ولا عملات قابلة للتحويل في MVP، وبالتالي Anti-cheat تجاري غير مناسب الآن. يتم إعادة تقييمه فقط إن ظهر اقتصاد/منافسة تعتمد على خدمة مركزية.

### S06 — هل ينفع تشغيل Cloud Save مجانًا؟
**القرار:** لا نعتمده في v1.0؛ Spark فقط، لكن الميزة ليست ضرورية للعب ولا نعد بمزامنة عبر الأجهزة. Export/Import progress محلي بعد تصميم format آمن، ثم يمكن دراسة Google Play Games/Android Backup لاحقًا حسب القيود والخصوصية والاختبارات؛ لا افتراض بتوفير نسخ سحابية لا تمتلكها اللعبة.

### S07 — كيف نتعامل مع أخطاء قابلة للتعافي؟
**القرار:** `GameError` typed مع severity وerror_id وsafe_message وrecovery_action؛ شاشة Recoverable Error فيها Retry/Restore/Home. Logs محلية دوارة، حجم مبدئي 3×1 MiB على الأكثر، يُزال منها العناوين السرية/مواقع الملفات الحساسة وTokens. Export Sanitized Report بإجراء اللاعب. لا إرسال تلقائي لكل Log خام إلى خدمة سحابية.

## 3. ضمان الجودة الرسومية وصوت اللعبة

### Q01 — كيف نفرّق بين جودة الشكل والسرعة؟
**القرار:** Asset Style Guide هو بوابة Review؛ كل عنصر يعرض screenshot at 1x، وعلى 720×1600 و1080×1920 ومحاكي ضعيف؛ Baseline Low/Med/High بالصور. Preset Low يحتفظ بالألوان والحدود والرموز ويحذف المؤثرات الثانوية: glow layers كثيفة، blur, excessive particles؛ Med يعيد موجة زجاج خفيفة؛ High يسمح بـspecular/soft animated background عند الأداء المستهدف.

### Q02 — ما معايير الأداء؟
**القرار:** على OPPO Android 11 نستهدف 30fps مستقر في Low وp95 frame time ≤33.3ms لمشهد لعب معياري؛ 60fps هدف للأجهزة المناسبة وليس ادعاء نجاح مسبق. البدء يسجل cold start time وتغير استهلاك الذاكرة خلال 20 دقيقة لعب، ومعدل حفظ ورفع/تحميل مستوى، وحرارة الهاتف مع Battery Saver. نتائج جهاز حقيقي هي Release Gate مستقل، لأن GitHub runner لا يمتلك GPU الهاتف.

### Q03 — كيف نمنع صور وصوت «مجانية» غير قانونية؟
**القرار:** `assets/licenses/ASSET_REGISTER.csv` يحمل لكل أصل: `asset_id,source_url,creator,license,license_snapshot,attribution_text,commercial_permission,modifications,hash,reviewer,release_status`. لا أصل يتحول إلى `approved` إذا `license=unknown`. صوت/موسيقى AI يسجل أداة التوليد وشروطها وتاريخها وما إذا تتطلب نسبة. Godot وPlugins والخطوط لها قائمة تراخيص مستقلة محدثة في Credits وLicenses.

### Q04 — كيف نمنع تجربة مزعجة؟
**القرار:** Screen Shake بحد خفيف اختياري 0–2px منطقي، منع الرمش السريع والصوت الحاد، Reduce Motion يختصر الرقص البصري، Color Assist يضع رموزًا على كل طبقة، موسيقى تتوقف عند المكالمة/خلفية التطبيق، وAudio Mixer يحد الذروة. لا إعلان يوقف اللعب أو تشجيع compulsive streak.

### Q05 — كيف نضمن حفظ الشاشات كما صممناها؟
**القرار:** Snapshot Goldens AR/EN × ratios مع تقارير Diff؛ استثناء Dynamic timestamps/particles بذور ثابتة؛ صور فعلية من Appium وعناصر Scenes. رفض PR عند اختفاء زر، خط غير مقروء، مسافات تلامس، أو تعديل مفاجئ في hue semantics.

## 4. طبقات الاختبار وأدوات الوكلاء

| الطبقة | الاختبارات الأساسية | أداة مستقلة/شرط فشل |
|---|---|---|
| Domain | ملكية اللون، السعة، قواعد الصب، Atomic Commit، التراجع، الفوز/الوقت | GDScript headless tests؛ أي خلل يرفض PR |
| Mechanic | Circuit latch, Freeze, Shift charges, Links, Undo with combined mechanics | Property tests/seed snapshots؛ كل انتقال قانوني قابل للتراجع |
| Generation | Test N seeds, solvability, duplicate canonical state, bounded retries, difficulty tags | Offline Python/Godot batch؛ لا نشر مستوى بلا certificate |
| Save | killed app, schema migration, corrupt/temp/backup recovery, full storage | Automated state fixtures + Android force-stop |
| UX | 20+ Screens, RTL, Color Assist, Reduce Motion, Safe Area, Alerts | Screenshot diff + Manual QA |
| Audio | Crossfade timing, focus interruption, slider persistence, mute | Android runtime/audio logs + review سمعي |
| Firebase | Null adapter, no network, opt-in, sanitized events, plugin compatibility, Spark-only | Integration test + SDK dependency audit |
| Release | APK manifest portrait/ABI/minSDK/targetSDK, install, cold start, touch, memory, crash | GitHub Actions + `agentctl` + ADB/Appium device gate |

### Toolchain and ownership

- `agentctl status`, `agentctl smoke <agent>`, `agentctl touch <agent>`, و`phone-queue` تظل البوابات المشتركة للوكلاء بعد تحديث اختبار APK إلى اللعبة الفعلية. اسم الـPackage/Test Scene يتغير عند الانتقال إلى GDScript؛ لا يُفترض أن Smoke السابق يغطيه من دون تحديث.
- بناء Android على GitHub Actions باستخدام نسخة Godot Standard + Export Templates مثبتة، وليس الاعتماد على مساحة تخزين Termux أو تنفيذ Build ثقيل على الجهاز.
- يسمح بPython لأدوات Static Asset Checking وSeed Batch والتحليلات (ليس منطق اللعبة runtime). إضافات GUT أو gdUnit4 لا يعتمد منها إلا واحدة بعد اختبار النسخة والترخيص. `gdformat` و`gdlint` يتطلبان توافقًا مع نسخة GDScript المثبتة، والاختبار الفعلي أهم من مجرد وجود اسم الأداة في YAML.
- لا أدعي اختبارات Property/Golden/Godot Editor منفذة الآن؛ تُكتب في تذاكر وتُغلق بالأدلة.

## 5. سجل مخاطر مؤسسي — Risk Register 1.3

**المعيار:** Probability P(1–5) × Impact I(1–5) = Priority score. المالك مسؤول عن قبول المخاطر، الوكيل منفذ وقائي. تُراجع المخاطر عند كل Gate، وتُضاف Actual Evidence / Next Action / Status.

| الخطر | P×I | العلامة المبكرة | التخفيف | نقطة إيقاف التسليم |
|---|---:|---|---|---|
| فقد نتيجة Save أو corrupt migration | 3×5=15 | تفاوت snapshot/checksum، مراجعات المستخدم | double snapshots + corruption tests | أي حالة ضياع تقدم متكررة P0 |
| FPS/بطارية سيئة بسبب مؤثرات زجاجية | 4×4=16 | p95 يتجاوز الميزانية، سخونة | Compatibility-first، قوالب رسوم منخفضة، scene profiling | تدهور دائم في Low tier |
| Puzzle generator ينتج مستوى مستحيل | 3×5=15 | solver timeout أو لا certificate | certify offline وfallback levels | مستوى منشور غير مثبت قابلية الحل |
| تضارب GDScript State/Undo مع Circuit | 4×4=16 | hash mismatch بعد undo | deterministic command architecture | State corrupt |
| اعتماد Firebase Spark على خدمة غير مجانية | 3×5=15 | مطالبة Billing، ربط Cloud Project | Spark-only allowlist + finance guard | قبل إضافة الخدمة/SDK |
| Crashlytics لا يرى أخطاء GDScript | 4×3=12 | تجربة Error غير مرصودة | explicit domain reporting + local logs | إعلان قدرة رصد وهمية |
| فقد العمل بسبب حذف ملفات C#/Git | 3×5=15 | تعديل main أو غياب branch baseline | safe fresh branch + archive + backup | أي حذف غير قابل للتراجع |
| شفافية الخصوصية أو Consent غير سليم | 3×5=15 | Analytics قبل الخيار أو نص مبهم | default-off + audit legal before Beta | إيقاف Firebase telemetry |
| أصول/موسيقى لا تسمح الاستخدام التجاري | 4×5=20 | license unknown | registry + legal QA | لا merge/لا Release |
| شاشة RTL أو UI لا تصل للإبهام | 4×3=12 | clipping، tap misses | golden/screens device testing | شاشة رئيسية أو زر أساسي غير قابل للنقر |
| اضمحلال جودة الأصول بين الفصول | 3×4=12 | اختلاف shaders/line width | visual bible/design tokens | مراجعة بشرية مطلوبة |
| تنزيل Godot/Gradle upgrade يكسر APK | 3×4=12 | import/renderer failures | engine lock + canary/rollback | ممنوع merge دون device gate |
| الهاتف لا يتصل بـ ADB بعد reboot | 4×3=12 | offline/stale port | watchdog آمن + تنبيه، بدون raw scan | اختبارات الجهاز لا تعتبر Passed |
| ضغط العمل يتجاوز المتاح | 4×4=16 | tickets ضخمة ومراحل لا تنتهي | scoped gates + 8h planning | freeze وtrim scope |
| خلط بيانات Firebase QA مع المستخدمين | 3×3=9 | events خاطئة | separate app flags/project when available | metrics مضللة تمنع حكم النجاح |
| مشاكل أذونات وإعدادات Android متعددة | 3×4=12 | build/install fails API 24/30/36 | device matrix + manifest checks | release gate fails |
| فقد حقوق اسم/أيقونة قبل متجر | 3×4=12 | نتائج علامة مشابهة | search trademark قبل النشر | لا تعتمد الاسم للمتجر دون فحص |
| لا بيانات فعلية لنجاح اللاعب | 3×3=9 | نجاح فني فقط | curated playtest + usability studies | Beta ليست دليل متعة |

## 6. المراقبة ومقاييس النجاح

### Measures — تقارير وليس ادعاءات

| Metric | التعريف | قرار بوابة الاختبار |
|---|---|---|
| Crash-free sessions | النسبة في عينات Telemetry التي تسمح سياساتها بالجمع | هدف beta ≥99.5%؛ لا نسبة مزعومة قبل العينة |
| Puzzle pass rate | مستويات المحتوى المعتمد التي يثبت solver حلها / جميع المستويات | 100% قبل الشحن |
| Save-recovery pass | اختبارات kill/corrupt/interrupted write الناجحة / المختبرة | 100% على مصفوفة الاختبار |
| Tutorial clarity | نسبة إكمال أول خمس مستويات بين عينة جديدة | هدف مراجعة ≥80%، يُقاس بالخصوصية وموافقة المستخدمين |
| First-touch success | taps الصحيحة / محاولات محددة في usability test | تحليل احتكاك اللمس وليس الانطباع |
| Unwanted Ads | ظهور إعلان مفروض في Gameplay | صفر في MVP/Beta |
| App boot offline | بداية لعبة ناجحة في وضع طيران | 100% في مصفوفة الأنظمة المختبرة |
| Frame time p95 | زمن عرض الإطار على OPPO Low tier | ≤33.3ms هدف أولي يتطلب Device Proof |
| A11y / AR defects | clipping, color ambiguity, motion issues | صفر عيب مانع في شاشات MVP |
| Asset copyright status | أصول معتمدة ترخيصيًا / أصول مستخدمة | 100% قبل نشر Release Candidate |

### Incident response

P0 Lost progress/boot blocked/forced crash → Stop release, reproduce via seeded logs, hotfix branch, regression test, accept only with user approval. P1 gameplay rule/blocked level → disable future distribution of that level when possible without breaking save; forward patch. P2 audio/visual/occasional layout → prioritized fix; P3 polish. Weekly Beta report includes issue IDs, root cause, metrics denominators, privacy status, build reproducibility, and two top priorities.

## 7. تحديثات المحرك والأمن

- مراجعة Godot/SDK/Addons شهريًا وعلى تنبيه أمني، لكن لا Auto Update على main.
- كل Upgrade بمستند ADR، مقارنة release notes، حفظ build baseline وsave fixtures، branch isolated، same-version export templates، build APK، Android device test، offline/consent tests، Screenshot/Animation regression وRollback plan.
- لا upgrade أثناء Freeze قبل Beta إلا ثغرة مهمة أو crash مانع؛ الرجوع عبر source/engine pin لا يفترض قابلية downgrade لبيانات اللاعب دون migrations.
- مكتبة Firebase Android تُثبَّت عبر Android BoM متوافق بعد مراجعة Plugin/Gradle وإصدار Godot، وموافقة owner على إذن `INTERNET`; يُراجع أثر SDK على minSdk/targetSdk/ABI.

## 8. المخاطر التنظيمية التي لا يسمح بتجاهلها

- إصدار Signing Key / Developer account / App Store marketing **مؤجل للنشر** وليس تذكرة MVP. التوقيع Debug ينتمي للبناء العادي ويختلف عن أسرار Upload/Release.
- Firebase project/account يحتاج مالك المستخدم يهيئه أو يوافق على الربط؛ CI لا يحتوي credential مفبركة ولا Admin Secrets ولا يقفز لحساب مدفوع.
- لا وصول الوكيل إلى الموبايل مباشرة إلا عبر البيئة المصرح بها؛ أدوات Device تستخدم lock، ولا تعطيل Termux services أو إعادة اكتشاف منافذ عبر آلاف محاولات غير آمنة.
- قياس المتعة والقبول القانوني والتراخيص يتطلبان مراجعة بشرية عند كل Release Gate، حتى لو أتم الوكيل آلاف اختبارات Unit.

## Current gate reconciliation — ADR-0006

See [00-START-HERE.md](00-START-HERE.md#current-accepted-checkpoint--2026-11-03) for the accepted PR15 checkpoint and owner-reported 10/10 device QA. Earlier gate-specific instructions are historical scope, not permission to restart those gates. Current task is CI/documentation/merge readiness only; no gameplay, phone operations, merge or G5 implementation. Godot 4.7.2 Standard / Compatibility remains pinned. Firebase is future optional Spark-only; no SDK/billing/signing changes. No new agent-run runtime or durability claim.
