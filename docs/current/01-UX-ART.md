# LAYER SORT — UX / UI / VISUAL / AUDIO CONTRACT

> **الملف:** `docs/current/01-UX-ART.md` | **المصدر:** LS-MASTER-1.3 — مقتطع حرفيًا من الحزمة المعتمدة دون تغيير في القرارات.
> **المحتوى:** UX وUI والفن والصوت: الشاشات والتنقل وعقود الشاشات.
> **المعرّفات:** معرّفات هذا الملف (`UX01`–`UX36`) فريدة أصلًا ولا تحتاج بادئة.
> **ملفات `docs/current/`:** `00-START-HERE.md` (قرارات مركزية) · `01-UX-ART.md` (واجهة وفن وصوت) · `02-ENGINEERING.md` (هندسة وFirebase ومخاطر) · `03-PRODUCTION.md` (بوابات وخطة وتسليم)

**المعرف:** LS-UX-1.3 | **معتمد للتنفيذ:** كل الشاشات **Portrait**، والاتجاه الأفقي ملغى. | **نطاق:** Android Phone، العربية/الإنجليزية، تشغيل أوفلاين.

> هذا مستند تعاقدي للواجهة والتصميم الفني. كل مدة، قيمة، حجم، أو تأثير هنا «هدف تصميم معتمد» قابل للضبط داخل قيم Design Tokens عند اختبار الجهاز؛ لا يدعي أن الأصول موجودة أو أن الحركة اختبرت. لا يجوز لوكيل التنفيذ استبدال الهوية الفنية بواجهة افتراضية جاهزة دون مراجعة صاحب المشروع.

## 1. الخريطة الكاملة للشاشات والتنقل

```text
Native Android Launch → Short Splash (first assets/health) → Local Initialization
  ├─ New User → Welcome/Play → Tutorial Level 1 → Game → Win → Next → ...
  ├─ Returning User → Home → Continue (resume active state) → Game
  ├─ Home → Chapter Map → Level Grid → Game
  ├─ Home → Skins/Collection (when unlocked)
  ├─ Home → Settings → [Sound, Accessibility, Language, Graphics, Privacy, Data]
  └─ Home → About → [Credits, Asset Attribution, OSS Licenses, Privacy, Diagnostics, Help]
Game ↔ Pause [Resume, Restart, Settings, Chapter Map, Exit to Home]
Game → Win [Stars, Result, Next, Replay, Map] → Next/Game
Game → Time Out (only in optional timed challenge) [Retry, Map, Home]
Game → Recoverable Error [Retry, Restore, Back]
Firebase unavailable → No blocking screen; offline gameplay continues
```

**Android Back policy:** داخل شاشة اللعب Back يفتح Pause، داخل Dialog يغلقه إلى سياقه ما لم يكن إنهاء خطِر، داخل Settings يرجع إلى الصفحة المستدعية، من Home يظهر Exit confirmation خفيف فقط إذا ضغط Back (بدون نافذة طلب تقييم). لا أكوام تنقل تجعل Back يعود لشاشة قديمة بعد الفوز.

## 2. الإجابات المعتمدة على UX01–UX20

### UX01 — خريطة الشاشات؟
**القرار:** الخريطة أعلاه ملزمة؛ لكل شاشة حالات `loading/ready/empty/error/offline` بحسب وظيفتها. توجد شاشة Privacy وAbout/Credits وAsset Licenses وDiagnostics وHelp وData Reset. **اختبار:** E2E يبدأ من cold-start ويمر بكل مسار رجوع من غير روابط مقطوعة أو توقف لعب.

### UX02 — الرئيسية وزر Continue؟
**القرار:** شعار Layer Sort بالأعلى، بطاقة فصل/مستوى آخر مع تقدم مختصر، زر **Continue** الأكبر وبصريًا الأساسي؛ أسفله `Chapters`, `Collection` عند الإتاحة، `Daily` فقط بعد تنفيذها فعلًا، ثم Settings وAbout بأيقونات واضحة؛ لا Banner داخل الصفحة الأولى في MVP. بعد أول تشغيل يتحول Continue إلى `Play Level 1`. لا زحمة أو Popups. **اختبار:** لاعب جديد يعرف بدء اللعبة بأقل من 3 ثوانٍ في اختبار فهم سريع.

