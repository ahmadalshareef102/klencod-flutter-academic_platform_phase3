part of '../../main.dart';

// ───────────────────────── إدارة المقررات ─────────────────────────

class CoursesAdminPage extends StatefulWidget {
  final AppUser user;
  final String title;
  const CoursesAdminPage({super.key, required this.user, required this.title});
  @override
  State<CoursesAdminPage> createState() => _CoursesAdminPageState();
}

class _CoursesAdminPageState extends State<CoursesAdminPage> {
  int _v = 0;
  Map<String, String> _teachers = {'': '— بدون مدرس —'};

  Future<List<CourseInfo>> _load() async {
    final people = (await profileMap()).values.where((p) => p['role'] == 'teacher' && p['is_active'] == true).toList();
    _teachers = {'': '— بدون مدرس —', for (final p in people) p['id'] as String: '${p['full_name']}'};
    return loadCourses(widget.user);
  }

  Future<void> _add() async {
    final r = await formDialog(context, 'مقرر جديد', [
      const FormSpec('code', 'رمز المقرر (فريد)'),
      const FormSpec('name', 'اسم المقرر'),
      const FormSpec('desc', 'الوصف', kind: FK.multiline, required: false),
      const FormSpec('sem', 'الفصل الدراسي', required: false),
      FormSpec('teacher', 'المدرس', kind: FK.dropdown, required: false, options: _teachers, initial: ''),
    ]);
    if (r == null || !mounted) return;
    final ok = await guarded(context, () async {
      await db.from('courses').insert({'code': r['code']!, 'name': r['name']!, 'description': nz(r['desc']), 'semester': nz(r['sem']), 'teacher_id': nz(r['teacher']), 'is_published': true});
    }, ok: 'تمت إضافة المقرر');
    if (ok && mounted) setState(() => _v++);
  }

  Future<void> _edit(CourseInfo c) async {
    final r = await formDialog(context, 'تعديل ${c.code}', [
      FormSpec('name', 'اسم المقرر', initial: c.name),
      FormSpec('desc', 'الوصف', kind: FK.multiline, required: false, initial: c.description),
      FormSpec('sem', 'الفصل الدراسي', required: false, initial: c.semester),
      FormSpec('teacher', 'المدرس', kind: FK.dropdown, required: false, options: _teachers, initial: c.teacherId ?? ''),
      FormSpec('pub', 'حالة النشر', kind: FK.dropdown, options: const {'true': 'منشور', 'false': 'مخفي عن الطلاب'}, initial: c.published ? 'true' : 'false'),
    ]);
    if (r == null || !mounted) return;
    final ok = await guarded(context, () async {
      await db.from('courses').update({'name': r['name']!, 'description': nz(r['desc']), 'semester': nz(r['sem']), 'teacher_id': nz(r['teacher']), 'is_published': r['pub'] == 'true'}).eq('id', c.id);
    }, ok: 'تم حفظ التعديلات');
    if (ok && mounted) setState(() => _v++);
  }

  Future<void> _delete(CourseInfo c) async {
    if (!await confirmDialog(context, 'حذف المقرر "${c.name}" نهائياً مع محاضراته وتكليفاته وسجلات حضوره؟')) return;
    if (!mounted) return;
    final ok = await guarded(context, () async {
      await db.from('courses').delete().eq('id', c.id);
    }, ok: 'تم حذف المقرر');
    if (ok && mounted) setState(() => _v++);
  }

