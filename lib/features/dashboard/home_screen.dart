part of '../../main.dart';

// ───────────────────────── الشاشة الرئيسية ─────────────────────────

Widget featurePage(AppUser u, String f) {
  switch (f) {
    case 'ملفات المحاضرات':
    case 'إدارة المحاضرات':
      return LecturesPage(user: u);
    case 'الواجبات والتكليفات':
    case 'إدارة التكليفات':
      return AssignmentsPage(user: u);
    case 'الحضور والغياب':
      return MyAttendancePage(user: u);
    case 'درجاتي':
      return MyGradesPage(user: u);
    case 'تسجيل الحضور':
      return AttendanceTakePage(user: u);
    case 'تقدم المقرر':
      return ProgressPage(user: u);
    case 'متابعة الطلاب':
      return StudentsFollowPage(user: u);
    case 'الإعلانات':
      return AnnouncementsPage(user: u);
    case 'الشكاوى والمقترحات':
      return ComplaintsPage(user: u);
    case 'إدارة المستخدمين':
    case 'الصلاحيات':
      return UsersPage(user: u, title: f, canEdit: u.role == UserRole.admin);
    case 'متابعة المدرسين':
      return UsersPage(user: u, title: f, canEdit: false, onlyRole: 'teacher');
    case 'إدارة المقررات':
    case 'متابعة المقررات':
      return CoursesAdminPage(user: u, title: f);
    case 'متابعة الحضور':
      return AttendanceReportPage(user: u);
    default:
      return ReportsPage(user: u, title: f);
  }
}

class HomeScreen extends StatefulWidget {
  final AppUser user;
  const HomeScreen({super.key, required this.user});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(user: widget.user, openFeature: _openFeature),
      CoursesPage(user: widget.user),
      NotificationsPage(user: widget.user),
      ProfilePage(user: widget.user, onLogout: _logout),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.school_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 10),
          const Expanded(child: Text('المنصة الأكاديمية', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
        ]),
        actions: [IconButton(onPressed: () => setState(() => _tab = 2), icon: const Icon(Icons.notifications_none_rounded)), const SizedBox(width: 6)],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        backgroundColor: Colors.white,
        indicatorColor: paleBlue,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: 'المقررات'),
          NavigationDestination(icon: Icon(Icons.notifications_none_rounded), label: 'الإشعارات'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'حسابي'),
        ],
      ),
    );
  }

  void _openFeature(String feature) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => featurePage(widget.user, feature)));
  }

  Future<void> _logout() async {
    await db.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }
}