### UX03 — Undo/Hint/Restart والإبهام؟
**القرار:** شريط أفعال سفلي داخل Safe Area: Undo يسار، Hint في الوسط، Restart يمين في LTR؛ يخضع ترتيب الأزرار النصية لاتجاه اللغة عند الحاجة، و`left-handed mode` يعيد تخصيص الأولوية قرب الإبهام. Pause بالأعلى، رقم المستوى والمؤقت الاختياري والحركات بالأعلى دون ازدحام. لا زر يغطي أنبوبًا. **اختبار:** اختبارات يد واحدة على 720×1600 و18:9 و20:9.

### UX04 — أهداف اللمس والمسافات؟
**القرار:** الحد الأدنى المستهدف **48dp** مكافئ لكل زر مهم، ومناطق تباعد ≥8dp كبداية، والأنابيب تملك hit-target أكبر قليلًا من عرض الزجاج المرئي دون تداخل مناطق النقر؛ تُطبّق القياسات حسب كثافة Android الفعلية مع Safe Area. **اختبار:** Tap near-edge/multitouch وscreen scaling.

### UX05 — الفوز؟
**القرار:** احتفال جذاب قصير **0.9–1.5s**، ثم بطاقة نتائج بها 1–3 نجوم (إن كان نظام النجوم للنوع المعني)، عدد الحركات، رقم المستوى، زر `Next` أساسي، `Replay` و`Map` ثانويان، وتلميح لشارة الفصل/مكافأته إذا حصلت. يتاح Skip للاحتفال مباشرة دون إلغاء حفظ الفوز؛ Reduce Motion يستبدله بانتقال Fade قصير. **اختبار:** لا حواران معًا ولا تسجيل تقدم مرتين، وصوت الفوز في توقيت أنيميشن النتيجة.

### UX06 — Pause / Time Out؟
**القرار:** Pause يحفظ حالة التقدم الملتزم بها، ويوقف مؤقت اللعب فقط حسب وضع التحدي؛ `Resume`, `Restart`, `Settings`, `Map/Home`. انتهاء الوقت **لا يظهر إلا في تحدٍ اختياري موقّت** برسالة محترمة و`Retry` أساسي و`Map`؛ لا Game Over عشوائي ولا إعلان إجباري. **اختبار:** استئناف بعد مكالمة وتغيير focus مع ثبات حالة المؤقت.

### UX07 — اختيار المستويات؟
**القرار:** خريطة فصول عمودية ببطاقات واسعة تحمل هوية Glass/Circuit/Frost/Shift/Links، مع شبكة مستويات داخل الفصل من 3 أعمدة على هاتف قياسي وتتحول حسب عرض الشاشة. مكتمل: نجوم وتدرج اللون؛ مفتوح: رقم وحدود واضحة؛ مقفل: قفل وشرط فتح، لا أيقونة مبهمة. زر Continue ظاهر فوق الخريطة. **اختبار:** لا مستوى مقفل يُفتح بواسطة Tap على رقمه فقط؛ إمكانية الوصول للأعلى/الأسفل دون Scroll معلق.

### UX08 — التعليم البصري؟
**القرار (ADR-0002):** دروس Classic التفاعلية القصيرة في **1–5 فقط**؛ 6–10 ألغاز Classic سهلة بلا إرشاد إلزامي، و11–14 أصعب تدريجيًا. توهج حلقة حول الأنبوب الصحيح مع إيماءة إصبع مرئية عند التوقف 3 ثوانٍ، ونص قصير قابل للتعطيل (مثل «اضغط على اللون ثم مكانه»). تختفي الإشارة بمجرد أول إجراء صحيح ولا تمنع المحاولة. أول شرح بسيط لـCircuit التلقائية في مستوى 15؛ لا تُفرض دروس Classic الأولى على مستويات 6–14 أو على كل مستويات Circuit. توجد `Replay Tutorials` بالإعدادات. **اختبار:** لاعب أول مرة يفهم اختيار المصدر والهدف، ولا يصبح التلميح دائمًا فوق الأنابيب.

