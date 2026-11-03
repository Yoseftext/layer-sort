SUPERSEDED — NOT AUTHORITATIVE

Historical G0 start checklist and one-time OpenCode prompt, preserved verbatim from production sections 7–8. Replaced by docs/current/00-START-HERE.md current acceptance and MERGE-READINESS.md.

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