  void _menu(CourseInfo c) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('عرض التفاصيل'), onTap: () { Navigator.pop(sheet); Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailsPage(course: c, user: widget.user))); }),
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('تعديل المقرر وتعيين المدرس'), onTap: () { Navigator.pop(sheet); _edit(c); }),
          ListTile(leading: const Icon(Icons.groups_2_outlined), title: const Text('تسجيل الطلاب في المقرر'), onTap: () { Navigator.pop(sheet); Navigator.of(context).push(MaterialPageRoute(builder: (_) => EnrollmentsPage(course: c))).then((_) { if (mounted) setState(() => _v++); }); }),
          ListTile(leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB42318)), title: const Text('حذف المقرر', style: TextStyle(color: Color(0xFFB42318))), onTap: () { Navigator.pop(sheet); _delete(c); }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: widget.title,
        fab: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('مقرر جديد')),
        body: FutureBody<List<CourseInfo>>(
          key: ValueKey(_v),
          load: _load,
          builder: (context, list, reload) => refreshList(reload, [
            if (list.isEmpty) const Card(child: EmptyBox('لا توجد مقررات بعد. اضغط "مقرر جديد" لإضافة أول مقرر.')),
            for (final c in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FeatureRow(
                  icon: Icons.menu_book_rounded,
                  title: '${c.code} · ${c.name}',
                  subtitle: '${c.teacherName}\nالطلاب المسجلون: ${c.enrolled}${c.published ? '' : ' · مخفي'}',
                  onTap: () => _menu(c),
                  trailing: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
                ),
              ),
          ]),
        ),
      );
}

class EnrollmentsPage extends StatefulWidget {
  final CourseInfo course;
  const EnrollmentsPage({super.key, required this.course});
  @override
  State<EnrollmentsPage> createState() => _EnrollmentsPageState();
}

class _EnrollmentsPageState extends State<EnrollmentsPage> {
  List<Rec> _students = [];
  Set<String> _enrolled = {};
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final people = await profileMap();
      final enr = await fetch('course_enrollments', cols: 'student_id', eq: {'course_id': widget.course.id});
      final st = people.values.where((p) => p['role'] == 'student' && p['is_active'] == true).toList();
      st.sort((a, b) => '${a['full_name']}'.compareTo('${b['full_name']}'));
      if (!mounted) return;
      setState(() {
        _students = st;
        _enrolled = enr.map((e) => e['student_id'] as String).toSet();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() { _error = errText(e); _loading = false; });
    }
  }

  Future<void> _toggle(Rec s, bool on) async {
    final id = s['id'] as String;
    final ok = await guarded(context, () async {
      if (on) {
        await db.from('course_enrollments').insert({'course_id': widget.course.id, 'student_id': id});
      } else {
        await db.from('course_enrollments').delete().eq('course_id', widget.course.id).eq('student_id', id);
      }
    });
    if (ok && mounted) setState(() => on ? _enrolled.add(id) : _enrolled.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final list = _students.where((s) => _search.isEmpty || '${s['full_name']} ${s['student_number'] ?? ''}'.toLowerCase().contains(_search.toLowerCase())).toList();
    return PageScaffold(
      title: 'طلاب ${widget.course.code}',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر التحميل\n$_error', textAlign: TextAlign.center)))
              : ListView(padding: const EdgeInsets.all(18), children: [
                  Text('المسجلون: ${_enrolled.length} من ${_students.length} طالب', style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
                  const SizedBox(height: 10),
                  TextField(onChanged: (v) => setState(() => _search = v.trim()), decoration: const InputDecoration(hintText: 'بحث بالاسم أو الرقم الجامعي', prefixIcon: Icon(Icons.search_rounded))),
                  const SizedBox(height: 10),
                  if (_students.isEmpty) const Card(child: EmptyBox('لا يوجد طلاب بعد. أنشئ حسابات الطلاب أولاً من إدارة المستخدمين.')),
                  for (final s in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: CheckboxListTile(
                          value: _enrolled.contains(s['id']),
                          onChanged: (v) => _toggle(s, v == true),
                          title: Text('${s['full_name']}', style: const TextStyle(fontWeight: FontWeight.w700, color: navy, fontSize: 13)),
                          subtitle: Text((s['student_number'] ?? s['email']).toString(), style: const TextStyle(fontSize: 11, color: muted)),
                        ),
                      ),
                    ),
                ]),
    );
  }
}