### UX09 — الحالات الحرجة؟
**القرار:** تلف حفظ → استعادة آخر Snapshot صالح مع شرح وتصدير Report؛ فشل مستوى → `Retry` ثم `Safe Level` محفوظ أو Map دون فتح مستوى فاسد؛ مساحة ممتلئة → تنبيه «تعذر حفظ التقدم، أفرغ مساحة» ثم retry مع بقاء الحالة الحالية في الذاكرة وتحذير واضح؛ Asset مفقود → fallback مرئي وخطأ في التشخيص. ممنوع فقدان صامت للبيانات. **اختبار:** محاكاة ملف ناقص/قطع كتابة/فشل تحميل/مخزن ممتلئ.

### UX10 — Splash وتحميل؟
**القرار:** Native splash لا تطول دون سبب، شاشة Godot Intro 0–1.5s *إذا* اكتمل التحميل سريعًا، وإلا حالة تحميل بسيطة موثوقة مع معلومات محلية فقط. لا ننتظر اتصال Firebase قبل أول مستوى ولا فيديو مقدمة إلزامي. **اختبار:** startup cold/warm، عدم تجمد، حفظ الشاشة عند تدوير الجهاز مع Portrait ثابت.

### UX11 — لوحة الألوان؟
**القرار:** فصل كامل بين `UI Palette` و`Liquid Palette`: واجهة أساسية كحلي غامق `#111B2C`، بطاقات `#1C2A40`، نص `#F4F7FC`، Secondary `#AABBD0`، Accent `#75D7EA`، Success `#7CCDA6`، Warning `#F3BF77`، Error `#EF8292`. نسخة Light اختيارية بخلفية `#F3F7FA` ونص `#14283A`؛ التباين يُقاس ويعدل قبل النشر. ألوان السوائل مستقلة مع patterns/رموز. **اختبار:** فحص WCAG contrast للنصوص ذات الصلة وصور Low/High/Light.

### UX12 — الخط والأرقام؟
**القرار:** خط عربي **Noto Sans Arabic** وخط لاتيني **Inter** أو خطوط OFL مماثلة بعد التحقق من ملفات الترخيص الفعلية؛ أرقام واجهة/مستوى لاتينية 0–9 بشكل ثابت في كلا اللغتين لسهولة الربط والقراءة. أحجام مرجعية: عنوان 28–34sp، عنوان ثانوي 20–24sp، نص 15–17sp، Caption 12–14sp، زر 16–18sp؛ وضع تكبير خطوط اختياري. **اختبار:** لا clipping للعربية الطويلة عند تكبير 130%، وبيان تراخيص ملفات الخط.

### UX13 — الأزرار وحالاتها؟
**القرار:** أنماط Primary Filled وSecondary Outline وQuiet Icon وDanger Confirm. لكل نمط حالات normal/pressed/disabled/focus/loading مع Animation لطيفة، وdisabled مميز بأيقونة/وصف لا باللون وحده. استخدام Theme Godot موحد مع Scene components قابلة لإعادة الاستخدام. **اختبار:** Snapshot states + keyboard/gamepad focus إن أُتيح.

### UX14 — الأيقونات؟
**القرار:** Outline rounded 2dp stroke كبداية، الأيقونات أساسية تُرسم داخليًا بصيغة SVG/Vector ضمن هوية واحدة. الأصل الخارجي له ترخيص وسجل، ولا يدخل من Google Images بلا تصريح. لا تُستخدم رموز Emoji بدل أيقونات الإنتاج. **اختبار:** وضوح أيقونات 24/32/48dp وخلفيات فاتحة وداكنة.

### UX15 — حركة الواجهة؟
**القرار:** Design tokens: Press 100–140ms (ease-out)، Tab/Panel 180–240ms (ease-in-out)، شاشة 220–320ms، احتفال الفوز 0.9–1.5s. Normalize animation time حسب الإعداد، ولا تُستخدم Blur/Shake قوي؛ Reduce Motion يختصر حركة UI إلى Fade/Instant دون منع الوصول للزر. **اختبار:** مع reduce motion لا يحصل Zoom إجبارى أو بقاء Input Lock مدة غير منطقية.

