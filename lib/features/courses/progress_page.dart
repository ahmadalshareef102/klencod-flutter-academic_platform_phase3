part of '../../main.dart';

// ───────────────────────── تقدم المقرر (للمدرس) ─────────────────────────

class ProgressPage extends StatefulWidget {
  final AppUser user;
  const ProgressPage({super.key, required this.user});
  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  int _v = 0;
  List<CourseInfo> _courses = [];

  Future<(List<CourseInfo>, List<Rec>)> _load() async {
    final courses = await loadCourses(widget.user);
    _courses = courses;
    final ids = courses.map((c) => c.id).toSet();
    final t = (await fetch('course_progress', orderBy: 'updated_at', asc: false)).where((x) => ids.contains(x['course_id'])).toList();
    return (courses, t);
  }

  int? _percent(String s) {
    final n = num.tryParse(s);
    if (n == null || n < 0 || n > 100) return null;
    return n.round();
  }

  Future<void> _add() async {
    if (_courses.isEmpty) {
      snack(context, 'لا توجد مقررات مسندة إليك');
      return;
    }
    final r = await formDialog(context, 'موضوع جديد', [
      FormSpec('course', 'المقرر', kind: FK.dropdown, options: courseOptions(_courses)),
      const FormSpec('topic', 'الموضوع الذي تم شرحه'),
      const FormSpec('pct', 'نسبة الإنجاز (0 - 100)', kind: FK.number, initial: '100'),
      const FormSpec('notes', 'ملاحظات', kind: FK.multiline, required: false),
    ]);
    if (r == null || !mounted) return;
    final pct = _percent(r['pct']!);
    if (pct == null) {
      snack(context, 'النسبة يجب أن تكون بين 0 و 100');
      return;
    }
    final ok = await guarded(context, () async {
      await db.from('course_progress').insert({'course_id': r['course']!, 'teacher_id': widget.user.id, 'topic': r['topic']!, 'completion_percent': pct, 'notes': nz(r['notes'])});
    }, ok: 'تم تسجيل الموضوع');
    if (ok && mounted) setState(() => _v++);
  }

  Future<void> _edit(Rec t) async {
    final r = await formDialog(context, '${t['topic']}', [
      FormSpec('pct', 'نسبة الإنجاز (0 - 100)', kind: FK.number, initial: '${t['completion_percent']}'),
      FormSpec('notes', 'ملاحظات', kind: FK.multiline, required: false, initial: (t['notes'] ?? '').toString()),
    ]);
    if (r == null || !mounted) return;
    final pct = _percent(r['pct']!);
    if (pct == null) {
      snack(context, 'النسبة يجب أن تكون بين 0 و 100');
      return;
    }
    final ok = await guarded(context, () async {
      await db.from('course_progress').update({'completion_percent': pct, 'notes': nz(r['notes']), 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', t['id']);
    }, ok: 'تم التحديث');
    if (ok && mounted) setState(() => _v++);
  }

  Future<void> _delete(Rec t) async {
    if (!await confirmDialog(context, 'حذف الموضوع "${t['topic']}"؟')) return;
    if (!mounted) return;
    final ok = await guarded(context, () async {
      await db.from('course_progress').delete().eq('id', t['id']);
    }, ok: 'تم الحذف');
    if (ok && mounted) setState(() => _v++);
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'تقدم المقرر',
        fab: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('موضوع جديد')),
        body: FutureBody<(List<CourseInfo>, List<Rec>)>(
          key: ValueKey(_v),
          load: _load,
          builder: (context, d, reload) => refreshList(reload, [
            if (d.$1.isEmpty) const Card(child: EmptyBox('لا توجد مقررات مسندة إليك بعد')),
            for (final c in d.$1) ...[
              Padding(padding: const EdgeInsets.only(top: 6, bottom: 8), child: Row(children: [Expanded(child: SectionHeading(title: '${c.code} · ${c.name}')), Text(c.progress == null ? '—' : '${(c.progress! * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w800, color: c.color))])),
              if (d.$2.where((t) => t['course_id'] == c.id).isEmpty) const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('لم تسجل أي موضوع بعد', style: TextStyle(color: muted, fontSize: 12))),
              for (final t in d.$2.where((t) => t['course_id'] == c.id))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FeatureRow(
                    icon: Icons.trending_up_rounded,
                    title: '${t['topic']}',
                    subtitle: '${t['completion_percent']}% · ${fmtDate(t['updated_at'])}${(t['notes'] ?? '').toString().isEmpty ? '' : '\n${t['notes']}'}',
                    onTap: () => _edit(t),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB42318)), onPressed: () => _delete(t)),
                  ),
                ),
            ],
          ]),
        ),
      );
}
