import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'app/router.dart';
import 'brand/tokens.dart';
import 'core/error_reporter.dart';
import 'core/reload.dart';
import 'core/supabase.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // التطبيق عربي بالكامل. نثبّت لغة intl صراحةً بدل الاعتماد على ما يبلّغه
  // المتصفح — بعض المتصفحات تبلّغ لغة فارغة أو غير قابلة للتحليل فيرمي
  // intl خطأ «Incorrect locale information provided» وتبقى الشاشة بيضاء.
  Intl.defaultLocale = 'ar';

  // روابط نظيفة (/app/students) لا (/app/#/students) — تُشارَك على واتساب
  // كما هي. vercel.json يعيد كل مسار تحت /app إلى index.html.
  usePathUrlStrategy();
  // context.push (ملف طالب من القائمة) يغيّر الرابط أيضاً — فيُشارَك ويعمل
  // زر الرجوع في المتصفح، مع بقاء القائمة وبحثها خلفه.
  GoRouter.optionURLReflectsImperativeAPIs = true;

  // على الويب يعرض سفاري عدسته الخاصة فوق الحقل المخفي دائماً؛ عدسة Flutter
  // فوقها = عدستان، وتعلق عدسة Flutter أحياناً بعد رفع الإصبع. نتركها للمتصفح.
  if (kIsWeb) {
    TextMagnifier.adaptiveMagnifierConfiguration =
        TextMagnifierConfiguration.disabled;
  }

  // لا يُنتظر التهيئة قبل runApp بلا حدّ: لو تعذّر الوصول إلى Supabase
  // (لا إنترنت، أو الخدمة متوقّفة) لبقي المستخدم أمام شاشة بيضاء بلا أي
  // تفسير. نمهله وقتاً معقولاً ثم نُقلع على كل حال ونعرض خطأً واضحاً.
  String? bootError;
  try {
    await Db.init().timeout(const Duration(seconds: 15));
  } on TimeoutException {
    bootError =
        'استغرق الاتصال بالخادم وقتاً طويلاً. تحقّق من اتصالك بالإنترنت.';
  } catch (e) {
    bootError = 'تعذّر الاتصال بخادم الأكاديمية. حاول مجدداً بعد قليل.';
  }

  // أخطاء اللوحة الحيّة تصل إلى client_errors بدل أن تضيع في console
  // جوّال لا يفتحه أحد. التسجيل يحتاج جلسة، فلا يعمل قبل الدخول.
  if (bootError == null) {
    ErrorReporter.instance = ErrorReporter.supabase(Db.client);
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      (previous ?? FlutterError.presentError)(details);
      ErrorReporter.reportIfEnabled(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorReporter.reportIfEnabled(error, stack);
      return false; // يبقى السلوك الافتراضي (طباعة في console) كما هو
    };
  }

  runApp(NawahApp(bootError: bootError));
}

class NawahApp extends StatefulWidget {
  const NawahApp({super.key, this.bootError});

  /// خطأ وقع أثناء الإقلاع — يُعرض بدل اللوحة.
  final String? bootError;

  @override
  State<NawahApp> createState() => _NawahAppState();
}

class _NawahAppState extends State<NawahApp> {
  AuthService? _auth;
  GoRouter? _router;
  final _counts = ValueNotifier<Map<String, int>>(const {});

  @override
  void initState() {
    super.initState();
    // AuthService يفترض أن Supabase مُهيّأ؛ لا نبنيه إن فشل الإقلاع.
    // الموجّه يُبنى مرة واحدة ويستمع للجلسة بنفسه (refreshListenable).
    if (widget.bootError == null) {
      _auth = AuthService();
      _router = buildPortalRouter(_auth!, _counts);
    }
  }

  @override
  void dispose() {
    _router?.dispose();
    _auth?.dispose();
    _counts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const locale = Locale('ar');
    const locales = [Locale('ar'), Locale('en')];
    const delegates = [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

    if (_router == null) {
      return MaterialApp(
        title: 'أكاديمية نواة',
        debugShowCheckedModeBanner: false,
        theme: NawahTheme.light,
        locale: locale,
        supportedLocales: locales,
        localizationsDelegates: delegates,
        home: _BootError(message: widget.bootError!),
      );
    }

    // التطبيق عربي بالكامل — RTL أصيل لا معكوس
    return MaterialApp.router(
      title: 'أكاديمية نواة',
      debugShowCheckedModeBanner: false,
      theme: NawahTheme.light,
      locale: locale,
      supportedLocales: locales,
      localizationsDelegates: delegates,
      routerConfig: _router,
    );
  }
}

/// شاشة فشل الإقلاع — أفضل بكثير من شاشة بيضاء صامتة.
class _BootError extends StatelessWidget {
  const _BootError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NawahColors.ink,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(NawahSpacing.s6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 46, color: NawahColors.invertSoft),
                const SizedBox(height: NawahSpacing.s4),
                const Text(
                  'تعذّر تشغيل اللوحة',
                  style: TextStyle(
                    fontFamily: NawahFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: NawahSpacing.s2),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: NawahColors.invertSoft, height: 1.8),
                ),
                const SizedBox(height: NawahSpacing.s5),
                FilledButton.icon(
                  // إعادة التحميل تعيد تشغيل main من جديد
                  onPressed: () => reloadApp(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
