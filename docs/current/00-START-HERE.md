# LAYER SORT — المصدر التنفيذي المعتمد

> **الملف:** `docs/current/00-START-HERE.md` | **المصدر:** LS-MASTER-1.3 — مقتطع حرفيًا من الحزمة المعتمدة دون تغيير في القرارات.
> **المحتوى:** القرارات المركزية (B01–B15) والإجابات الحاسمة والتصميم الملزم وخريطة المشروع.
> **بادئة المعرّفات عند الإشارة من ملف آخر:** `START-` (مثال: عند ذكر Q01 من هذا الملف اكتب `START-Q01`) لتجنب تكرار المعرّفات بين الملفات.
> **ملفات `docs/current/`:** `00-START-HERE.md` (قرارات مركزية) · `01-UX-ART.md` (واجهة وفن وصوت) · `02-ENGINEERING.md` (هندسة وFirebase ومخاطر) · `03-PRODUCTION.md` (بوابات وخطة وتسليم) · `04-AGENT-OPERATIONS.md` (وكلاء وQA وحدود الأتمتة) · `05-QA-TEST-CATALOG.md` (كتالوج اختبارات ومعايير تقارير) · `06-SHIZUKU-TERMUX.md` (Shizuku اختياري وغير جذري)

**المعرف:** LS-MASTER-1.3 | **تاريخ:** 24 أكتوبر 2026 | **الحالة:** قرارات معتمدة؛ حالة التنفيذ الحالية أدناه وفق ADR-0006 | **اللغة:** العربية (مصطلحات التنفيذ بالإنجليزية)

> **حكم الوثيقة:** الوثائق داخل هذه الحزمة هي المصدر الوحيد النشط للقرارات الجديدة. أي ملف سابق يحمل Landscape أو C# بوصفهما الاختيار النهائي، أو يفترض خدمات Firebase مدفوعة أو توقيع نشر فوري، أصبح ملغى. المستندات القديمة والنسخة التجريبية C# مراجع تاريخية لا تُنسخ منها قواعد اللعب. الموافقة على التصميم لا تثبت تنفيذًا أو نجاح اختبار، ولا تمنح الوكيل حق الإنفاق أو النشر أو دمج main.
>
> **سجل تفويض تاريخي، وليس نطاق العمل الحالي:** القيود الزمنية في الفقرات التالية تُقرأ مع ADR-0003..0006 والتفويض الحالي أدناه.
>
> **بوابة G1.5 (تفويض المالك — 24 أكتوبر 2026):** بوابة تشغيل مؤقتة بين G1 وG2 لأتمتة الوكلاء وQA والأدوات وفحص Shizuku الاختياري، منظمة في `04-AGENT-OPERATIONS.md` و`05-QA-TEST-CATALOG.md` و`06-SHIZUKU-TERMUX.md` و`docs/adr/ADR-0001`. لا تغيّر القرارات B01–B15، ولا تسمح ببدء G2 أو Firebase أو التوقيع أو أي خدمة مدفوعة. Shizuku اختياري ولا يمنح root، ولا يُنشأ جسر دائم أو صلاحيات موسعة دون موافقة منفصلة من المالك.
>
> **قرار المالك G1.5 (25 أكتوبر 2026): ACCEPTED WITH KNOWN LIMITATIONS.** قبول الأساس التشغيلي لا يعني نجاح جميع الاختبارات: `G15-QA-001` ما زالت OPEN (تراكب مكالمة خارجية على لقطة اللمس؛ ليست دليل عيب لعب). Shizuku موثق **بإفادة المالك** في Termux الأصلي `uid=2000(shell)` فقط؛ جسر Debian ودمجه في QA غير متحققين ولا يُنشآن ضمن هذه المرحلة. سياسات أوامر OpenCode لا تحل محل حماية Git وموافقة المالك. PR #1 وPR #2 بلا دمج؛ ترتيب دمجهما ومراجعة الفروق والأسرار وCI يحتاج موافقة صريحة. **G2 غير مفوضة بعد.** تفاصيل المتابعة في `05-QA-TEST-CATALOG.md` و`docs/G15_QA_REPORT.md`، وقرار المرحلة في `docs/adr/ADR-0001`.
>
> **قرار المالك لمسار المستويات (25 أكتوبر 2026، `docs/adr/ADR-0002`):** المستويات 1–5 فقط دروس Classic تفاعلية؛ 6–10 Classic سهلة بلا إرشاد إلزامي؛ 11–14 Classic أصعب تدريجيًا؛ 15 أول Layer Circuit تلقائية؛ 16–29 تطوير Circuit بالتناوب مع Classic عادية؛ 30 أول Frozen؛ 45 أول Layer Shift؛ 60 أول Connected Tubes؛ وبعدها مزج تدريجي مع استمرار Classic. ميكانيكية جديدة واحدة في كل مرة ودروس بسيطة قبل التركيبات المعقدة. لا تفويض بتنفيذ G2 أو دمج PRs بهذا القرار.
>
> **تفويض G2 منفصل (25 أكتوبر 2026، `docs/adr/ADR-0003`):** أذن المالك بتنفيذ نموذج Classic قابل للعب على Android مع اختبارات قواعد headless واختبار جهاز مستقل، على فرع `feat/g2-core-gameplay` فقط. التفاصيل غير الأساسية المحددة للنموذج قابلة للتغيير ولا تعني اعتماد عقد `04-RULES-CONTRACT.md` بالكامل. لا Circuit أو حفظ إنتاجي أو Generator في G2؛ لا إذن بدمج PRs أو بدء G3. `G15-QA-001` لا تزال مفتوحة.

