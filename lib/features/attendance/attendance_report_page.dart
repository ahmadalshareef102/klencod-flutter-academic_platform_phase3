part of '../../main.dart';

// ───────────────────────── متابعة الحضور (رئيس القسم) ─────────────────────────

class AttendanceReportPage extends StatelessWidget {
  final AppUser user;
  const AttendanceReportPage({super.key, required this.user});

  Future<(List<Rec>, List<CourseInfo>, Map<String, Rec>)> _load() async => (await fetch('attendance', cols: 'course_id, student_id, status, session_date'), await loadCourses(user), await profileMap());

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'متابعة الحضور',
        body: FutureBody<(List<Rec>, List<CourseInfo>, Map<String, Rec>)>(
          load: _load,
          builder: (context, d, reload) {
            final att = d.$1;
            final absent = <String, int>{};
            for (final a in att.where((a) => a['status'] == 'absent')) {
              absent[a['student_id'] as String] = (absent[a['student_id']] ?? 0) + 1;
            }
            final top = absent.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            return refreshList(reload, [
              const SectionHeading(title: 'حضور المقررات', subtitle: 'نسبة الحضور = (حاضر + متأخر) ÷ كل السجلات'),
              const SizedBox(height: 12),
              if (d.$2.isEmpty) const Card(child: EmptyBox('لا توجد مقررات')),
              for (final c in d.$2)
                Builder(builder: (context) {
                  final rows = att.where((a) => a['course_id'] == c.id).toList();
                  final sessions = rows.map((a) => a['session_date']).toSet().length;
                  final good = rows.where((a) => a['status'] == 'present' || a['status'] == 'late').length;
                  final rate = rows.isEmpty ? null : good / rows.length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${c.code} · ${c.name}', style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
                          const SizedBox(height: 4),
                          Text('${c.teacherName} · $sessions جلسة مسجلة', style: const TextStyle(fontSize: 11, color: muted)),
                          const SizedBox(height: 10),
                          Row(children: [const Expanded(child: Text('نسبة الحضور', style: TextStyle(fontSize: 12, color: muted))), Text(rate == null ? 'لا توجد سجلات' : '${(rate * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w800, color: c.color))]),
                          const SizedBox(height: 6),
                          ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: rate ?? 0, minHeight: 7, backgroundColor: const Color(0xFFEDF1F6), color: c.color)),
                        ]),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 14),
              const SectionHeading(title: 'الطلاب الأكثر غياباً', subtitle: 'أعلى 10 طلاب بعدد مرات الغياب'),
              const SizedBox(height: 12),
              if (top.isEmpty) const Card(child: EmptyBox('لا توجد غيابات مسجلة')),
              for (final e in top.take(10)) Padding(padding: const EdgeInsets.only(bottom: 8), child: FeatureRow(icon: Icons.person_off_outlined, title: pname(d.$3, e.key), subtitle: '', trailing: Tag('${e.value} غياب', color: const Color(0xFFB42318)))),
            ]);
          },
        ),
      );
}