### UX16 — جدول التغذية الراجعة؟
**القرار:** لمسة أنبوب: lift 6–10px + highlight + haptic light إن فعال؛ حركة صالحة: tilt + liquid bridge + 1 من SFX variants؛ رفض: wobble خفيف 100ms + soft tick دون اهتزاز قوي؛ اكتمال أنبوب: shimmer 250ms + note؛ Circuit/Freeze/Shift/Links: أصوات ومعالم مرئية مختلفة؛ Win: fanfare قصيرة دون إزعاج؛ خطأ نظام: رسالة عملية لا فلاش أحمر. **اختبار:** كل فعل ينتج حدث صوت/رسوم واحدًا ويعود لحالة stable حتى عند انقطاع التطبيق.

### UX17 — RTL والانعكاس؟
**القرار:** النصوص ومسارات القراءة والشاشات النصية تتحول RTL. الأزرار «التالي/السابق» والأيقونات الاتجاهية قد تنعكس بالاتجاه الدلالي؛ Undo يدور كرمز «العودة في التاريخ» لا ينعكس عشوائيًا إن غيّر معنى السهم، والأرقام والأنابيب وقواعد ترتيب ألوانها **لا تنعكس**. **اختبار:** Golden صور AR/EN مع مقارنة مسار التنقل والفعل الفعلي.

### UX18 — Wireframes قبل الكود؟
**القرار:** نعم؛ Low Fidelity wireframe لكل شاشة ثم Design Tokens ثم Mockups معتمدة ثم Scenes Godot Controls/Containers؛ لا استخدام صورة AI مسطحة كواجهة غير قابلة للتفاعل. توليد AI للاتجاه الفني لا يُغني عن Assets أصلية قابلة للتقسيم. **اختبار:** كل مكون UI له Scene وسلوك ويمكن تغيير اللون/الحجم من Theme واحد.

### UX19 — اختبار الواجهات؟
**القرار:** Golden screenshots لكل شاشة وحالاتها على العربية والإنجليزية، أبعاد 16:9 و19.5:9 و20:9 والـOPPO 720×1600، مع اختبارات Device/Appium لمس فعلي ومراجعة التباين وSafe Area. التغيرات المقصودة تحتاج قبول الصورة الجديدة بالـPR. **اختبار:** لا clipping، لا زر خارج safe area، وجود alt/accessibility labels للأزرار حيث يمكن.

### UX20 — الهوية والشعار؟
**القرار:** اسم العمل `Layer Sort` الآن. تصميم الشعار وأيقونة التطبيق في مرحلة Art Identity قبل Beta، لكن يُستخدم placeholder مميز وواضح خلال MVP؛ العلامة النهائيّة تتكون من Tube/Layers/Signal motif وتعمل عند 48px. حقوق الاسم والشعار تُفحص قبل حسابات النشر. النص المعروض: `Layer Sort` بالإنجليزية، و`Layer Sort — فرز الطبقات` كعنوان وصفي في العربية لا يغيّر الاسم التجاري. **اختبار:** Icon grid وتحمل الألوان والـmonochrome.

## 3. عقود شاشة بشاشة (لا تُترك حالات للصدفة)

