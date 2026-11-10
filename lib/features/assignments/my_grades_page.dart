part of '../../main.dart';

// ───────────────────────── درجاتي ─────────────────────────

class MyGradesPage extends StatelessWidget {
  final AppUser user;
  const MyGradesPage({super.key, required this.user});

  Future<(List<Rec>, List<Rec>)> _load() async {
    final subs = await fetch('submissions', eq: {'student_id': user.id}, orderBy: 'submitted_at', asc: false);
    final asg = await fetch('assignments', cols: 'id, title, max_score');
    return (subs, asg);
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'درجاتي',
        body: FutureBody<(List<Rec>, List<Rec>)>(
          load: _load,
          builder: (context, d, reload) {
            final graded = d.$1.where((s) => s['score'] != null).toList();
            double tot = 0, mx = 0;
            for (final s in graded) {
              final a = d.$2.where((x) => x['id'] == s['assignment_id']).toList();
              if (a.isEmpty) continue;
              tot += (s['score'] as num).toDouble();
              mx += (a.first['max_score'] as num).toDouble();
            }
            return refreshList(reload, [
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Icon(Icons.grade_outlined, color: blue), const SizedBox(width: 10), Expanded(child: Text(mx == 0 ? 'لا توجد درجات مصححة بعد' : 'المجموع: ${tot.toStringAsFixed(1)} من ${mx.toStringAsFixed(1)}  (${(tot * 100 / mx).round()}%)', style: const TextStyle(fontWeight: FontWeight.w800, color: navy)))]))),
              const SizedBox(height: 14),
              if (d.$1.isEmpty) const Card(child: EmptyBox('لم تسلّم أي تكليف بعد')),
              for (final s in d.$1)
                Builder(builder: (context) {
                  final a = d.$2.where((x) => x['id'] == s['assignment_id']).toList();
                  final title = a.isEmpty ? 'تكليف' : '${a.first['title']}';
                  final max = a.isEmpty ? '' : ' / ${a.first['max_score']}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FeatureRow(
                      icon: Icons.assignment_turned_in_outlined,
                      title: title,
                      subtitle: '${s['score'] == null ? 'قيد التصحيح' : 'الدرجة: ${s['score']}$max'}${(s['feedback'] ?? '').toString().isEmpty ? '' : '\nملاحظات: ${s['feedback']}'}',
                    ),
                  );
                }),
            ]);
          },
        ),
      );
}