## 1. القرار المركزي والإطار

| الرمز | القرار الملزم |
|---|---|
| B01 | اسم العمل Layer Sort (يُفحص توفر الاسم والعلامات قبل النشر). |
| B02 | Android فقط؛ Portrait ثابت على جميع الشاشات؛ مرجع تركيبي 720×1600، مع تخطيط مرن وSafe Area. |
| B03 | Godot 4 Standard وTyped GDScript؛ لا استخدام C# في المشروع المنتج؛ تثبيت نسخة محرك وقوالب Export بعد Smoke على جهاز OPPO. |
| B04 | إخراج 2.5D مرسوم عبر CanvasItem و2D shaders وخامات مرسومة بعناية؛ Compatibility Rendering خيار البداية للاختبار على OPPO، مع اختبار Mobile فقط إذا تفوق عمليًا. |
| B05 | Android ARM64 (`arm64-v8a`) في الإصدار الأول؛ حد Android الأدنى `minSdk 24` والهدف الموثق في Baseline السابق `targetSdk 36`، يُراجع عند إعداد Android Export وعند النشر حسب السياسة القائمة وقتها. ليس إعلانًا عن تحقق إعداد APK الآن. |
| B06 | Core Offline-first: لا اتصال ولا تسجيل دخول ولا إعلان مطلوب لبدء اللعب أو الفوز أو الحفظ المحلي. |
| B07 | Firebase **Spark فقط** دون إضافة Billing Account أو الترقية إلى Blaze أو استخدام خدمات تتطلب دفعًا؛ Crashlytics, Analytics, Remote Config، وApp Distribution لاحقًا وفق البوابة. الخدمات ليست شرطًا للعب، والتليمترية محكومة بالخصوصية. |
| B08 | التوقيع والإصدار الرسمي والمتجر بعد اكتمال المنتج؛ توقيع Debug ضروري تقنيًا لأي APK تطويري ولا يعني بدء إجراءات النشر. |
| B09 | المسار المعتمد في ADR-0002: دروس Classic التفاعلية 1–5 فقط؛ Classic سهلة بلا إرشاد إلزامي 6–10 ثم أصعب تدريجيًا 11–14؛ أول Circuit تلقائية في 15، وتتطور 16–29 بالتناوب مع Classic عادية؛ أول Frozen في 30، وأول Shift في 45، وأول Connected في 60. لاحقًا دمج تدريجي مع مستويات Classic عادية؛ ميكانيكية جديدة واحدة كل مرة ودروس بسيطة قبل التركيبات. |
| B10 | التوليد الإجرائي يمر عبر Solver وValidator وDifficulty Rating + Playtest؛ المستويات التعليمية تصمم/تراجع يدويًا، ولا يدخل مستوى غير مثبت القابلية للحل. |
| B11 | واجهة فاخرة واضحة بالعربية والإنجليزية، Color Assist، Reduce Motion، تناسق الأيقونات؛ أصول أصلية أو مرخصة مع إثبات المصدر. |
| B12 | الوقت متغير؛ نطاق 3–15 ساعة أسبوعيًا، 8 ساعات أساس تخطيطي، تطوير وفق معايير قبول لا مواعيد تقويمية صارمة. |
| B13 | مالك المشروع يعتمد القرارات ودمج التغييرات النهائية؛ ChatGPT مراجع هندسة وتصميم؛ OpenCode/Codex منفذ يرفع أدلة الاختبارات وPRs. |
| B14 | عدم تفعيل إعلانات أو IAP أو حساب Google Play أو وسائل دفع ضمن MVP؛ الاقتصاد والتسويق قرارات منتج مسجلة لكن التنفيذ مؤجل. |
| B15 | ممنوع نسخ شيفرة، عناصر رسومية، أو مقتطفات تنفيذ من المستودع المرجعي GPLv3؛ وثيقته الأصلية تاريخ تحليل منفصل ولا تُمرر للوكيل كمدخل تنفيذ. |