| الشاشة | المحتويات الأساسية | الحالات الحرجة | فحوص لازم تمر |
|---|---|---|---|
| Boot/Splash | Logo صغير، Loading نزيه | تأخر import/لا نت/ملف تالف | بدء بلا شبكة، no infinite spinner |
| Welcome | بدء لعب، لغة أولية، خيار Help | مستخدم قديم/ملف مهاجر | لا Consent Wall للتليمترية الاختيارية |
| Home | Continue رئيسي، فصل، Map، Settings، About | تقدم غير موجود، بيانات متدهورة | Continue يفتح المستوى الصحيح |
| Chapter Map | فصول وحالة فتح/نجوم، Scroll رأسي | قفل، محتوى تحديث، No chapter | روابط دقيقة إلى المستوى المفتوح |
| Level Grid | شبكة 3 أعمدة مرنة، تقدم وشروط فتح | قفل/مكتمل/حالي | لا تزاحم عند تغيير اللغة |
| Gameplay | Header info، Board وسط، Toolbar أسفل | Animation pending، Pause، Low FPS | Tap hit testing وatomic moves |
| Pause | Resume/Restart/Settings/Map | توقيت/مكالمة/خروج | Audio Focus وSave consistent |
| Win | نجوم/حركات/Next/Replay/Map | زر مرتين، فقد كتابة | progress idempotent |
| Time Out | Retry/Map/Home | انتهاء خلال animation | win/timeout mutually exclusive |
| Hint | Highlight+Arrow ومساحة حوار قصيرة | Solver slow/No network | لا حجب شاشة/لا حركة تلقائية |
| Restart Confirm | تأكيد إذا تمت حركة واحدة | Double tap/Save state | لا فقد تقدم فصل سابق |
| Skins | Preview واضح وحالة Unlock | غير متاح/no purchase | No fake buttons للميزات المؤجلة |
| Settings | تبويبات Audio, Accessibility, Graphics, Language, Data, Privacy | لغة تتغير أثناء اللعب، permission | الإعداد يُطبق ويُحفظ فوريًا |
| Help/Tutorials | شرح تفاعلي ودروس قابلة للإعادة | لا نت، مستوى صعب | إعادة تشغيل الدرس لا تمس تقدمًا |
| About | Build/Engine version، Support، Diagnostics، Legal | URL offline | صفحة قانونية داخلية متاحة |
| Credits/Attribution | مؤلفو أصول/مساهمون/مصادر | ملف غير معتمد | كل attribution مطلوب موجود |
| OSS Licenses | تراخيص أصلية للـSDK/engine/addons | رابط مفقود | Offline license text/export |
| Privacy/Consent | بيانات الجمع، تشغيل/إيقاف telemetry، حذف محلي | رفض المشاركة | لا إرسال Analytics قبل الإذن المناسب |
| Diagnostics | Error ID، مسار تقرير sanitized، Copy | فشل تقرير/لا مشاركة متاحة | لا أسرار ولا بيانات حساسة |
| Recoverable Error | وصف بسيط، Retry، Restore، Home | Store full/Level missing | استرداد محلي فعلي دون loop |
| Reset Data | شرح أثر الحذف، تأكيد ثانٍ واضح | ضغط خاطئ | التأكيد لا يمكن تجاوزه بالرجوع |

## 4. تفاصيل شاشة اللعبة — Portal of quality

- **الأعلى 12–16%**: زر Pause 48dp، اسم الفصل/المستوى، moves، timer progress ring يظهر فقط إن كانت اللعبة موقّتة؛ لا currency/ads في MVP.
- **المنتصف 65–73%**: أنابيب زجاجية بنسبة مرئية واسعة؛ من 1 إلى صفين أو ثلاثة Grid حسب العدد والارتفاع، مع معرّفات لمسية داخلية مستقلة عن الشكل. الأنابيب تظهر بأحجام متناسقة؛ لا تحويل اللوحة إلى scroll افتراضي يؤدي لنقرات غير مقصودة.
- **الأسفل 14–20%**: Undo / Hint / Restart، أسفلها مساحة Safe Area وإشارة Drag فقط إذا أصبح هذا أسلوب تحكم معتمدًا لاحقًا؛ التحكم المعتمد `Tap → Tap`.
- إشارات Circuit تربط نقاط الأجهزة بمنحنيات صغيرة حول حدود اللعب، **لا أسلاك كبيرة فوق الألوان**. أجهزة Frozen/Shift/Link تملك شارات حروف/أنماط حتى في Grayscale.
- الانتقالات تبنى على Logical State committed، والرسوم تتلقى Event immutable؛ عند app background تنتهي الحركة بصريًا إلى أحدث snapshot منطقي دون double-commit.

## 5. Art Direction — معايير القبول الملزمة

