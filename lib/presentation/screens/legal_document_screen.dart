import 'package:flutter/material.dart';

import '../../core/legal_consent.dart';

enum LegalDocumentType { terms, privacy }

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocumentType type;

  const LegalDocumentScreen({super.key, required this.type});

  bool _isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  String _t(BuildContext context, String ar, String en) =>
      _isArabic(context) ? ar : en;

  @override
  Widget build(BuildContext context) {
    final isTerms = type == LegalDocumentType.terms;
    final theme = Theme.of(context);
    final sections = isTerms ? _terms(context) : _privacy(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTerms
              ? _t(context, 'شروط الاستخدام', 'Terms of Use')
              : _t(context, 'سياسة الخصوصية', 'Privacy Policy'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
          children: [
            Text(
              isTerms
                  ? _t(context, 'شروط استخدام مُنِيب', 'Munib Terms of Use')
                  : _t(context, 'سياسة خصوصية مُنِيب', 'Munib Privacy Policy'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                context,
                'سارية من 9 أيلول 2026 • الإصدار $munibLegalVersion',
                'Effective September 9, 2026 • Version $munibLegalVersion',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            for (final section in sections) ...[
              Text(
                section.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                section.body,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
              ),
              const SizedBox(height: 22),
            ],
          ],
        ),
      ),
    );
  }

  List<_LegalSection> _terms(BuildContext context) => [
        _LegalSection(
          _t(context, '1. قبول الشروط', '1. Accepting these terms'),
          _t(
            context,
            'باستخدام مُنِيب أو إنشاء حساب فيه، فإنك توافق على هذه الشروط وسياسة الخصوصية. إذا لم توافق، فلا تنشئ حسابًا ولا تستخدم الميزات التي تتطلب حسابًا.',
            'By using Munib or creating an account, you agree to these Terms and the Privacy Policy. If you do not agree, do not create an account or use account-required features.',
          ),
        ),
        _LegalSection(
          _t(context, '2. طبيعة التطبيق', '2. Nature of the app'),
          _t(
            context,
            'مُنِيب تطبيق مساعد للعبادات اليومية يتضمن مواقيت الصلاة والأذكار والنفحات والتنبيهات وميزات أخرى. المحتوى والمواقيت أدوات مساعدة وليست فتوى أو بديلًا عن الجهات الدينية أو المصادر المحلية المعتمدة.',
            'Munib is a daily worship companion with prayer times, adhkar, reflections, notifications, and related features. Content and calculated times are aids and are not a religious ruling or a substitute for trusted local religious authorities.',
          ),
        ),
        _LegalSection(
          _t(context, '3. دقة المواقيت والمحتوى', '3. Prayer-time and content accuracy'),
          _t(
            context,
            'قد تختلف مواقيت الصلاة باختلاف الموقع وطريقة الحساب والجهة المحلية. أنت مسؤول عن مراجعة المواقيت عند الحاجة، خصوصًا في الحالات الحساسة مثل الصيام أو السفر.',
            'Prayer times can vary by location, calculation method, and local authority. You are responsible for checking times when accuracy is especially important, including fasting or travel.',
          ),
        ),
        _LegalSection(
          _t(context, '4. الحساب والأمان', '4. Account and security'),
          _t(
            context,
            'أنت مسؤول عن حماية بيانات دخولك وعن النشاط الذي يتم من حسابك. لا تشارك كلمة مرورك، وأبلغنا عبر قنوات مُنِيب الرسمية إذا اشتبهت بوصول غير مصرح به إلى حسابك.',
            'You are responsible for protecting your sign-in credentials and activity under your account. Do not share your password, and use Munib official support channels if you suspect unauthorized access.',
          ),
        ),
        _LegalSection(
          _t(context, '5. الاستخدام المقبول', '5. Acceptable use'),
          _t(
            context,
            'لا تستخدم مُنِيب لإساءة استخدام الخدمات، محاولة اختراقها، تعطيلها، إرسال محتوى ضار، أو انتهاك حقوق الآخرين أو القوانين المعمول بها.',
            'Do not use Munib to abuse, attack, disrupt, or compromise its services, distribute harmful content, or violate the rights of others or applicable law.',
          ),
        ),
        _LegalSection(
          _t(context, '6. الإشعارات والصلاحيات', '6. Notifications and permissions'),
          _t(
            context,
            'بعض الميزات تحتاج صلاحيات من جهازك، مثل الإشعارات أو الموقع. يمكنك رفض هذه الصلاحيات أو إيقافها من إعدادات الجهاز، لكن بعض الميزات قد لا تعمل بالشكل الكامل.',
            'Some features need device permissions, such as notifications or location. You may deny or disable them in device settings, but related features may not work fully.',
          ),
        ),
        _LegalSection(
          _t(context, '7. التحديثات والتوفر', '7. Updates and availability'),
          _t(
            context,
            'قد تتغير الميزات أو تتوقف مؤقتًا بسبب الصيانة أو الأعطال أو تحديثات الخدمات الخارجية. قد نطلب تحديث التطبيق عندما يكون التحديث ضروريًا للأمان أو التوافق.',
            'Features may change or become temporarily unavailable because of maintenance, outages, or third-party service changes. We may require an app update when needed for security or compatibility.',
          ),
        ),
        _LegalSection(
          _t(context, '8. حدود المسؤولية', '8. Limitation of responsibility'),
          _t(
            context,
            'يُقدَّم مُنِيب كما هو وبقدر ما يسمح به القانون. لا نضمن عدم انقطاع الخدمة أو خلوها من الأخطاء بشكل دائم، ولا نتحمل نتائج اعتماد المستخدم على بيانات تحتاج تحققًا محليًا مستقلًا.',
            'Munib is provided as available and to the extent permitted by law. We do not guarantee uninterrupted or permanently error-free operation and are not responsible for outcomes from relying on information that requires independent local verification.',
          ),
        ),
        _LegalSection(
          _t(context, '9. تغييرات الشروط', '9. Changes to these terms'),
          _t(
            context,
            'قد نحدّث هذه الشروط مع تطور مُنِيب. عند حدوث تغيير مهم، سنحدّث الإصدار أو التاريخ ونطلب موافقة جديدة عندما يكون ذلك مناسبًا.',
            'We may update these Terms as Munib evolves. For material changes, we will update the version or date and request renewed consent when appropriate.',
          ),
        ),
      ];

  List<_LegalSection> _privacy(BuildContext context) => [
        _LegalSection(
          _t(context, '1. ما البيانات التي نعالجها', '1. Data we process'),
          _t(
            context,
            'عند إنشاء حساب قد نعالج الاسم والبريد الإلكتروني وطريقة تسجيل الدخول وحالة تفعيل البريد. إذا اخترت صورة شخصية، تمر الصورة عبر Munib API وتُخزّن عبر Cloudinary. وعند طلب مواقيت لموقعك الحالي، قد تُستخدم إحداثيات الموقع لتحديد المدينة والمواقيت.',
            'When you create an account, we may process your name, email address, sign-in provider, and email-verification status. If you choose a profile photo, it is handled through the Munib API and stored using Cloudinary. When you request prayer times for your current location, coordinates may be processed to determine the city and prayer times.',
          ),
        ),
        _LegalSection(
          _t(context, '2. التحليلات', '2. Analytics'),
          _t(
            context,
            'نستخدم Firebase Analytics لفهم استخدام الميزات الأساسية وتحسين التطبيق. لا نسجّل في أحداث التحليلات اسمك أو بريدك الإلكتروني أو موقعك الدقيق أو النصوص التي تكتبها داخل التطبيق.',
            'We use Firebase Analytics to understand use of core features and improve the app. Analytics events do not include your name, email address, precise location, or text you enter in the app.',
          ),
        ),
        _LegalSection(
          _t(context, '3. لماذا نستخدم البيانات', '3. Why we use data'),
          _t(
            context,
            'نستخدم البيانات لتسجيل الدخول وحماية الحساب، حفظ الملف الشخصي، توفير المواقيت والميزات المطلوبة، إرسال الإشعارات التي فعّلتها، تشخيص الأعطال، تحسين الأداء، وإدارة تحديثات التطبيق.',
            'We use data to authenticate and protect accounts, maintain profiles, provide requested prayer-time and app features, deliver enabled notifications, diagnose problems, improve performance, and manage app updates.',
          ),
        ),
        _LegalSection(
          _t(context, '4. الخدمات الخارجية', '4. Third-party services'),
          _t(
            context,
            'يعتمد مُنِيب على خدمات من بينها Firebase Authentication وCloud Firestore وFirebase Analytics وFirebase Cloud Messaging وRemote Config، بالإضافة إلى Cloudinary لصورة الملف الشخصي وMunib API لبعض عمليات التطبيق. تخضع هذه الخدمات لسياساتها وشروطها الخاصة.',
            'Munib relies on services including Firebase Authentication, Cloud Firestore, Firebase Analytics, Firebase Cloud Messaging, and Remote Config, plus Cloudinary for profile photos and the Munib API for certain app operations. These providers operate under their own terms and privacy practices.',
          ),
        ),
        _LegalSection(
          _t(context, '5. الموقع', '5. Location'),
          _t(
            context,
            'لا نستخدم موقعك الدقيق لأغراض التحليلات. لا يُطلب الموقع إلا عند استخدام ميزة تحتاجه، مثل تحديد موقعك الحالي لجلب المواقيت، ويمكنك رفض الإذن أو إلغاؤه من إعدادات الجهاز.',
            'We do not use your precise location for analytics. Location is requested only when you use a feature that needs it, such as detecting your current location for prayer times. You can deny or revoke location permission in device settings.',
          ),
        ),
        _LegalSection(
          _t(context, '6. الإشعارات', '6. Notifications'),
          _t(
            context,
            'قد يستخدم مُنِيب إشعارات محلية وإشعارات Firebase Cloud Messaging. يمكنك إدارة صلاحية الإشعارات من إعدادات الجهاز وإيقاف أنواع الإشعارات المتاحة من داخل التطبيق.',
            'Munib may use both local notifications and Firebase Cloud Messaging. You can manage notification permission in device settings and disable supported notification types in the app.',
          ),
        ),
        _LegalSection(
          _t(context, '7. الاحتفاظ والأمان', '7. Retention and security'),
          _t(
            context,
            'نحتفظ بالبيانات المرتبطة بالحساب ما دامت لازمة لتشغيل الحساب والميزات المرتبطة به أو للوفاء بمتطلبات مشروعة. نستخدم ضوابط وصول وخدمات موثوقة، لكن لا توجد وسيلة تخزين أو نقل عبر الإنترنت مضمونة بنسبة 100%.',
            'We retain account-related data while needed to operate the account and related features or to meet legitimate requirements. We use access controls and trusted service providers, but no internet transmission or storage method is guaranteed to be 100% secure.',
          ),
        ),
        _LegalSection(
          _t(context, '8. خياراتك', '8. Your choices'),
          _t(
            context,
            'يمكنك تعديل بعض بيانات الملف الشخصي، إدارة الصلاحيات والإشعارات، أو التوقف عن استخدام التطبيق. تتوفر خيارات الحساب الإضافية بحسب الميزات التي يوفرها مُنِيب في الإصدار الحالي.',
            'You can edit supported profile information, manage permissions and notifications, or stop using the app. Additional account controls are available according to the features provided in the current Munib release.',
          ),
        ),
        _LegalSection(
          _t(context, '9. تغييرات السياسة', '9. Changes to this policy'),
          _t(
            context,
            'قد نحدّث سياسة الخصوصية مع تغير ميزات مُنِيب أو مزودي الخدمة. سيظهر تاريخ وإصدار السياسة المحدثة، وقد نطلب موافقة جديدة عند وجود تغيير مهم.',
            'We may update this Privacy Policy as Munib features or service providers change. The updated date and version will be shown, and renewed consent may be requested for material changes.',
          ),
        ),
      ];
}

class _LegalSection {
  final String title;
  final String body;

  const _LegalSection(this.title, this.body);
}
