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

> **Historical authorization scope:** G1/G1.5/G2 permission and startup statements below describe their original dated gates, not current authorization. Later owner-authorized ADRs (including [ADR-0006](../adr/ADR-0006-g4-checkpoint-acceptance.md)) control subsequent project decisions. AGENTS operating constraints remain in force. The entry point is [00-START-HERE.md](00-START-HERE.md). No historical gate text restarts implementation or grants merging permission.

## 2. بوابات التنفيذ المعتمدة

| Gate | العمل المطلوب | شروط اكتمال محددة |
|---|---|---|
| G0 — Git Safe Reset | فرع GDScript جديد وتوثيق ملفات C# التي ستزال، عدم لمس main | Git status واضح، baseline محفوظ، diff مراجَع، لا secrets |
| G1 — Native Android Smoke | Godot Standard 4 + GDScript شاشة Portrait بسيط، Compatibility renderer مبدئيًا، APK عبر GitHub Actions | APK يثبت ويفتح على OPPO؛ Appium screenshot/tap؛ no crash/black screen؛ no C# runtime dependency |
| G1.5 — Agent Orchestration & QA Tooling | وكلاء OpenCode للمشروع، سكربتات QA وكتالوج اختبارات، جرد اعتماديات، فحص Shizuku اختياري | roster وصلاحيات موثقة، workflowان عاملان على الأقل، اختبارات سالبة متعمدة، لقطة شاشة محللة، حالة Shizuku، بلا G2 وبلا تغيير main/خدمات الهاتف |
| G2 — Core Rules | tube model، select/destination، pour batch، invalid action، win، atomic undo/restart، test scene | Unit/property cases تشمل full/empty/invalid/partial/undo، headless PASS، واجهة بسيطة قابلة للعب |
| G3 — UX & Persistence + Classic content | Splash/Home/Level Map/Game/Pause/Win/Settings/Error، Arabic/English، Save/Resume، خمس دروس Classic قصيرة 1–5، Classic سهلة 6–10 وأصعب تدريجيًا 11–14 | مخرجات UX Goldens معتمدة، Force Stop recovery، مستويات Classic 1–14 قابلة للحل، no stuck state؛ **ليس** إغلاق MVP ذي 20 مستوى قبل G5 |
| G4 — Vertical Slice Art | Glass 2.5D وLiquid shaders، Pour/Win VFX، Audio cues، Color Assist، low/high tiers | صور ومقاطع مقارنة، OPPO Low tier p95 ضمن الهدف، لا ضرر للتنقل/اللمس |
| G5 — Automatic Layer Circuit Proof + 20-level MVP completion | Sensor/latch/lock، أول درس Circuit بسيط في مستوى 15، و16–20 تطوير تدريجي مع Classic عادية؛ undo/canonical solver | حل معتمد، محتوى 15–20 قابل للحل وحالات Undo/Save/Firebase-off متوافقة؛ لا إعلان اكتمال MVP 1–20 قبل قبول G5 |
| G6 — Procedural Content | تطوير Circuit وClassic العادية حتى 29 (بعد مستويات MVP 16–20)، Level generator/solver/certificates، difficulty curve، visual QA editor | Duplicate filter، bounded search، catalog version، مستويات تعليمية مراجعة يدويًا، مستويات 21–29 قابلة للحل، اختبار N seeds؛ لا تفعيل ميكانيكية ثانية جديدة هنا |
| G7 — Expansion | أول Frozen في 30، أول Layer Shift في 45، أول Connected Tubes في 60، ثم تركيبات تدريجية مع Classic عادية؛ ميكانيكية جديدة واحدة كل مرة | لكل mechanic عقد ودرس بسيط قبل التركيبات، unit/property tests، تعليم/Audio/Icon، playtest، لا جمع ميكانيكيات جديدة مبكرًا |
| G8 — Firebase + Beta | Firebase Spark فقط، Android adapter/Noop، Consent/Privacy، Crash/Analytics test، واجهة القانون والشكر | SDK free-plan audit، offline pass، Crash sample قابل للرصد، Golden A11y، zero P0 issues |
| G9 — Store لاحقًا | Release Signing، حساب مطور، AAB، التوافق والسياسة القانونية، إعلانات اختيارية إن اعتمدت | **مؤجل حاليًا**، لا تنفيذ ولا إنشاء حساب قبل إذن المالك |

**مبدأ التسليم:** يمكن إنشاء نسخة Playable داخلية قبل اكتمال Circuit وFirebase، لكنها **ليست** Release/Beta على أنها مكتملة.

**ADR-0003 (تفويض المالك 2026-10-25):** بدأ تنفيذ G2 Classic فقط في فرع مستقل؛ لا اعتماد G2 ناجح قبل نتيجتي QA منفصلتين: (A) قواعد headless/CI/APK provenance، و(B) تثبيت/لمس/Undo/Restart/Win على هاتف OPPO مع foreground/لقطات/logcat. لا تُستنتج نتيجة الجهاز من CI، ولا يُغلق `G15-QA-001` بهذا الاختبار.

