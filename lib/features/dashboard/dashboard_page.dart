part of '../../main.dart';

// ───────────────────────── الرئيسية (بيانات حقيقية) ─────────────────────────

Future<List<Rec>> loadAnnouncements(AppUser u) async {
  final rows = await fetch('announcements', orderBy: 'published_at', asc: false);
  var mine = <String>{};
  if (u.role == UserRole.student) {
    final enr = await fetch('course_enrollments', cols: 'course_id', eq: {'student_id': u.id});
    mine = enr.map((e) => e['course_id'] as String).toSet();
  }
  return rows.where((a) {
    final aud = a['audience'];
    if (!u.role.isManager) {
      if (aud == 'students' && u.role != UserRole.student) return false;
      if (aud == 'teachers' && u.role != UserRole.teacher) return false;
    }
    final cid = a['course_id'];
    if (cid != null && u.role == UserRole.student && !mine.contains(cid)) return false;
    return true;
  }).toList();
}

typedef StatItem = (IconData, String, String, Color);

class DashData {
  final List<StatItem> stats;
  final List<Rec> notices;
  const DashData(this.stats, this.notices);
}

Future<DashData> loadDash(AppUser u) async {
  const c1 = Color(0xFF1976D2);
  const c2 = Color(0xFF0F9D8A);
  const c3 = Color(0xFFF59E0B);
  const c4 = Color(0xFF8B5CF6);
  final stats = <StatItem>[];
  switch (u.role) {
    case UserRole.student:
      {
        final enr = await fetch('course_enrollments', cols: 'course_id', eq: {'student_id': u.id});
        final att = await fetch('attendance', cols: 'status', eq: {'student_id': u.id});
        final asg = await fetch('assignments', cols: 'id, due_at');
        final subs = await fetch('submissions', cols: 'assignment_id', eq: {'student_id': u.id});
        final done = subs.map((s) => s['assignment_id']).toSet();
        final now = DateTime.now();
        final upcoming = asg.where((a) {
          final d = a['due_at'] == null ? null : DateTime.tryParse(a['due_at'].toString());
          return !done.contains(a['id']) && d != null && d.isAfter(now);
        }).length;
        final good = att.where((a) => a['status'] == 'present' || a['status'] == 'late').length;
        stats.addAll([
          (Icons.menu_book_rounded, 'المقررات', '${enr.length}', c1),
          (Icons.fact_check_outlined, 'نسبة الحضور', att.isEmpty ? '—' : '${(good * 100 / att.length).round()}%', c2),
          (Icons.assignment_outlined, 'تكليفات قادمة', '$upcoming', c3),
          (Icons.task_alt_rounded, 'تكليفات مسلّمة', '${subs.length}', c4),
        ]);
      }
    case UserRole.teacher:
      {
        final courses = await fetch('courses', cols: 'id', eq: {'teacher_id': u.id});
        final ids = courses.map((c) => c['id']).toSet();
        final enr = await fetch('course_enrollments', cols: 'course_id, student_id');
        final att = await fetch('attendance', cols: 'course_id, session_date');
        final asg = await fetch('assignments', cols: 'course_id');
        final students = enr.where((e) => ids.contains(e['course_id'])).map((e) => e['student_id']).toSet().length;
        final sessions = att.where((a) => ids.contains(a['course_id'])).map((a) => '${a['course_id']}|${a['session_date']}').toSet().length;
        final myAsg = asg.where((a) => ids.contains(a['course_id'])).length;
        stats.addAll([
          (Icons.menu_book_rounded, 'مقرراتي', '${courses.length}', c1),
          (Icons.groups_2_outlined, 'الطلاب', '$students', c2),
          (Icons.fact_check_outlined, 'جلسات الحضور', '$sessions', c3),
          (Icons.assignment_outlined, 'التكليفات', '$myAsg', c4),
        ]);
      }
    case UserRole.head:
      {
        final courses = await fetch('courses', cols: 'id');
        final people = await fetch('profiles', cols: 'id, role, is_active');
        final att = await fetch('attendance', cols: 'course_id, session_date');
        final comp = await fetch('complaints', cols: 'status');
        final sessions = att.map((a) => '${a['course_id']}|${a['session_date']}').toSet().length;
        final open = comp.where((c) => c['status'] == 'new' || c['status'] == 'in_review').length;
        stats.addAll([
          (Icons.menu_book_rounded, 'المقررات', '${courses.length}', c1),
          (Icons.groups_2_outlined, 'المدرسون', '${people.where((p) => p['role'] == 'teacher' && p['is_active'] == true).length}', c2),
          (Icons.fact_check_outlined, 'جلسات الحضور', '$sessions', c3),
          (Icons.report_gmailerrorred_rounded, 'شكاوى مفتوحة', '$open', c4),
        ]);
      }
    case UserRole.admin:
      {
        final courses = await fetch('courses', cols: 'id');
        final people = await fetch('profiles', cols: 'id, role');
        final comp = await fetch('complaints', cols: 'status');
        stats.addAll([
          (Icons.menu_book_rounded, 'المقررات', '${courses.length}', c1),
          (Icons.groups_2_outlined, 'المستخدمون', '${people.length}', c2),
          (Icons.school_outlined, 'الطلاب', '${people.where((p) => p['role'] == 'student').length}', c3),
          (Icons.pending_actions_rounded, 'شكاوى جديدة', '${comp.where((c) => c['status'] == 'new').length}', c4),
        ]);
      }
  }
  final notices = (await loadAnnouncements(u)).take(3).toList();
  return DashData(stats, notices);
}