## 2. إجابات حاسمة على الفجوات المكتشفة — سؤال وجواب

### Q01 — ما الوثيقة الحاكمة عند التعارض؟
**الجواب المعتمد:** هذه الحزمة `v1.3` مقدَّمة على كل نص سابق. أي قرار جديد يمر عبر ADR برقم وتاريخ وصاحب اعتماد، ويحدث `00-START-HERE.md` وملف النظام المتأثر معًا. ممنوع للوكيل اختيار الأقدم بناءً على ترتيب فتح الملفات. **تحقق:** بحث CI عن Landscape/C#/Blaze في ملفات المتطلبات النشطة ورفض تناقض السياق.

### Q02 — هل نمسح مشروع C# القديم فورًا؟
**الجواب المعتمد:** **نبدأ مشروع اللعبة المنتج من الصفر داخل فرع GDScript جديد ونلغي استخدام C# كأساس**؛ لكن لا نحذف تاريخ Git ولا Branch التجربة الناجحة ولا إعدادات الاختبار. أولًا تُحفَظ نقطة مرجعية بالـCommit الحالي والـAPK، ثم ينشأ فرع `feat/gdscript-foundation` من قاعدة آمنة، وتُزال ملفات Godot .NET غير المطلوبة **من الفرع الجديد فقط** بعد التأكد من الملفات المراد حذفها، مع تقرير diff. لا force-push أو حذف main أو branch تجريبي إلا بموافقة منفصلة. **تحقق:** نجاح APK GDScript مستقل وCI، وإمكانية الوصول لتجربة C# تاريخيًا.

### Q03 — هل نزيل الوثائق القديمة؟
**الجواب المعتمد:** لا تُحذف فورًا؛ تُؤرشف خارج `docs/current/` وتُوسَم `SUPERSEDED` أو تُنقل إلى `docs/archive/` مع فهرس. يمكن تنظيف نسخ مكررة لاحقًا بعد التأكد من حفظ القرارات المهمة. لا تبقى نسخ قديمة ذات أولويات متعارضة متاحة للوكلاء كتعليمات نشطة. **تحقق:** ملف INDEX واحد، وحصر المرجعيات الموجودة في بنية المشروع.

### Q04 — هل اللعبة جاهزة للمشاركة لأنها نجحت سابقًا على الهاتف؟
**الجواب:** لا. نجاح عدّاد C# وADB/Appium أثبت البنية التحتية فقط، وليس GDScript أو اللعب أو التصميم الرأسي أو حفظ البيانات أو تكامل Firebase. كل مكوّن جديد له دليل اختبار منفصل.

