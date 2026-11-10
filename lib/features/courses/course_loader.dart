part of '../../main.dart';

// ───────────────────────── المقررات (نموذج مشترك) ─────────────────────────

class CourseInfo {
  final String id;
  final String code;
  final String name;
  final String description;
  final String semester;
  final String? teacherId;
  final String teacherName;
  final bool published;
  final double? progress;
  final int enrolled;
  const CourseInfo({required this.id, required this.code, required this.name, required this.description, required this.semester, required this.teacherId, required this.teacherName, required this.published, required this.progress, required this.enrolled});
  Color get color => palette[code.hashCode.abs() % palette.length];
}

/// المقررات المتاحة للمستخدم حسب صلاحيته: الطالب = المسجل بها، المدرس = مقرراته، الإدارة/الرئيس = الكل.
Future<List<CourseInfo>> loadCourses(AppUser u) async {
  final rows = await fetch('courses', orderBy: 'code');
  final people = await profileMap();
  final prog = await fetch('course_progress', cols: 'course_id, completion_percent');
  final enr = await fetch('course_enrollments', cols: 'course_id, student_id');
  final mine = u.role == UserRole.student ? enr.where((e) => e['student_id'] == u.id).map((e) => e['course_id'] as String).toSet() : <String>{};
  final out = <CourseInfo>[];
  for (final c in rows) {
    final id = c['id'] as String;
    if (u.role == UserRole.student && !mine.contains(id)) continue;
    if (u.role == UserRole.teacher && c['teacher_id'] != u.id) continue;
    final ps = prog.where((p) => p['course_id'] == id).map((p) => (p['completion_percent'] as num).toDouble()).toList();
    out.add(CourseInfo(
      id: id,
      code: (c['code'] as String?) ?? '',
      name: (c['name'] as String?) ?? '',
      description: (c['description'] as String?) ?? '',
      semester: (c['semester'] as String?) ?? '',
      teacherId: c['teacher_id'] as String?,
      teacherName: c['teacher_id'] == null ? 'لم يُحدد المدرس' : pname(people, c['teacher_id']),
      published: c['is_published'] == true,
      progress: ps.isEmpty ? null : ps.reduce((a, b) => a + b) / ps.length / 100,
      enrolled: u.role == UserRole.student ? -1 : enr.where((e) => e['course_id'] == id).length,
    ));
  }
  return out;
}

Map<String, String> courseOptions(List<CourseInfo> list, {bool allowNone = false}) => {
      if (allowNone) '': '— بدون مقرر —',
      for (final c in list) c.id: '${c.code} · ${c.name}',
    };
