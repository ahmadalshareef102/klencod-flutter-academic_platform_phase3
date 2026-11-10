import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'core/models/roles_and_user.dart';
part 'core/supabase/db_helpers.dart';
part 'core/widgets/form_dialog.dart';
part 'core/widgets/shared_widgets.dart';
part 'features/courses/course_loader.dart';
part 'features/auth/login_screen.dart';
part 'features/dashboard/home_screen.dart';
part 'features/dashboard/dashboard_page.dart';
part 'features/courses/courses_pages.dart';
part 'features/profile/notifications_and_profile.dart';
part 'features/lectures/lectures_page.dart';
part 'features/assignments/assignments_page.dart';
part 'features/assignments/my_grades_page.dart';
part 'features/attendance/my_attendance_page.dart';
part 'features/announcements/announcements_page.dart';
part 'features/complaints/complaints_page.dart';
part 'features/admin_users/users_pages.dart';
part 'features/courses/courses_admin_page.dart';
part 'features/attendance/attendance_take_page.dart';
part 'features/attendance/attendance_report_page.dart';
part 'features/courses/progress_page.dart';
part 'features/students/students_follow_page.dart';
part 'features/reports/reports_page.dart';

// تُمرَّر القيم وقت التشغيل/البناء عبر --dart-define ولا تُكتب في الكود.
// مثال: flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
bool get isSupabaseConfigured => supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isSupabaseConfigured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const AcademicPlatformApp());
}

const navy = Color(0xFF102A43);
const blue = Color(0xFF1976D2);
const paleBlue = Color(0xFFEAF3FF);
const pageBg = Color(0xFFF5F7FB);
const muted = Color(0xFF718096);
const palette = <Color>[Color(0xFF1976D2), Color(0xFF0F9D8A), Color(0xFF8B5CF6), Color(0xFFF59E0B), Color(0xFFE11D48), Color(0xFF0EA5E9)];

class AcademicPlatformApp extends StatelessWidget {
  const AcademicPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'المنصة الأكاديمية الرقمية',
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: blue),
        scaffoldBackgroundColor: pageBg,
        fontFamily: 'Cairo',
        appBarTheme: const AppBarTheme(backgroundColor: pageBg, foregroundColor: navy, centerTitle: false, elevation: 0),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE3EAF2))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}