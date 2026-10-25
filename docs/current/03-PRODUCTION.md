# LAYER SORT — خطة الإنتاج والتسليم والتحويل الآمن

> **الملف:** `docs/current/03-PRODUCTION.md` | **المصدر:** LS-MASTER-1.3 — مقتطع حرفيًا من الحزمة المعتمدة دون تغيير في القرارات.
> **المحتوى:** بوابات التنفيذ G0–G9 ونقل المشروع القديم وخط إنتاج الأصول وقائمة البدء ورسالة الوكيل.
> **بادئة المعرّفات عند الإشارة من ملف آخر:** `PLAN-` (مثال: بوابة G0 تُكتب `PLAN-G0`) لتجنب تكرار المعرّفات بين الملفات.
> **ملفات `docs/current/`:** `00-START-HERE.md` (قرارات مركزية) · `01-UX-ART.md` (واجهة وفن وصوت) · `02-ENGINEERING.md` (هندسة وFirebase ومخاطر) · `03-PRODUCTION.md` (بوابات وخطة وتسليم) · `04-AGENT-OPERATIONS.md` (وكلاء وQA) · `05-QA-TEST-CATALOG.md` (كتالوج اختبارات) · `06-SHIZUKU-TERMUX.md` (Shizuku اختياري)

**المعرف:** LS-PLAN-1.3 | **النطاق:** Android Portrait / Godot 4 GDScript / Firebase Spark ONLY

## 1. المسؤوليات وقاعدة إغلاق العمل

| الدور | مسؤوليات ملزمة | غير مفوّض له |
|---|---|---|
| مالك اللعبة | اعتماد الهوية والمحتوى وتجربة اللعب، اختيار الموارد، إصدار الإذن النهائي للدمج والنشر والحسابات | ليس مطلوبًا منه إصلاح أخطاء برمجية يدويًا كان بإمكان الوكيل فحصها |
| ChatGPT | تحديد عقود الأنظمة، مراجعة اتساق الوثائق، تقدير المخاطر، مراجعة قبول التصاميم وPRs وفق الأدلة | لا يدعي اختبارات لم يشغّلها ولا يعمل على هاتف لا يملك الوصول له |
| OpenCode / Codex | تطوير GDScript نظيف، Tests/CI/APK/Appium، حفظ السجلات، PRs صغيرة، التوثيق وتسليم الأدلة | لا ينشر، لا يحذف main/سجلات Git، لا يغير خدمات الهاتف أو حساب Firebase/الفوترة دون إذن |

**قاعدة المراحل:** 8 ساعات/أسبوع افتراضية للتخطيط وليست موعد تسليم، 3–15 ساعة ممكنة؛ المرحلة تُقفل بالوظيفة+جودة+اختبارات، لا بانتهاء أسبوع. لا تذكرة تتجاوز جلسة مراجعة كبيرة إلا بتقسيمها إلى مخرجات واضحة.

## 2. بوابات التنفيذ المعتمدة