**الهويّة:** Calm Laboratory / Living Layers؛ خامة أنبوب شبه زجاجية بخط حدود مزدوج وHighlight ناعم؛ أقسام الفصل تميّز بإضاءة خلفية لا تغيّر دلالة ألوان السائل. **القرار الفني:** 2D/2.5D باستخدام Godot CanvasItem Shader + Sprite/Polygon أصلي وعناصر FX خفيفة، دون Mesh3D شفاف ثقيل في Core MVP؛ يمكن تجربة نسخة 3D على فرع بحث فقط إذا أثبتت تفوق الأداء/الجمال.

**الإنتاج عالي الدقة:** الأصل المتجهي SVG أو المصدر عالي الدقة منفصل عن texture المضغوط، وخامات الأنابيب 2× من الحجم المرئي على جهاز الاختبار عند الحاجة بدون حفظ نسخ متكررة؛ الخلفيات 1080×1920 عالية الجودة بمستويات ضغط مناسبة؛ تجنب تحويل كل شاشة إلى PNG عملاق. يعاد رسم عناصر HUD ديناميكيًا، ولا تُستخدم صورة كاملة كزر.

**الرسوم المتحركة:** Lift select 120–160ms، pour 450–750ms ويختلف بحسب الحجم 1–4، settling 120–250ms، invalid 100–150ms، solved shimmer 250–400ms، Circuit signal 200–350ms، ice breakup 350–600ms، Shift exchange 250–450ms، Link blink 250–450ms، Win 900–1500ms، Lose/Timeout 250–400ms. هذه مدد مرجعية تُضبط بالاختبار دون تغيير Commit الذري. **Reduce Motion:** يلغي shake/floating particles والزووم الكبير، ويختصر الزمن إلى ≤120ms حيث ممكن.

**الألوان وإتاحة الوصول:** حد مبدئي 12–16 لونًا في كامل المكتبة، لكن مستويات الهاتف الأولى ≤6–8 ألوان حسب قياس الرؤية، ورموز فريدة لكل لون أو Pattern مرئي Color Assist؛ لا الاعتماد على Hue وحده. مع Airplane Mode وLow-quality يظل كل رمز واضحًا. الصور الثابتة لا تستخدم لونًا أزرق/أحمر فوق نفس الخلفية بدون contrast كافٍ.

**أصول AI المجانية:** يجوز استخدام أدوات تصميم مجانية مع ترخيص واضح يسمح الاستخدام المطلوب؛ نقّح كل مخرج وأزل الحروف غير المنضبطة والعيوب البصرية. الدقة/الطبقات القابلة للتحرير مصدرها برامج Vector/Blender أو shaders أصلية؛ سجل Prompt/Tool/License/Date/Revision عند الحاجة. لا نسخ تصميم لعبة أخرى أو واجهتها حرفيًا.

**ميزانية أولية للرسوم:** وضع Low بدون refraction كثيف وبحد بسيط للجزيئات، Medium يعيد overlay shimmer والموج، High يسمح specular soft وتوهج متزن. نحدد Pixel/time budgets بعد Profiling أول GDScript على OPPO لا نخترع أرقام RAM فعليّة. الهدف 30 FPS ثابت Low مع محاولة 60 FPS على الأجهزة المناسبة. لمسة اللعبة لا تنتظر انتهاء Particle effect.

## 6. Audio Bible — الهوية السمعية

**قنوات:** Master/Music/SFX/UI/Ambience عبر Godot Audio Buses. ثلاث حالات موسيقى: Calm، Focus، Tension تتغير عبر نسبة زمن التحدي المتبقي، وcrossfade عبر 1.0–2.0s أو تبديل على Bar موسيقي إذا توفر BPM موحد؛ لا قطع مفاجئ. لا موسيقى توتر في Classic غير الموقّت.

**SFX أساسية:** pick 3 variants، pour small/medium/large 2–3 variants، reject 2، tube-complete 2، undo 2، restart 1، hint 2، circuit 2، freeze 2، shift 2، link 2، win short/long 2، timeout 1، button 2، error 1. Mixed audio peak/volume يُضبط لتجنب أصوات عالية، يوقف أو يخفف عند فقد Audio Focus ومكالمات Android؛ استئناف سلس بعد العودة لا يبدأ مقطوعتين معًا. الاهتزاز لكل حدث قابل للتعطيل.