### Q05 — إيه إصدار اللعبة الأول الذي نغلقه؟
**الجواب المعتمد (محدّث بـADR-0002):** `Core MVP` يحافظ على **20 مستوى إجمالًا (1–20)** وليس 20 درسًا أو 20 مستوى Classic خالصًا: 1–5 خمس دروس Classic تفاعلية قصيرة، 6–10 ألغاز Classic سهلة بلا إرشاد إلزامي، 11–14 Classic أصعب تدريجيًا، 15 أول Circuit تلقائية، و16–20 تطوير Circuit مع استمرار ألغاز Classic العادية. يشمل حفظًا محليًا وUndo وRestart ومحتوى قابلًا للحل وشاشة رئيسية وخريطة أساسية وإعدادات وأصوات واجهة مبدئية وصوت سكب وAndroid Portrait مع Color Assist واختبار رسومي. G3 يجهّز UX/الحفظ وClassic 1–14؛ G5 يثبت Circuit ويمكّن إكمال محتوى 15–20 قبل اعتماد MVP ذي 20 مستوى. الإصدار التجريبي Beta يشمل شاشات القانون والشكر والتشخيص وFirebase بالخصوصية والتراخيص والأصول المعتمدة؛ نشر المتجر والإعلانات والتوقيع الرسمي تأتي بعد ذلك.

### Q06 — ماذا يعني «جودة خرافية» قابل للاختبار؟
**الجواب المعتمد:** دقة ووضوح الطبقات والزجاج، اتساق اللوحة والخامات، استجابة لمس بلا لبس، نعومة إطارات مع تدرجات جودة، مؤثرات مكافأة نظيفة، صوت متزامن، إمكانية قراءة الرموز/الألوان وعدم قص النصوص على المقاسات المختلفة. لا يثبت ذلك بنعت بصري؛ يلزم لقطات مقارنة على OPPO، تقييم Playtest، مراجعة Art Director/المالك، وقياس frametime/ذاكرة. جودة Low ليست نسخة قبيحة: تحافظ على جودة التكوين مع تخفيف shader/particles.

### Q07 — إزاي نمنع التوسع اللانهائي في التخطيط؟
**الجواب:** Freeze لباب كل مرحلة بمجرد وجود قرارات كافية للتنفيذ. تذكرة جديدة لكل مجهول، مع أثره وماذا سيتوقف عليه. لا تضاف ميزة قبل إثبات Core Loop، ولا يتم تغيير Game Rules من أجل مؤثر بصري. القاعدة: **Build → Measure → Review → Improve**.

## 3. التصميم المعتمد للعب ونطاق الميكانيكيات

| النطاق | سلوك اللاعب | شرط الدخول | التلميح والـUndo |
|---|---|---|---|
| Classic | يختار أنبوب مصدر ثم هدف؛ تصب الكتلة العلوية المتجاورة ذات اللون الواحد بقدر السعة؛ الفوز إذا كل أنبوب فارغ أو ممتلئ بالكامل بلون واحد. | سعة موحدة داخل المستوى؛ اختيار المصدر غير الفارغ، الهدف الفارغ أو المطابق وغير الممتلئ؛ لا خسارة عشوائية. | Hint يشير لحركة صحيحة، ولا ينفذها؛ Undo يعيد آخر حالة **مع كل حالة ميكانيكية**. |
| Circuit | عقد استشعار لون علوي محدد تشغّل قفلًا معروفًا بصريًا. | أول طرح: تلقائي بعد **Commit منطقي للحركة** ويظل القفل مفتوحًا خلال المحاولة (latched). | يرجع القفل والحساس وحالة الطبقات عند Undo ضمن Snapshot واحد. |
| Freeze | ثلج واضح على أنبوب/طبقة يمنع إجراء محدد؛ إزالته مرتبطة بحساس واضح، ليست بعدد عشوائي من الثواني. | لا تُضاف قواعد جديدة ضمنيًا؛ وضع القفل مرئي قبل الضغط. | Undo يعيد التجمد إن ألغى فعل فتحه. |
| Shift | داخل أنبوب Shift خاص: تبديل طبقتين متجاورتين فقط، بعد تحديد اللاعب، بعدد فرص محدد في بيانات المستوى. | عملية لعبة مستقلة مسجلة في Undo؛ لا تغيير للألوان أو السعة. | Solver يجب أن يحسب Shift في الحالة/الأفعال قبل السماح بتوليد مستويات تستخدمه. |
| Connected | وصلة مرئية تحدد المسارات المتاحة؛ لا انتقال تلقائي للسائل في الإصدار الأول. | يحافظ النقل على قاعدة التوافق/السعة الأساسية إضافة إلى شرط الرابط. | تغيير حالات الرابط والأقفال يعمل ذريًا مع الحركة والتراجع. |

