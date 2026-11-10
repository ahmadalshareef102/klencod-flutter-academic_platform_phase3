part of '../../main.dart';

// ───────────────────────── التقارير والإحصائيات ─────────────────────────

class ReportsPage extends StatelessWidget {
  final AppUser user;
  final String title;
  const ReportsPage({super.key, required this.user, required this.title});

  Future<Map<String, List<Rec>>> _load() async => {
        'profiles': await fetch('profiles', cols: 'role, is_active'),
        'courses': await fetch('courses', cols: 'is_published, teacher_id'),
        'enrollments': await fetch('course_enrollments', cols: 'course_id'),
        'lectures': await fetch('lectures', cols: 'id'),
        'assignments': await fetch('assignments', cols: 'id, max_score'),
        'submissions': await fetch('submissions', cols: 'assignment_id, score'),
        'attendance': await fetch('attendance', cols: 'status'),
        'complaints': await fetch('complaints', cols: 'status'),
        'announcements': await fetch('announcements', cols: 'id'),
      };

  Widget _section(String title, List<(String, String)> rows) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeading(title: title),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(children: [
                for (final r in rows) ProfileInfoRow(label: r.$1, value: r.$2),
              ]),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: title,
        body: FutureBody<Map<String, List<Rec>>>(
          load: _load,
          builder: (context, d, reload) {
            final people = d['profiles']!;
            int role(String r) => people.where((p) => p['role'] == r).length;
            final courses = d['courses']!;
            final subs = d['submissions']!;
            final asg = d['assignments']!;
            final att = d['attendance']!;
            final comp = d['complaints']!;
            int cnt(List<Rec> l, String k, String v) => l.where((x) => x[k] == v).length;
            double sum = 0;
            int n = 0;
            for (final s in subs.where((s) => s['score'] != null)) {
              final a = asg.where((x) => x['id'] == s['assignment_id']).toList();
              if (a.isEmpty || (a.first['max_score'] as num) == 0) continue;
              sum += (s['score'] as num) / (a.first['max_score'] as num);
              n++;
            }
            final good = cnt(att, 'status', 'present') + cnt(att, 'status', 'late');
            return refreshList(reload, [
              _section('المستخدمون', [
                ('إجمالي الحسابات', '${people.length}'),
                ('الطلاب', '${role('student')}'),
                ('المدرسون', '${role('teacher')}'),
                ('رؤساء الأقسام', '${role('head')}'),
                ('الإدارة', '${role('admin')}'),
                ('حسابات موقوفة', '${people.where((p) => p['is_active'] == false).length}'),
              ]),
              _section('المقررات', [
                ('إجمالي المقررات', '${courses.length}'),
                ('المنشورة', '${courses.where((c) => c['is_published'] == true).length}'),
                ('بدون مدرس', '${courses.where((c) => c['teacher_id'] == null).length}'),
                ('إجمالي تسجيلات الطلاب', '${d['enrollments']!.length}'),
              ]),
              _section('النشاط التعليمي', [
                ('المحاضرات', '${d['lectures']!.length}'),
                ('التكليفات', '${asg.length}'),
                ('التسليمات', '${subs.length}'),
                ('تسليمات مصححة', '${subs.where((s) => s['score'] != null).length}'),
                ('متوسط الدرجات', n == 0 ? '—' : '${(sum * 100 / n).round()}%'),
              ]),
              _section('الحضور', [
                ('إجمالي السجلات', '${att.length}'),
                ('نسبة الحضور العامة', att.isEmpty ? '—' : '${(good * 100 / att.length).round()}%'),
                ('حاضر', '${cnt(att, 'status', 'present')}'),
                ('متأخر', '${cnt(att, 'status', 'late')}'),
                ('غائب', '${cnt(att, 'status', 'absent')}'),
                ('بعذر', '${cnt(att, 'status', 'excused')}'),
              ]),
              _section('الشكاوى والإعلانات', [
                ('شكاوى جديدة', '${cnt(comp, 'status', 'new')}'),
                ('قيد المراجعة', '${cnt(comp, 'status', 'in_review')}'),
                ('تم حلها', '${cnt(comp, 'status', 'resolved')}'),
                ('مغلقة', '${cnt(comp, 'status', 'closed')}'),
                ('الإعلانات المنشورة', '${d['announcements']!.length}'),
              ]),
            ]);
          },
        ),
      );
}