| Gate | العمل المطلوب | شروط اكتمال محددة |
|---|---|---|
| G0 — Git Safe Reset | فرع GDScript جديد وتوثيق ملفات C# التي ستزال، عدم لمس main | Git status واضح، baseline محفوظ، diff مراجَع، لا secrets |
| G1 — Native Android Smoke | Godot Standard 4 + GDScript شاشة Portrait بسيط، Compatibility renderer مبدئيًا، APK عبر GitHub Actions | APK يثبت ويفتح على OPPO؛ Appium screenshot/tap؛ no crash/black screen؛ no C# runtime dependency |
| G1.5 — Agent Orchestration & QA Tooling | وكلاء OpenCode للمشروع، سكربتات QA وكتالوج اختبارات، جرد اعتماديات، فحص Shizuku اختياري | roster وصلاحيات موثقة، workflowان عاملان على الأقل، اختبارات سالبة متعمدة، لقطة شاشة محللة، حالة Shizuku، بلا G2 وبلا تغيير main/خدمات الهاتف |
| G2 — Core Rules | tube model، select/destination، pour batch، invalid action، win، atomic undo/restart، test scene | Unit/property cases تشمل full/empty/invalid/partial/undo، headless PASS، واجهة بسيطة قابلة للعب |
| G3 — UX & Persistence | Splash/Home/Level Map/Game/Pause/Win/Settings/Error، Arabic/English، Save/Resume، 5 دروس، 20 مستوى | مخرجات UX Goldens معتمدة، Force Stop recovery، 20 مستويات حل قابل للتحقق، no stuck state |
| G4 — Vertical Slice Art | Glass 2.5D وLiquid shaders، Pour/Win VFX، Audio cues، Color Assist، low/high tiers | صور ومقاطع مقارنة، OPPO Low tier p95 ضمن الهدف، لا ضرر للتنقل/اللمس |
| G5 — Circuit Proof | Sensor/latch/lock، tutorial level 20، undo/canonical solver | حل معتمد، وحدة تعلم 20–23، حالات Undo/Save/Firebase-off متوافقة |
| G6 — Procedural Content | Level generator/solver/certificates، difficulty curve، visual QA editor | Duplicate filter، bounded search، catalog version، curated teaching levels، اختبار N seeds |
| G7 — Expansion | Frozen ثم Shift ثم Connected ثم Hybrid مع مستويات Classic بينهما | لكل mechanic عقد، unit/property tests، تعليم/Audio/Icon، playtest، لا دمج 3 أنظمة مبكرًا |
| G8 — Firebase + Beta | Firebase Spark فقط، Android adapter/Noop، Consent/Privacy، Crash/Analytics test، واجهة القانون والشكر | SDK free-plan audit، offline pass، Crash sample قابل للرصد، Golden A11y، zero P0 issues |
| G9 — Store لاحقًا | Release Signing، حساب مطور، AAB، التوافق والسياسة القانونية، إعلانات اختيارية إن اعتمدت | **مؤجل حاليًا**، لا تنفيذ ولا إنشاء حساب قبل إذن المالك |

**مبدأ التسليم:** يمكن إنشاء نسخة Playable داخلية قبل اكتمال Circuit وFirebase، لكنها **ليست** Release/Beta على أنها مكتملة.

**حالة G1.5 بقرار المالك (2026-10-25): ACCEPTED WITH KNOWN LIMITATIONS، وليس PASS لكل الاختبارات.** `G15-QA-001` مفتوحة مع متابعة واحدة محدودة في `05-QA-TEST-CATALOG.md`. Shizuku موثقة من المالك في Termux الأصلي بصفة `uid=2000(shell)` فقط؛ جسر Debian وQA غير متحققين. لا دمج PR #1 أو PR #2 قبل مراجعة الفروق والأسرار وCI وترتيب الدمج وموافقة المالك الصريحة. لا بدء G2 قبل إذن منفصل وعقد قواعد `04-RULES-CONTRACT.md` معتمد.

## 3. نقل المشروع القديم دون خسارة أي شيء

1. الوكيل يراجع `git status`, current branch, commits, tags, remotes, CI current workflow دون فتح المشروع المرجعي GPLv3.
2. يسجل نقطة مرجعية `C# spike` ويحتفظ بالفرع `spike/godot-csharp-android` وأثر بناء `39987827578`. لا إعادة كتابة التاريخ أو force push.
3. ينشئ فرعًا نظيفًا باسم `feat/gdscript-foundation` ولا يستخدم ترحيل C# آلي إلى GDScript دون مراجعة قواعد مفاهيم المشروع.
4. ينقل ملفات البنية غير المرتبطة بـC# الضرورية فقط (CI/README/tests scripts بآخر نسخ)، ويحتفظ ببيئة Termux/Appium/ADB الآمنة الموجودة بدلاً من هدمها.
5. ينشئ `project.godot`, `main.tscn` و`boot.gd` في Godot Standard ويثبت Portrait Android وRenderer مع Export Presets مطابقة، ثم APK Smoke.
6. **بعد نجاح G1** يراجع قائمة حذف مجلدات C# من **الفرع الجديد فقط** مع Diff؛ الملفات القديمة لا تعود للتطبيق المنتج، لكن تظل قابلة للاستعادة من تاريخ Git. لا حذف `docs/` القديمة قبل نقل المعرفة المؤكدة وفهرسة الأرشيف.
7. إن فشل G1 يعود آخر commit ناجح دون تعديل خدمات الهاتف أو main؛ تقرير Root Cause قبل نسخة جديدة.

