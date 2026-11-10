part of '../../main.dart';

// ───────────────────────── الإعلانات ─────────────────────────

class AnnouncementsPage extends StatefulWidget {
  final AppUser user;
  const AnnouncementsPage({super.key, required this.user});
  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  int _v = 0;

  Future<void> _add() async {
    final courses = widget.user.role.isStaff ? await loadCourses(widget.user) : <CourseInfo>[];
    if (!mounted) return;
    final r = await formDialog(context, 'إعلان جديد', [
      const FormSpec('title', 'العنوان'),
      const FormSpec('body', 'نص الإعلان', kind: FK.multiline),
      const FormSpec('aud', 'موجّه إلى', kind: FK.dropdown, options: audienceAr),
      FormSpec('course', 'مقرر محدد', kind: FK.dropdown, required: false, options: courseOptions(courses, allowNone: true), initial: ''),
    ], okLabel: 'نشر');
    if (r == null || !mounted) return;
    final ok = await guarded(context, () async {
      await db.from('announcements').insert({'title': r['title']!, 'body': r['body']!, 'audience': r['aud']!, 'course_id': nz(r['course']), 'created_by': widget.user.id});
    }, ok: 'تم نشر الإعلان');
    if (ok && mounted) setState(() => _v++);
  }

  Future<void> _delete(Rec a) async {
    if (!await confirmDialog(context, 'حذف الإعلان "${a['title']}"؟')) return;
    if (!mounted) return;
    final ok = await guarded(context, () async {
      await db.from('announcements').delete().eq('id', a['id']);
    }, ok: 'تم حذف الإعلان');
    if (ok && mounted) setState(() => _v++);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return PageScaffold(
      title: 'الإعلانات',
      fab: u.role.isStaff ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.campaign_outlined), label: const Text('إعلان جديد')) : null,
      body: FutureBody<List<Rec>>(
        key: ValueKey(_v),
        load: () => loadAnnouncements(u),
        builder: (context, list, reload) => refreshList(reload, [
          if (list.isEmpty) const Card(child: EmptyBox('لا توجد إعلانات حتى الآن')),
          for (final a in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NoticeTile(
                icon: Icons.campaign_rounded,
                title: '${a['title']}',
                body: '${a['body']}',
                time: '${fmtDateTime(a['published_at'])} · ${audienceAr[a['audience']] ?? ''}${u.role.isStaff && (u.role.isManager || a['created_by'] == u.id) ? ' · اضغط مطولاً للحذف' : ''}',
                onLongPress: u.role.isStaff && (u.role.isManager || a['created_by'] == u.id) ? () => _delete(a) : null,
              ),
            ),
        ]),
      ),
    );
  }
}