**الترتيب الرسمي للأحداث:** إدخال موحد → Validate → Commit state → Evaluate mechanics deterministic → Evaluate win/timeout → Snapshot/Save → Animation/Audio notifications. لا يجب أن يتسبب تأخر الرسوم المتحركة في تغيير نتيجة الحركة. المؤقت اختياري للمسار الرئيسي؛ لا يمكن لواجهة السكب أن تمنح فوزًا بعد تسجيل خسارة وقتية لنفس المعاملة.

**السعة والألوان الدقيقة** تُثبت داخل بيانات الفصل واختبارات اللمس؛ المستويات الأولى 4 وحدات/أنبوب و3–4 ألوان مع 1–2 أنبوب فارغ، ولا تتخطى واجهة هاتف 720px عددًا يهدد تمييز كل طبقة. كل مستوى يحفظ نسخة قواعد ثابتة. عند اتساع الفصول يُعدّل التوازن بالأدلة بدل استخدام أرقام مولد غير مفحوصة.

## 4. خريطة ملفات المشروع الجديدة

```text
LayerSort/
  project.godot
  assets/
    art/{tubes,liquid,backgrounds,icons,vfx,fonts}/
    audio/{music,sfx,ambient}/
    licenses/
  scenes/{boot,home,levels,game,dialogs,settings,about}/
  scripts/
    domain/{tube,level,board,move_rules,game_state,commands}/
    mechanics/{circuit,freeze,shift,connection}/
    generation/{generator,solver,validator,difficulty}/
    application/{game_session,history,level_catalog,save_coordinator}/
    ui/{theme,components,flow,accessibility}/
    presentation/{tube_view,pour_animation,vfx_coordinator}/
    audio/{audio_director,audio_focus}/
    platform/{firebase_adapter,noop_telemetry,diagnostics,share}/
  content/{levels,chapters,translations,config}/
  addons/                    # allowlisted only
  tests/{unit,property,generator,ui,device}/
  tools/{asset_check,level_batch,benchmarks}/
  docs/current/{00-START-HERE.md,01-UX-ART.md,02-ENGINEERING.md,03-PRODUCTION.md}/
  docs/archive/              # read-only superseded documents
  .github/workflows/
  ENGINE_VERSION.lock
```

**مبدأ الحجم:** Script مسؤول عن وظيفة واحدة؛ ملف GDScript إرشاديًا ≤300 سطر ودالة ≤40 سطر إلا لسبب موثّق في PR. الاعتماديات من UI إلى Application إلى Domain، وليس العكس؛ لا وصول إلى Firebase من قواعد لعبة خالصة، ولا استخدام عقد Scenes داخل Solver.

## 5. سياسة التغييرات والتحديثات