**ممنوع إجراء حذف شامل من هاتف المستخدم بواسطة أوامر `rm -rf` أو حذف الـGit repository لإعادة البدء.** وجود نسخة قديمة لا يضر إذا كانت معزولة؛ الحذف بلا Backup مصدر خطر غير لازم.

## 4. إنتاج الرسومات والصوت — Asset Pipeline

```text
Approved Art Brief / Visual Bible
  → Mood board (reference only, no copied game graphics)
  → Original source asset (SVG / layered raster / procedural shader / custom Blender)
  → License+author+tool provenance registry
  → Low & High exports with DPI / atlas / compression presets
  → Godot scene / Theme integration
  → Android screenshot/video capture
  → Compare readability / frame-time / memory / sound sync
  → Owner aesthetic review
  → Merge as asset_id-approved
```

**لا نعتمد على مولد الصور وحده:** صورة AI قد تكون عالية الدقة لكن غير صالحة كعنصر تفاعلي؛ يجب تقطيعها وتنظيفها وإعادة بنائها كأصل يمكن ربطه بالأحداث. تُصمم أنابيب شفافة من layers مستقلة، Liquid surface قابل للتمدد دون Blur ثقيل، وCircuit line shader يرسم من بيانات المستوى، لا PNG بأسلاك ثابتة تعارض التنقل.

**لكل أصل:** SOURCE + LICENSE + ATTRIBUTION + AUTHOR + HASH + USED_BY + SCREENSHOT + QUALITY_TIER. علامات `pending/approved/rejected`؛ أي أصل pending لا يدخل Beta.

**جودة الصوت:** يمسح background music عند التوقف ويُطبق volume persistence، الموسيقى الثلاثية تعبر crossfade يتبع نسبة الوقت الفعلي، SFX لا تتراكب بمستوى صاخب، ولا تفقد نتيجة حركة إذا الجهاز في وضع صامت. Playback pipeline يختبر `audio focus lost/gained`.

## 5. Firebase Spark — بوابة الدخول إلى Beta

- حساب Firebase يخص المستخدم ويُهيَّأ يدويًا أو بإذنه؛ Spark free ومن دون Credit Card/Billing Link.
- Core Domain مستقل عن الشبكة. Android Native Adapter فقط خلف interfaces، والنسخة الداخلية تستبدله بـNoop.
- نختبر وصول Crash/Nonfatal محدد إلى Crashlytics بدل الادعاء بالتغطية الكاملة لأخطاء GDScript.
- Analytics يبقى Off حتى تكتمل سياسة الخصوصية ونموذج consent المناسب؛ في Offline/رفض المشاركة لا ترسل بيانات وتظل اللعبة قابلة للعب.
- Remote Config يغيّر فقط toggles/محتوى آمن محدد، ولا يحمل كودًا تنفيذيًا ولا يعطّل مستويات مستخدم حالي، وdefaults المحلية صالحة دائمًا.
- App Distribution خيار تجريبي إن توافقت الأداة والحساب، وإلا روابط APK من GitHub Actions للـTesters المصرح لهم.
- لا ضمان استمرار تخزين أو خدمة تجاوزت الحصة المجانية؛ نضع حالات `disabled/quota_exceeded` ونراجع الحصص شهريًا.

## 6. سلسلة التسليم والتجربة

**PR Template** يجب أن يذكر: Scope IDs، commit، screenshots before/after، Android build link، Test outputs، Android install/touch/logcat، Accessibility AR/EN، Save behavior، License impact، Firebase plan impact، Performance impact، Rollback. لا قبول `works on my machine` بلا صور/سجلات.

