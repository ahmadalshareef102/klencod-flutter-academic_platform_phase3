part of '../../main.dart';

// ───────────────────────── التكليفات ─────────────────────────

class AssignmentsPage extends StatefulWidget {
  final AppUser user;
  const AssignmentsPage({super.key, required this.user});
  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AsgData {
  final List<CourseInfo> courses;
  final List<Rec> assignments;
  final List<Rec> submissions;
  const _AsgData(this.courses, this.assignments, this.submissions);
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  int _v = 0;
  List<CourseInfo> _courses = [];

  Future<_AsgData> _load() async {
    final u = widget.user;
    final courses = await loadCourses(u);
    _courses = courses;
    final ids = courses.map((c) => c.id).toSet();
    final asg = (await fetch('assignments', orderBy: 'created_at', asc: false)).where((a) => ids.contains(a['course_id'])).toList();
    final subs = u.role == UserRole.student ? await fetch('submissions', eq: {'student_id': u.id}) : await fetch('submissions', cols: 'id, assignment_id');
    return _AsgData(courses, asg, subs);
  }

  Future<void> _add() async {
    if (_courses.isEmpty) {
      snack(context, 'لا توجد مقررات متاحة لإضافة تكليف إليها');
      return;
    }
    final r = await formDialog(context, 'تكليف جديد', [
      FormSpec('course', 'المقرر', kind: FK.dropdown, options: courseOptions(_courses)),
      const FormSpec('title', 'عنوان التكليف'),
      const FormSpec('instr', 'التعليمات', kind: FK.multiline, required: false),
      const FormSpec('due', 'آخر موعد للتسليم', kind: FK.date, required: false),
      const FormSpec('max', 'الدرجة العظمى', kind: FK.number, initial: '100'),
    ]);
    if (r == null || !mounted) return;
    final due = nz(r['due']);
    final ok = await guarded(context, () async {
      await db.from('assignments').insert({
        'course_id': r['course']!,
        'title': r['title']!,
        'instructions': nz(r['instr']),
        'due_at': due == null ? null : DateTime.parse('${due}T23:59:00').toUtc().toIso8601String(),
        'max_score': num.parse(r['max']!),
        'created_by': widget.user.id,
      });
    }, ok: 'تم إنشاء التكليف');
    if (ok && mounted) setState(() => _v++);
  }

  Future<void> _delete(Rec a) async {
    if (!await confirmDialog(context, 'حذف التكليف "${a['title']}" مع كل التسليمات المرتبطة به؟')) return;
    if (!mounted) return;
    final ok = await guarded(context, () async {
      await db.from('assignments').delete().eq('id', a['id']);
    }, ok: 'تم حذف التكليف');
    if (ok && mounted) setState(() => _v++);
  }

  Future<void> _openStudent(Rec a, Rec? sub) async {
    if (sub != null) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('${a['title']}'),
          content: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('تاريخ التسليم: ${fmtDateTime(sub['submitted_at'])}', style: const TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 10),
              const Text('إجابتك:', style: TextStyle(fontWeight: FontWeight.w700)),
              Text((sub['answer_text'] ?? '—').toString(), style: const TextStyle(height: 1.6)),
              if ((sub['file_path'] ?? '').toString().isNotEmpty) ...[const SizedBox(height: 8), SelectableText('الرابط: ${sub['file_path']}', style: const TextStyle(color: blue))],
              const Divider(height: 24),
              Text(sub['score'] == null ? 'لم تُصحح بعد' : 'الدرجة: ${sub['score']} / ${a['max_score']}', style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
              if ((sub['feedback'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('ملاحظات المدرس: ${sub['feedback']}', style: const TextStyle(height: 1.6))),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق'))],
        ),
      );
      return;
    }
    final r = await formDialog(
      context,
      '${a['title']}',
      const [FormSpec('answer', 'إجابتك', kind: FK.multiline, required: false), FormSpec('link', 'رابط ملف الحل (اختياري)', required: false)],
      okLabel: 'تسليم',
      intro: '${(a['instructions'] ?? 'لا توجد تعليمات إضافية').toString()}\n\nآخر موعد: ${fmtDateTime(a['due_at'])} · الدرجة العظمى: ${a['max_score']}\nلا يمكن تعديل التسليم بعد إرساله.',
    );
    if (r == null || !mounted) return;
    if (nz(r['answer']) == null && nz(r['link']) == null) {
      snack(context, 'اكتب إجابتك أو ضع رابط الحل');
      return;
    }
    final ok = await guarded(context, () async {
      await db.from('submissions').insert({'assignment_id': a['id'], 'student_id': widget.user.id, 'answer_text': nz(r['answer']), 'file_path': nz(r['link'])});
    }, ok: 'تم تسليم التكليف');
    if (ok && mounted) setState(() => _v++);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final staff = u.role.isStaff;
    return PageScaffold(
      title: staff ? 'إدارة التكليفات' : 'الواجبات والتكليفات',
      fab: staff ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('تكليف جديد')) : null,
      body: FutureBody<_AsgData>(
        key: ValueKey(_v),
        load: _load,
        builder: (context, d, reload) {
          final byId = {for (final c in d.courses) c.id: c};
          final now = DateTime.now();
          return refreshList(reload, [
            if (d.assignments.isEmpty) Card(child: EmptyBox(staff ? 'لا توجد تكليفات بعد. اضغط "تكليف جديد".' : 'لا توجد تكليفات في مقرراتك حالياً.')),
            for (final a in d.assignments)
              Builder(builder: (context) {
                final course = byId[a['course_id']];
                final due = a['due_at'] == null ? null : DateTime.tryParse(a['due_at'].toString());
                final sub = d.submissions.where((s) => s['assignment_id'] == a['id']).toList();
                Widget tag;
                if (staff) {
                  tag = Tag('${sub.length} تسليم');
                } else if (sub.isNotEmpty) {
                  tag = Tag(sub.first['score'] == null ? 'تم التسليم' : '${sub.first['score']}/${a['max_score']}', color: const Color(0xFF0F9D8A));
                } else if (due != null && due.isBefore(now)) {
                  tag = const Tag('انتهى الموعد', color: Color(0xFFB42318));
                } else {
                  tag = const Tag('مطلوب', color: Color(0xFFF59E0B));
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FeatureRow(
                    icon: Icons.assignment_outlined,
                    title: '${a['title']}',
                    subtitle: '${course?.code ?? ''} · ${course?.name ?? ''}\nالتسليم: ${fmtDate(a['due_at'])} · الدرجة العظمى ${a['max_score']}',
                    onTap: staff ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SubmissionsPage(user: u, assignment: a))).then((_) => setState(() => _v++)) : () => _openStudent(a, sub.isEmpty ? null : sub.first),
                    trailing: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                      tag,
                      if (staff && (u.role.isManager || a['created_by'] == u.id)) InkWell(onTap: () => _delete(a), child: const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFB42318)))),
                    ]),
                  ),
                );
              }),
          ]);
        },
      ),
    );
  }
}