**الترخيص:** كل مؤثر ومقطوعة لها ملف أصل وlicense وصاحب الحق ورابط وتاريخ وشروط نسبة إن لزم. لا استخدام موسيقى مجانية مشروطة بغير ذلك. في أول Prototype يُسمح بـPlaceholder مؤثر من مولد موجات أصلي، لكنه لا يدخل نسخة Beta دون قبول جودة وحقوق.

## 7. أسئلة UX الإضافية — أجوبة رسمية UX21–UX36

| الرمز | السؤال | الجواب النهائي / معيار القبول |
|---|---|---|
| UX21 | هل تظهر رسالة كل مرة من أجل مزامنة؟ | لا؛ Progress محلي، Firebase اختياري ولا ينتظر؛ لا infinite spinner. |
| UX22 | كيف تعمل التنقلات عند ضغطات متعددة؟ | Navigation coordinator واحد مع debounce، وحوار واحد من النوع نفسه؛ اختبارات rapid taps. |
| UX23 | كيف نعرض أول فتح للتحديات؟ | بطاقة تعليمية قصيرة عند unlock، ثم محتوى فعلي؛ لا إعلان أو Cutscene طويل. |
| UX24 | ماذا لو الترجمة طويلة؟ | Containers + wrap + max 2 lines للأزرار + زيادة ارتفاع موضعي؛ لا truncate لمعنى حساس. |
| UX25 | هل اللاعب يعرف سبب قفل الأنبوب؟ | نعم؛ رمز القفل وحالة الحساس وHelp context؛ لون وحده غير كافٍ. |
| UX26 | هل يمكن قراءة القاعدة مع خلفية متحركة؟ | نعم؛ خلفية خارج التركيز وخفض التباين/تثبيت عند gameplay؛ readability gate. |
| UX27 | ماذا لو تغيرت الشبكة؟ | لا Notification مزعج أثناء اللعب؛ Firebase adapter يفشل بصمت ويسجل محليًا. |
| UX28 | هل يُسمح بنسخ رمز خطأ؟ | نعم `Copy Error ID` وExport sanitizer، لا Stacktrace ظاهر. |
| UX29 | هل يمكن تفعيل الضبط السريع؟ | Settings متاحة من Pause مع العودة للمستوى نفسه بلا reset. |
| UX30 | كيف نتعامل مع نقر قرب حد أنبوبين؟ | أقرب target فقط إذا داخل hitbox غير متداخلة؛ وإلا تجاهل مع feedback خفيف. |
| UX31 | هل شاشة الإعدادات تعرض إعدادًا غير موجود؟ | لا؛ كل Toggle يعمل أو لا يظهر في Release. |
| UX32 | كيف تُحل مشكلة Splash عالق؟ | Timeout startup قصير وتشخيص ورسالة Retry/Continue Offline؛ لا انتظار Firebase. |
| UX33 | هل اللاعب يرى حالة الحفظ؟ | لا إشغال دائم؛ indicator صغير مؤقت عند فشل الحفظ فقط؛ Save warning واضح لو متكرر. |
| UX34 | ماذا عن شاشات Tablet أو foldable؟ | UI مرن دون وعد بدعم تجربة رسمية كاملة في v1؛ لا قص أو crash، ثم Device Matrix قبل الإعلان. |
| UX35 | هل هناك زر دائم للخروج؟ | Back/Settings وفق Android conventions؛ تجنب Exit يصرف مساحة اللعب. |
| UX36 | كيف تحمي الواجهة احترام اللاعب؟ | لا dark patterns، ولا جعْل رفض Analytics صغيرًا جدًا، ولا إجبار إعلانات، ولا استخدام صوت/اهتزاز إلزامي. |

## 8. UX Gate للتسليم

لا ينتقل Screen إلى `Done` إلا بعد وجود Wireframe + Mockup + Scene Godot + A11y labels + AR/EN + Dark/Light إن مشمولة + Screenshot Golden + قياس على OPPO + اختبارات Tap/Back/Rotate/Safe Area + فحص نصوص + فصل المنطق عن الرسم + مصدر الأصول. الموافقة البصرية للمالك مطلوبة قبل تثبيت Hero Screens والهوية النهائية.
