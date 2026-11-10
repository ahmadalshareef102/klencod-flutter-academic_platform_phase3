part of '../../main.dart';

// ───────────────────────── الحضور (للطالب) ─────────────────────────

class MyAttendancePage extends StatelessWidget {
  final AppUser user;
  const MyAttendancePage({super.key, required this.user});

  Future<(List<Rec>, List<CourseInfo>)> _load() async {
    final att = await fetch('attendance', eq: {'student_id': user.id}, orderBy: 'session_date', asc: false);
    return (att, await loadCourses(user));
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'الحضور والغياب',
        body: FutureBody<(List<Rec>, List<CourseInfo>)>(
          load: _load,
          builder: (context, d, reload) {
            final att = d.$1;
            int count(String s) => att.where((a) => a['status'] == s).length;
            final good = count('present') + count('late');
            const colors = {'present': Color(0xFF0F9D8A), 'late': Color(0xFFF59E0B), 'absent': Color(0xFFB42318), 'excused': blue};
            return refreshList(reload, [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(att.isEmpty ? 'لا توجد سجلات حضور بعد' : 'نسبة الحضور: ${(good * 100 / att.length).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, color: navy, fontSize: 16)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 6, children: [for (final k in attendanceAr.keys) Tag('${attendanceAr[k]}: ${count(k)}', color: colors[k]!)]),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              for (final a in att)
                Builder(builder: (context) {
                  final c = d.$2.where((x) => x.id == a['course_id']).toList();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FeatureRow(
                      icon: Icons.event_available_outlined,
                      title: c.isEmpty ? 'مقرر' : c.first.name,
                      subtitle: '${fmtDate(a['session_date'])}${(a['notes'] ?? '').toString().isEmpty ? '' : ' · ${a['notes']}'}',
                      trailing: Tag(attendanceAr[a['status']] ?? '', color: colors[a['status']] ?? blue),
                    ),
                  );
                }),
            ]);
          },
        ),
      );
}