class SubmissionsPage extends StatefulWidget {
  final AppUser user;
  final Rec assignment;
  const SubmissionsPage({super.key, required this.user, required this.assignment});
  @override
  State<SubmissionsPage> createState() => _SubmissionsPageState();
}

class _SubmissionsPageState extends State<SubmissionsPage> {
  int _v = 0;

  Future<(List<Rec>, Map<String, Rec>)> _load() async {
    final subs = await fetch('submissions', eq: {'assignment_id': widget.assignment['id'] as Object}, orderBy: 'submitted_at', asc: false);
    return (subs, await profileMap());
  }

  Future<void> _grade(Rec s, String studentName) async {
    final max = widget.assignment['max_score'];
    final r = await formDialog(
      context,
      'تصحيح: $studentName',
      [
        FormSpec('score', 'الدرجة (من $max)', kind: FK.number, initial: s['score']?.toString()),
        FormSpec('feedback', 'ملاحظات للطالب', kind: FK.multiline, required: false, initial: (s['feedback'] ?? '').toString()),
      ],
      intro: 'إجابة الطالب:\n${(s['answer_text'] ?? '—').toString()}${(s['file_path'] ?? '').toString().isEmpty ? '' : '\nالرابط: ${s['file_path']}'}',
    );
    if (r == null || !mounted) return;
    final score = num.parse(r['score']!);
    if (score < 0 || score > (max as num)) {
      snack(context, 'الدرجة يجب أن تكون بين 0 و $max');
      return;
    }
    final ok = await guarded(context, () async {
      await db.from('submissions').update({'score': score, 'feedback': nz(r['feedback']), 'graded_by': widget.user.id}).eq('id', s['id']);
    }, ok: 'تم حفظ الدرجة');
    if (ok && mounted) setState(() => _v++);
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: '${widget.assignment['title']}',
        body: FutureBody<(List<Rec>, Map<String, Rec>)>(
          key: ValueKey(_v),
          load: _load,
          builder: (context, d, reload) => refreshList(reload, [
            if (d.$1.isEmpty) const Card(child: EmptyBox('لم يسلّم أي طالب هذا التكليف بعد')),
            for (final s in d.$1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FeatureRow(
                  icon: Icons.person_outline_rounded,
                  title: pname(d.$2, s['student_id']),
                  subtitle: 'سُلّم: ${fmtDateTime(s['submitted_at'])}',
                  onTap: () => _grade(s, pname(d.$2, s['student_id'])),
                  trailing: s['score'] == null ? const Tag('بانتظار التصحيح', color: Color(0xFFF59E0B)) : Tag('${s['score']}/${widget.assignment['max_score']}', color: const Color(0xFF0F9D8A)),
                ),
              ),
          ]),
        ),
      );
}