**ADR-0002 (قرار المالك 2026-10-25):** 20 مستوى هي إجمالي Core MVP 1–20؛ الدروس Classic في 1–5 فقط وليست المستويات 1–19 كلها. G3 يكمل 1–14 Classic، وG5 يبدأ Circuit في 15 ويكمل 15–20 قبل اعتماد MVP. لا تغيير تلقائي لنطاق G2 (Classic فقط)، ولا تصريح بتنفيذه أو بدمج PRs.

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

## 7. Current gate execution

The obsolete G0 checklist and one-time bootstrap prompt were moved to [the indexed archive](../archive/G0-START-INSTRUCTIONS.md). Current acceptance and limits are defined in [00-START-HERE.md](00-START-HERE.md#current-project-state--2026-11-04); ADR-0006 remains the historical PR15 checkpoint record. Do not restart G0 or treat old unchecked start tasks as current blockers.

## 9. ما زال يحتاج إثباتًا، وليس سؤال تصميم جديدًا

1. نسخة Godot Standard المناسبة على CI وهاتف OPPO والـRenderer الفعلي.
2. ملكية `applicationId` النهائي لم تُحسم للنشر؛ نستخدم معرف Debug محليًا لا يتسبب بتعارض مع النسخة التجريبية القديمة.
3. أرقام FPS وRAM وحجم APK وفترة start لا تُعلن محققة قبل Instrumentation.
4. توفر ترخيص كل صورة وصوت وخط في تاريخ جمعها.
5. قواعد خصوصية/أعمار المستخدمين والبلدان عند Beta والنشر، وتوافق إضافة Firebase Native.
6. ملاءمة التدرج الفكري بعد جولات Playtesting، وليس بمجرد وجود Solver.

هذه **بوابات تحقق تشغيلية** وليست مبررًا لتأخير بدء GDScript Core؛ الخطة تعتمد المبدأ وتترك الأرقام لتجربة موثقة.

## Historical G4 checkpoint reconciliation — ADR-0006

See [00-START-HERE.md](00-START-HERE.md#current-accepted-checkpoint--2026-11-03) for the accepted PR15 checkpoint and owner-reported 10/10 device QA. Earlier gate-specific instructions are historical scope, not permission to restart those gates. At that dated checkpoint the task was CI/documentation/merge readiness only, with no gameplay, phone operations, merge or G5 implementation authorized. That acceptance alone did not prove integration or a 20-level MVP. G4 has since been integrated and accepted; current G5 acceptance and planning scope are recorded below.

**Protected-main integration:** the previous blanket main-policy decision gate is superseded by [ADR-0007](../adr/ADR-0007-protected-main-owner-authorized-agent-merge.md). No direct main pushes. Reviewed PRs, passing required CI, no unresolved blocking comments and explicit owner authorization for each PR/head SHA/target/intended changes are prerequisites for agent merge execution. No actual merge is authorized by this production plan or the current documentation task.

## Current G5 acceptance and planning gate — 2026-11-04

- G4 is integrated and accepted at PR18 merge `144c744b92c3e66f71ad44a0d5b962121c72bba1`; its earlier acceptance evidence above is preserved.
- G5-P1 Level15 is accepted by owner-reported physical-device QA **12/12 PASS**.
- G5-P2 Levels16–17 at `6e3f10f8a3fec017aed756d96e69471eb3da238d` are **ACCEPTED — OWNER-REPORTED PHYSICAL DEVICE QA**, dated 2026-11-04: **13/13 PASS**, zero reported failures. [All 13 groups and limitations](../G5_P2.md#owner-reported-physical-device-qa-acceptance--2026-11-04). This is not independent agent device QA, performance benchmarking or logcat inspection; automated CI is recorded separately.
- G5-P3 implementation is now owner-authorized:18 Classic,19 Circuit,20 Classic, with no new mechanic. [Implemented content and verification gates](../G5_P3.md) are recorded; exact final-head CI evidence is on PR19. **Accepted by OWNER-REPORTED PHYSICAL DEVICE QA:12/12 PASS** at corrected checkpoint `8f3a49c1f84a982da060a06f9d47df02f249d0f3`; no agent phone testing or instrumented benchmark is claimed.
- G5-Final [P2 gameplay HUD/board and original audio cleanup](../G5_FINAL.md#11-g5-final-p2-gameplay-hud-board-and-audio) is owner-authorized. Broader polish, menu/map redesign and imports remain deferred pending owner review. G6 is not authorized. No new assets, shaders, animations, audio systems, dependencies, changes to accepted gameplay or save migrations are authorized by this bounded rendering slice. Existing rules contract stays Draft; G15-QA-001 stays OPEN.
- PR19 stays Draft on its existing branch and base. No merge is authorized; the 20-level Core MVP and full G5 gate remain incomplete until the applicable CI and owner device acceptance gates pass.
