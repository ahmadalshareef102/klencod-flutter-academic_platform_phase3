part of '../../main.dart';

// ───────────────────────── متابعة الطلاب (للمدرس) ─────────────────────────

class StudentsFollowPage extends StatelessWidget {
  final AppUser user;
  const StudentsFollowPage({super.key, required this.user});

  Future<(List<CourseInfo>, List<Rec>, List<Rec>, Map<String, Rec>)> _load() async => (await loadCourses(user), await fetch('course_enrollments', cols: 'course_id, student_id'), await fetch('attendance', cols: 'course_id, student_id, status'), await profileMap());

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'متابعة الطلاب',
        body: FutureBody<(List<CourseInfo>, List<Rec>, List<Rec>, Map<String, Rec>)>(
          load: _load,
          builder: (context, d, reload) => refreshList(reload, [
            if (d.$1.isEmpty) const Card(child: EmptyBox('لا توجد مقررات مسندة إليك بعد')),
            for (final c in d.$1)
              Builder(builder: (context) {
                final ids = d.$2.where((e) => e['course_id'] == c.id).map((e) => e['student_id'] as String).toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ExpansionTile(
                      shape: const Border(),
                      title: Text('${c.code} · ${c.name}', style: const TextStyle(fontWeight: FontWeight.w800, color: navy, fontSize: 14)),
                      subtitle: Text('${ids.length} طالب', style: const TextStyle(fontSize: 11, color: muted)),
                      children: [
                        if (ids.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('لا يوجد طلاب مسجلون', style: TextStyle(color: muted))),
                        for (final id in ids)
                          Builder(builder: (context) {
                            final rows = d.$3.where((a) => a['course_id'] == c.id && a['student_id'] == id).toList();
                            final good = rows.where((a) => a['status'] == 'present' || a['status'] == 'late').length;
                            final abs = rows.where((a) => a['status'] == 'absent').length;
                            final p = d.$4[id];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.person_outline_rounded, color: blue),
                              title: Text(pname(d.$4, id), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              subtitle: Text((p?['student_number'] ?? '').toString(), style: const TextStyle(fontSize: 11)),
                              trailing: Tag(rows.isEmpty ? 'لا سجلات' : 'حضور ${(good * 100 / rows.length).round()}% · غياب $abs', color: rows.isEmpty ? muted : (abs > 2 ? const Color(0xFFB42318) : const Color(0xFF0F9D8A))),
                            );
                          }),
                      ],
                    ),
                  ),
                );
              }),
          ]),
        ),
      );
}