**كل Stage:** يختبر 3 أنماط فشل كحد أدنى: (1) input غير صالح أو نقرات متزامنة، (2) app kill أثناء الحركة أو الحفظ، (3) وضع طيران وغياب Firebase. وأي إضافة ميكانيكية لها suite خاص به يشمل undo وsolver وrepro seed.

**Playtest:** 3–5 أشخاص خارجيين على الأقل في أول جولة فهم، ثم جولات أكبر حسب القدرة قبل Beta؛ لا يدّعي حجم عينة إحصائي كافٍ بمجرد نجاح عدد قليل. نسجل أين فشل الفهم أو ازداد الاستخدام غير المرغوب للتلميح، ونعدل onboarding/levels بدل إضافة صعوبة بلا تحليل.

## 7. القائمة الأساسية قبل بدء التطوير — Final Start Checklist

- [x] Android + Portrait + Godot GDScript متفق عليها تصميميًا.
- [x] مراحل الميكانيكيات وتجربة Offline وR11 موثقة.
- [x] Firebase Spark فقط وتوقيع نشر مؤجل موثقان.
- [x] UX Art/Audio target specs وRisk Register وطرق الرصد موثقة.
- [ ] أول محرك Godot Standard وExport Templates مثبتان برقم إصدار فعلي بعد smoke.
- [ ] فرع GDScript جديد وCI Android يعملان.
- [x] G1.5 — وكلاء/QA/أدوات **مقبولة من المالك بقيود موثقة** (2026-10-25؛ ليست جميع الاختبارات PASS). G2 ما زالت تحتاج تفويضًا منفصلًا.
- [ ] UI/Glass/Sound assets موجودة فعلًا ومراجعة من المالك.
- [ ] Firebase project Spark وخدماته موصولة ومختبرة لاحقًا، بعد الموافقة.
- [ ] اختبارات محتوى/حلّال/حفظ/Android/RTL حقيقية ومصحوبة بأدلة.
- [ ] حساب متجر/Signing رسمي — **غير مطلوب الآن إطلاقًا**.

## 8. رسالة جاهزة إلى OpenCode (لا تُشغّل دون إرفاق كل الملفات الحالية)

> Read every file under `docs/current/` beginning with `00-START-HERE.md`; this v1.3 replaces earlier Landscape/C# proposals. Implement Godot 4 Standard + Typed GDScript for Android Portrait only, offline-first, with Firebase Spark-only as a later optional native adapter. Do not create billing, production signing, stores, ads or paid APIs. Do not modify protected main. Keep the historical C# spike in Git history but develop the production app on a clean GDScript branch. Start with G0/G1 only: inspect repo, record baseline, create new branch, pin Godot standard/export templates, build APK with Actions, install and test on the already connected phone via agentctl/phone-queue/Appium, capture screenshot and logcat, then deliver commit, PR, build link, device evidence, exact unresolved blockers. Do not claim tests passed unless tool logs prove them. Never touch GPLv3 reference code during implementation.

## 9. ما زال يحتاج إثباتًا، وليس سؤال تصميم جديدًا

1. نسخة Godot Standard المناسبة على CI وهاتف OPPO والـRenderer الفعلي.
2. ملكية `applicationId` النهائي لم تُحسم للنشر؛ نستخدم معرف Debug محليًا لا يتسبب بتعارض مع النسخة التجريبية القديمة.
3. أرقام FPS وRAM وحجم APK وفترة start لا تُعلن محققة قبل Instrumentation.
4. توفر ترخيص كل صورة وصوت وخط في تاريخ جمعها.
5. قواعد خصوصية/أعمار المستخدمين والبلدان عند Beta والنشر، وتوافق إضافة Firebase Native.
6. ملاءمة التدرج الفكري بعد جولات Playtesting، وليس بمجرد وجود Solver.

هذه **بوابات تحقق تشغيلية** وليست مبررًا لتأخير بدء GDScript Core؛ الخطة تعتمد المبدأ وتترك الأرقام لتجربة موثقة.