- ترقية Godot وPlugins ليست تلقائية: تثبيت `ENGINE_VERSION.lock` وقوالب تصدير مطابقة وفحص checksum وإصدار المحرك.
- ترقيات الإصلاح تمر عبر PR مع Release Notes واختبار Load/Save/Arabic/Visual/Android APK وRegression؛ ترقيات كبيرة تتطلب خطة ترحيل.
- لا تغييرات للمحرك/Gradle/SDK/Appium وADB متزامنة في PR واحد؛ منع التحسين الذي يكسر الجهاز المنتج.
- Crash/Firebase/Analytics مستقلون؛ لا تسجل أحداثاً قبل تحقق بوابة الخصوصية، وتبقى كل أحداث اللعب الأساسية محلية عند تعطيل الشبكة.

## 6. معايير الاعتماد النهائية

**لكل تسليم:** commit وbranch واسم الإصدار؛ Test report لكل قاعدة تمسها الميزة؛ Android APK مثبت بالفعل؛ Screenshot/Video للأحداث المرئية؛ FPS/Memory Baseline للأصول/المؤثرات؛ فحص لملفات الترخيص؛ أثر التحديث على الحفظ؛ وصف المخاطر ووسيلة رجوع؛ لا أسرار أو SDK مدفوع. عبارة PASS بلا تقرير ليست اعتمادًا.

**مصادر رسمية للحالة المتغيرة:** Firebase https://firebase.google.com/pricing ؛ Godot renderers https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html ؛ Android export https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html ؛ Firebase Spark https://firebase.google.com/docs/projects/billing/firebase-pricing-plans .

## Owner-authorized Optical Clarity slice

G4-B Phase 1 owner selection is recorded in `docs/adr/ADR-0004-optical-clarity.md`: one gameplay screen combines navy optical depth with precision/readability, subject to visual review before expansion. Existing gameplay and Android contracts remain authoritative.

## Current owner authorization — Real Game UI

ADR-0005 records the bounded Home/gameplay/Win presentation and Settings→About navigation refinement based on PR #14. Earlier dated gate statements describe authorization at their dates; they do not supersede this explicit later scope. Classic rules, save architecture and all prior evidence remain unchanged. G5/G6 and merging remain outside scope.

## Current accepted checkpoint — 2026-11-03

The single active entry point is [00-START-HERE.md](00-START-HERE.md). ADR-0006 records the owner's current acceptance; older dated scope restrictions describe their original gates and do not revoke later explicit authorizations.

PR #15 (`feat/real-game-ui`) at `c961972365258baa34cae279dfc10ab46edce2f7` is **ACCEPTED WITH MINOR NON-BLOCKING POLISH DEFERRED**. It remains Open / Draft against `feat/g4b-optical-clarity`; no merge or release is approved. The owner reports **10/10 physical-device test groups passed** on OPPO CPH1937 / Android 11. This is owner-run evidence, not a new agent-run phone test, instrumented performance benchmark or closure of G15-QA-001. Source: [owner-reported acceptance comment](https://github.com/Yoseftext/layer-sort/pull/15#issuecomment-6606381017) and the explicit G4 Exit Gate instruction. Raw phone logs were not independently collected in this task.

Pinned baseline: Godot **4.7.2 Standard**, typed GDScript, Android-only, Portrait-only, Compatibility renderer, offline-first. CI [41626811037](https://github.com/Yoseftext/layer-sort/actions/runs/41626811037) succeeded via **workflow_dispatch**; that event alone does not establish push/PR triggers. Accepted APK: 29,093,281 bytes, SHA-256 `f2c631b3bd1479706abe969427869dd044f083679d992bdcd86f6995db9ec0a7`.

**Current work is repository/CI/documentation and merge-readiness only.** Do not reopen accepted gameplay or implement deferred polish. G5 implementation is not authorized: its future scope is automatic Layer Circuit proof and levels 15–20. ADR-0002 remains controlling: Classic 1–14, first Circuit 15, Circuit development interspersed with ordinary Classic 16–20, Core MVP = 20 total levels. G6 is also unauthorized. Firebase remains future optional Spark-only, with no SDK/billing changes. Shizuku remains optional. The detailed rules contract remains Draft; production signing/store release are not authorized. `main` and all existing PR relationships remain unchanged. [Merge-readiness audit](MERGE-READINESS.md) is a review aid, not merge approval.
