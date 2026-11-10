part of '../../main.dart';

// ───────────────────────── الشكاوى والمقترحات ─────────────────────────

class ComplaintsPage extends StatefulWidget {
  final AppUser user;
  const ComplaintsPage({super.key, required this.user});
  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  int _v = 0;
  bool get _manage => widget.user.role.isManager;

  Future<(List<Rec>, Map<String, Rec>)> _load() async {
    final rows = _manage ? await fetch('complaints', orderBy: 'created_at', asc: false) : await fetch('complaints', eq: {'submitted_by': widget.user.id}, orderBy: 'created_at', asc: false);
    return (rows, _manage ? await profileMap() : <String, Rec>{});
  }

  Future<void> _submit() async {
    final r = await formDialog(context, 'شكوى أو مقترح جديد', const [FormSpec('subject', 'الموضوع'), FormSpec('body', 'التفاصيل', kind: FK.multiline)], okLabel: 'إرسال');
    if (r == null || !mounted) return;
    final ok = await guarded(context, () async {
      await db.from('complaints').insert({'submitted_by': widget.user.id, 'subject': r['subject']!, 'body': r['body']!});
    }, ok: 'تم إرسال شكواك إلى الإدارة');
    if (ok && mounted) setState(() => _v++);
  }

  Future<void> _open(Rec c, Map<String, Rec> people) async {
    final head = 'من: ${_manage ? pname(people, c['submitted_by']) : 'أنت'}\n${fmtDateTime(c['created_at'])}\n\n${c['body']}';
    if (!_manage) {
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('${c['subject']}'),
          content: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(head, style: const TextStyle(height: 1.7)),
              const Divider(height: 24),
              Text('الحالة: ${complaintAr[c['status']] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
              Text((c['response'] ?? '').toString().isEmpty ? 'لم يصل رد بعد' : 'الرد: ${c['response']}', style: const TextStyle(height: 1.7)),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('إغلاق'))],
        ),
      );
      return;
    }
    final r = await formDialog(
      context,
      '${c['subject']}',
      [
        FormSpec('status', 'الحالة', kind: FK.dropdown, options: complaintAr, initial: c['status'] as String?),
        FormSpec('response', 'الرد على صاحب الشكوى', kind: FK.multiline, required: false, initial: (c['response'] ?? '').toString()),
      ],
      intro: head,
    );
    if (r == null || !mounted) return;
    final ok = await guarded(context, () async {
      await db.from('complaints').update({'status': r['status']!, 'response': nz(r['response']), 'handled_by': widget.user.id, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', c['id']);
    }, ok: 'تم تحديث الشكوى');
    if (ok && mounted) setState(() => _v++);
  }

  @override
  Widget build(BuildContext context) {
    const colors = {'new': Color(0xFFF59E0B), 'in_review': blue, 'resolved': Color(0xFF0F9D8A), 'closed': muted};
    return PageScaffold(
      title: _manage ? 'إدارة الشكاوى والمقترحات' : 'الشكاوى والمقترحات',
      fab: _manage ? null : FloatingActionButton.extended(onPressed: _submit, icon: const Icon(Icons.add_rounded), label: const Text('شكوى / مقترح')),
      body: FutureBody<(List<Rec>, Map<String, Rec>)>(
        key: ValueKey(_v),
        load: _load,
        builder: (context, d, reload) => refreshList(reload, [
          if (d.$1.isEmpty) Card(child: EmptyBox(_manage ? 'لا توجد شكاوى أو مقترحات واردة' : 'لم ترسل أي شكوى أو مقترح بعد')),
          for (final c in d.$1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FeatureRow(
                icon: Icons.support_agent_rounded,
                title: '${c['subject']}',
                subtitle: '${_manage ? '${pname(d.$2, c['submitted_by'])} · ' : ''}${fmtDate(c['created_at'])}\n${c['body']}',
                onTap: () => _open(c, d.$2),
                trailing: Tag(complaintAr[c['status']] ?? '', color: colors[c['status']] ?? blue),
              ),
            ),
        ]),
      ),
    );
  }
}
