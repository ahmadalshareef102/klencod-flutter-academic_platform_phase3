part of '../../main.dart';

// ───────────────────────── المحاضرات ─────────────────────────

void showLectureDialog(BuildContext context, Rec l) {
  final link = (l['file_path'] ?? '').toString();
  final desc = (l['description'] ?? '').toString();
  showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('${l['title']}'),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (desc.isNotEmpty) Text(desc, style: const TextStyle(height: 1.7)),
          if (desc.isNotEmpty) const SizedBox(height: 12),
          Text('تاريخ النشر: ${fmtDate(l['created_at'])}', style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 12),
          if (link.isEmpty) const Text('لا يوجد ملف مرفق بهذه المحاضرة.', style: TextStyle(color: muted)) else ...[const Text('رابط الملف:', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6), SelectableText(link, style: const TextStyle(color: blue))],
        ]),
      ),
      actions: [
        if (link.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (c.mounted) {
                Navigator.pop(c);
                snack(context, 'تم نسخ الرابط');
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('نسخ الرابط'),
          ),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
      ],
    ),
  );
}

class LecturesPage extends StatefulWidget {
  final AppUser user;
  const LecturesPage({super.key, required this.user});
  @override
  State<LecturesPage> createState() => _LecturesPageState();
}

class _LecturesPageState extends State<LecturesPage> {
  int _v = 0;
  List<CourseInfo> _courses = [];

  Future<(List<CourseInfo>, List<Rec>)> _load() async {
    final courses = await loadCourses(widget.user);
    _courses = courses;
    final ids = courses.map((c) => c.id).toSet();
    final lec = (await fetch('lectures', orderBy: 'created_at', asc: false)).where((l) => ids.contains(l['course_id'])).toList();
    return (courses, lec);
  }

  Future<void> _add() async {
    if (_courses.isEmpty) {
      snack(context, 'لا توجد مقررات متاحة لإضافة محاضرة إليها');
      return;
    }
    final r = await formDialog(context, 'إضافة محاضرة', [
      FormSpec('course', 'المقرر', kind: FK.dropdown, options: courseOptions(_courses)),
      const FormSpec('title', 'عنوان المحاضرة'),
      const FormSpec('desc', 'الوصف', kind: FK.multiline, required: false),
      const FormSpec('link', 'رابط الملف (Google Drive أو غيره)', required: false),
    ]);
    if (r == null || !mounted) return;
    final ok = await guarded(context, () async {
      await db.from('lectures').insert({
        'course_id': r['course']!,
        'title': r['title']!,
        'description': nz(r['desc']),
        'file_path': nz(r['link']),
        'published_at': DateTime.now().toUtc().toIso8601String(),
        'created_by': widget.user.id,
      });
    }, ok: 'تمت إضافة المحاضرة');
    if (ok && mounted) setState(() => _v++);
  }

  Future<void> _delete(Rec l) async {
    if (!await confirmDialog(context, 'حذف المحاضرة "${l['title']}"؟')) return;
    if (!mounted) return;
    final ok = await guarded(context, () async {
      await db.from('lectures').delete().eq('id', l['id']);
    }, ok: 'تم حذف المحاضرة');
    if (ok && mounted) setState(() => _v++);
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.user.role.isStaff;
    return PageScaffold(
      title: staff ? 'إدارة المحاضرات' : 'ملفات المحاضرات',
      fab: staff ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('محاضرة جديدة')) : null,
      body: FutureBody<(List<CourseInfo>, List<Rec>)>(
        key: ValueKey(_v),
        load: _load,
        builder: (context, data, reload) {
          final byId = {for (final c in data.$1) c.id: c};
          return refreshList(reload, [
            if (data.$2.isEmpty) Card(child: EmptyBox(staff ? 'لم تُضف أي محاضرة بعد. اضغط "محاضرة جديدة".' : 'لا توجد محاضرات منشورة في مقرراتك بعد.')),
            for (final l in data.$2)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FeatureRow(
                  icon: Icons.picture_as_pdf_outlined,
                  title: '${l['title']}',
                  subtitle: '${byId[l['course_id']]?.code ?? ''} · ${byId[l['course_id']]?.name ?? ''} · ${fmtDate(l['created_at'])}',
                  onTap: () => showLectureDialog(context, l),
                  trailing: staff && (widget.user.role.isManager || l['created_by'] == widget.user.id) ? IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB42318)), onPressed: () => _delete(l)) : null,
                ),
              ),
          ]);
        },
      ),
    );
  }
}
