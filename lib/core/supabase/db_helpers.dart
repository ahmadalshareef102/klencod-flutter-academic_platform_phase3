part of '../../main.dart';

// ───────────────────────── أدوات قاعدة البيانات ─────────────────────────

typedef Rec = Map<String, dynamic>;

SupabaseClient get db => Supabase.instance.client;

Future<List<Rec>> fetch(String table, {String cols = '*', String? orderBy, bool asc = true, Map<String, Object>? eq}) async {
  dynamic q = db.from(table).select(cols);
  if (eq != null) {
    for (final e in eq.entries) {
      q = q.eq(e.key, e.value);
    }
  }
  if (orderBy != null) q = q.order(orderBy, ascending: asc);
  final res = await q;
  return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Future<Map<String, Rec>> profileMap() async {
  final rows = await fetch('profiles', cols: 'id, full_name, email, role, student_number, is_active, department');
  return {for (final r in rows) r['id'] as String: r};
}

String pname(Map<String, Rec> people, dynamic id) => (people[id]?['full_name'] as String?) ?? '—';

String errText(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) return e.message;
  return e.toString();
}

String two(int n) => n.toString().padLeft(2, '0');
String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

String fmtDate(dynamic iso) {
  final d = iso == null ? null : DateTime.tryParse(iso.toString());
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.year}/${two(l.month)}/${two(l.day)}';
}

String fmtDateTime(dynamic iso) {
  final d = iso == null ? null : DateTime.tryParse(iso.toString());
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.year}/${two(l.month)}/${two(l.day)}  ${two(l.hour)}:${two(l.minute)}';
}

const attendanceAr = {'present': 'حاضر', 'absent': 'غائب', 'late': 'متأخر', 'excused': 'بعذر'};
const complaintAr = {'new': 'جديدة', 'in_review': 'قيد المراجعة', 'resolved': 'تم الحل', 'closed': 'مغلقة'};
const audienceAr = {'all': 'الجميع', 'students': 'الطلاب', 'teachers': 'المدرسون', 'department': 'القسم'};

void snack(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// ينفذ عملية ويعرض رسالة نجاح أو خطأ. يعيد true عند النجاح.
Future<bool> guarded(BuildContext context, Future<void> Function() job, {String? ok}) async {
  try {
    await job();
    if (ok != null) snack(context, ok);
    return true;
  } catch (e) {
    snack(context, 'تعذر تنفيذ العملية: ${errText(e)}');
    return false;
  }
}

Future<bool> confirmDialog(BuildContext context, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تأكيد')),
      ],
    ),
  );
  return r == true;
}
