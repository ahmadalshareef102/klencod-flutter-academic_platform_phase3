part of '../../main.dart';

// ───────────────────────── تسجيل الحضور (للمدرس) ─────────────────────────

class AttendanceTakePage extends StatefulWidget {
  final AppUser user;
  const AttendanceTakePage({super.key, required this.user});
  @override
  State<AttendanceTakePage> createState() => _AttendanceTakePageState();
}

class _AttendanceTakePageState extends State<AttendanceTakePage> {
  List<CourseInfo> _courses = [];
  String? _courseId;
  DateTime _date = DateTime.now();
  List<Rec> _students = [];
  final Map<String, String> _status = {};
  bool _loading = true;
  bool _saving = false;
  bool _existing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = await loadCourses(widget.user);
      if (!mounted) return;
      setState(() {
        _courses = c;
        _courseId = c.isEmpty ? null : c.first.id;
      });
      await _loadSheet();
    } catch (e) {
      if (mounted) setState(() { _error = errText(e); _loading = false; });
    }
  }

  Future<void> _loadSheet() async {
    if (_courseId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final people = await profileMap();
      final enr = await fetch('course_enrollments', cols: 'student_id', eq: {'course_id': _courseId!});
      final ids = enr.map((e) => e['student_id'] as String).toSet();
      final st = people.values.where((p) => ids.contains(p['id'])).toList();
      st.sort((a, b) => '${a['full_name']}'.compareTo('${b['full_name']}'));
      final old = await fetch('attendance', cols: 'student_id, status', eq: {'course_id': _courseId!, 'session_date': dayKey(_date)});
      if (!mounted) return;
      setState(() {
        _students = st;
        _status.clear();
        for (final s in st) {
          final rec = old.where((o) => o['student_id'] == s['id']).toList();
          _status[s['id'] as String] = rec.isEmpty ? 'present' : rec.first['status'] as String;
        }
        _existing = old.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = errText(e); _loading = false; });
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d == null) return;
    setState(() => _date = d);
    await _loadSheet();
  }

  Future<void> _save() async {
    if (_students.isEmpty || _courseId == null) return;
    setState(() => _saving = true);
    final rows = [
      for (final s in _students) {'course_id': _courseId, 'student_id': s['id'], 'session_date': dayKey(_date), 'status': _status[s['id']] ?? 'present', 'recorded_by': widget.user.id},
    ];
    final ok = await guarded(context, () async {
      await db.from('attendance').upsert(rows, onConflict: 'course_id,student_id,session_date');
    }, ok: 'تم حفظ سجل الحضور');
    if (mounted) {
      setState(() { _saving = false; if (ok) _existing = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    const colors = {'present': Color(0xFF0F9D8A), 'late': Color(0xFFF59E0B), 'absent': Color(0xFFB42318), 'excused': blue};
    return PageScaffold(
      title: 'تسجيل الحضور',
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر التحميل\n$_error', textAlign: TextAlign.center)))
          : (!_loading && _courses.isEmpty)
              ? const Center(child: EmptyBox('لا توجد مقررات مسندة إليك بعد. تتولى الإدارة إسناد المقررات للمدرسين.'))
              : ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 40), children: [
                  if (_courses.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _courseId,
                      isExpanded: true,
                      items: courseOptions(_courses).entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) {
                        setState(() => _courseId = v);
                        _loadSheet();
                      },
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_month_outlined), label: Padding(padding: const EdgeInsets.all(10), child: Text('تاريخ الجلسة: ${dayKey(_date)}'))),
                  if (_existing) const Padding(padding: EdgeInsets.only(top: 8), child: Text('يوجد سجل محفوظ لهذا اليوم. التعديل سيحدّثه.', style: TextStyle(color: Color(0xFF9A6700), fontSize: 12))),
                  const SizedBox(height: 12),
                  if (_loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
                  if (!_loading && _students.isEmpty) const Card(child: EmptyBox('لا يوجد طلاب مسجلون في هذا المقرر بعد')),
                  if (!_loading && _students.isNotEmpty) ...[
                    Row(children: [
                      Expanded(child: Text('${_students.length} طالب', style: const TextStyle(fontWeight: FontWeight.w800, color: navy))),
                      TextButton(onPressed: () => setState(() { for (final s in _students) { _status[s['id'] as String] = 'present'; } }), child: const Text('الكل حاضر')),
                    ]),
                    for (final s in _students)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${s['full_name']}', style: const TextStyle(fontWeight: FontWeight.w700, color: navy)),
                              const SizedBox(height: 8),
                              Wrap(spacing: 6, children: [
                                for (final k in attendanceAr.keys)
                                  ChoiceChip(
                                    label: Text(attendanceAr[k]!, style: TextStyle(fontSize: 12, color: _status[s['id']] == k ? Colors.white : navy)),
                                    selected: _status[s['id']] == k,
                                    selectedColor: colors[k],
                                    showCheckmark: false,
                                    onSelected: (_) => setState(() => _status[s['id'] as String] = k),
                                  ),
                              ]),
                            ]),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined), label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ سجل الحضور'))),
                  ],
                ]),
    );
  }
}