List<(IconData, String)> dashActions(UserRole role) => switch (role) {
      UserRole.student => const [(Icons.library_books_outlined, 'ملفات المحاضرات'), (Icons.assignment_outlined, 'الواجبات والتكليفات'), (Icons.fact_check_outlined, 'الحضور والغياب'), (Icons.grade_outlined, 'درجاتي'), (Icons.support_agent_rounded, 'الشكاوى والمقترحات'), (Icons.campaign_outlined, 'الإعلانات')],
      UserRole.teacher => const [(Icons.library_books_outlined, 'إدارة المحاضرات'), (Icons.assignment_outlined, 'إدارة التكليفات'), (Icons.fact_check_outlined, 'تسجيل الحضور'), (Icons.trending_up_rounded, 'تقدم المقرر'), (Icons.groups_2_outlined, 'متابعة الطلاب'), (Icons.campaign_outlined, 'الإعلانات')],
      UserRole.head => const [(Icons.menu_book_rounded, 'متابعة المقررات'), (Icons.groups_2_outlined, 'متابعة المدرسين'), (Icons.assessment_outlined, 'تقارير القسم'), (Icons.fact_check_outlined, 'متابعة الحضور'), (Icons.support_agent_rounded, 'الشكاوى والمقترحات'), (Icons.campaign_outlined, 'الإعلانات')],
      UserRole.admin => const [(Icons.manage_accounts_outlined, 'إدارة المستخدمين'), (Icons.admin_panel_settings_outlined, 'الصلاحيات'), (Icons.assessment_outlined, 'التقارير العامة'), (Icons.menu_book_rounded, 'إدارة المقررات'), (Icons.support_agent_rounded, 'الشكاوى والمقترحات'), (Icons.insights_rounded, 'الإحصائيات')],
    };

class DashboardPage extends StatelessWidget {
  final AppUser user;
  final ValueChanged<String> openFeature;
  const DashboardPage({super.key, required this.user, required this.openFeature});

  @override
  Widget build(BuildContext context) {
    final actions = dashActions(user.role);
    return FutureBody<DashData>(
      load: () => loadDash(user),
      builder: (context, data, reload) => refreshList(reload, [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [navy, Color(0xFF1D4E89)], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('أهلاً، ${user.name}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)), child: Text(user.role.label, style: const TextStyle(color: Colors.white, fontSize: 12))),
            ]),
            const SizedBox(height: 10),
            Text(user.role.greeting, style: const TextStyle(color: Color(0xFFD8E8FA), fontSize: 14)),
          ]),
        ),
        const SizedBox(height: 24),
        const SectionHeading(title: 'ملخص سريع', subtitle: 'أرقام محدّثة من قاعدة البيانات'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.stats.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.55),
          itemBuilder: (_, i) => StatCard(icon: data.stats[i].$1, title: data.stats[i].$2, value: data.stats[i].$3, color: data.stats[i].$4),
        ),
        const SizedBox(height: 24),
        const SectionHeading(title: 'الخدمات الأكاديمية', subtitle: 'اختر الخدمة التي تريدها'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .95),
          itemBuilder: (_, i) => ActionTile(icon: actions[i].$1, title: actions[i].$2, onTap: () => openFeature(actions[i].$2)),
        ),
        const SizedBox(height: 24),
        const SectionHeading(title: 'آخر الإعلانات', subtitle: 'مستجدات الكلية والمقررات'),
        const SizedBox(height: 12),
        if (data.notices.isEmpty) const Card(child: EmptyBox('لا توجد إعلانات حتى الآن')),
        for (final a in data.notices) Padding(padding: const EdgeInsets.only(bottom: 10), child: NoticeTile(icon: Icons.campaign_rounded, title: '${a['title']}', body: '${a['body']}', time: fmtDateTime(a['published_at']))),
      ]),
    );
  }
}
