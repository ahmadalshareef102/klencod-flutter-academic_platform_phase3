part of '../../main.dart';

// ───────────────────────── المقررات ─────────────────────────

class CoursesPage extends StatelessWidget {
  final AppUser user;
  const CoursesPage({super.key, required this.user});
  @override
  Widget build(BuildContext context) => FutureBody<List<CourseInfo>>(
        load: () => loadCourses(user),
        builder: (context, courses, reload) => refreshList(reload, [
          const SizedBox(height: 10),
          const Text('المقررات الدراسية', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 7),
          Text(user.role == UserRole.student ? 'المقررات المسجل بها' : user.role == UserRole.teacher ? 'المقررات المسندة إليك' : 'جميع مقررات القسم', style: const TextStyle(color: muted)),
          const SizedBox(height: 20),
          if (courses.isEmpty) Card(child: EmptyBox(user.role == UserRole.student ? 'لم يتم تسجيلك في أي مقرر بعد. تتولى الإدارة تسجيل الطلاب في المقررات.' : 'لا توجد مقررات بعد.')),
          for (final c in courses) Padding(padding: const EdgeInsets.only(bottom: 12), child: CourseCard(course: c, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailsPage(course: c, user: user))))),
        ]),
      );
}

class CourseCard extends StatelessWidget {
  final CourseInfo course;
  final VoidCallback onTap;
  const CourseCard({super.key, required this.course, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = course.progress;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: course.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.menu_book_rounded, color: course.color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(course.name, style: const TextStyle(fontWeight: FontWeight.w800, color: navy, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('${course.code}  ·  ${course.teacherName}', style: const TextStyle(fontSize: 11, color: muted)),
                ]),
              ),
              const Icon(Icons.chevron_left_rounded, color: Color(0xFF94A3B8)),
            ]),
            const SizedBox(height: 17),
            Row(children: [
              const Expanded(child: Text('إنجاز المقرر', style: TextStyle(fontSize: 12, color: muted))),
              Text(p == null ? 'لم يبدأ التسجيل' : '${(p * 100).round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: course.color)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: p ?? 0, minHeight: 7, backgroundColor: const Color(0xFFEDF1F6), color: course.color)),
          ]),
        ),
      ),
    );
  }
}

class CourseDetail {
  final List<Rec> lectures;
  final List<Rec> assignments;
  final List<Rec> topics;
  const CourseDetail(this.lectures, this.assignments, this.topics);
}

class CourseDetailsPage extends StatelessWidget {
  final CourseInfo course;
  final AppUser user;
  const CourseDetailsPage({super.key, required this.course, required this.user});

  Future<CourseDetail> _load() async {
    final l = await fetch('lectures', eq: {'course_id': course.id}, orderBy: 'created_at', asc: false);
    final a = await fetch('assignments', eq: {'course_id': course.id}, orderBy: 'created_at', asc: false);
    final t = await fetch('course_progress', eq: {'course_id': course.id}, orderBy: 'updated_at', asc: false);
    return CourseDetail(l, a, t);
  }

  @override
  Widget build(BuildContext context) {
    final p = course.progress;
    return PageScaffold(
      title: 'تفاصيل المقرر',
      body: FutureBody<CourseDetail>(
        load: _load,
        builder: (context, d, reload) => refreshList(reload, [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(course.code, style: const TextStyle(color: Color(0xFFB9D9FF))),
              const SizedBox(height: 8),
              Text(course.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(course.teacherName, style: const TextStyle(color: Colors.white70)),
              if (course.semester.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('الفصل: ${course.semester}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
              if (course.enrolled >= 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('عدد الطلاب المسجلين: ${course.enrolled}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
              const SizedBox(height: 20),
              LinearProgressIndicator(value: p ?? 0, color: Colors.lightBlueAccent, backgroundColor: Colors.white24, minHeight: 8),
              const SizedBox(height: 8),
              Text(p == null ? 'لم يسجل المدرس تقدم المقرر بعد' : 'نسبة الإنجاز ${(p * 100).round()}%', style: const TextStyle(color: Colors.white)),
            ]),
          ),
          if (course.description.isNotEmpty) ...[const SizedBox(height: 16), Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(course.description, style: const TextStyle(height: 1.7, color: navy))))],
          const SizedBox(height: 22),
          const SectionHeading(title: 'المحاضرات', subtitle: 'المواد التعليمية المنشورة'),
          const SizedBox(height: 12),
          if (d.lectures.isEmpty) const Card(child: EmptyBox('لا توجد محاضرات بعد')),
          for (final l in d.lectures) Padding(padding: const EdgeInsets.only(bottom: 10), child: FeatureRow(icon: Icons.picture_as_pdf_outlined, title: '${l['title']}', subtitle: fmtDate(l['created_at']), onTap: () => showLectureDialog(context, l))),
          const SizedBox(height: 14),
          const SectionHeading(title: 'التكليفات', subtitle: 'الواجبات ومواعيد التسليم'),
          const SizedBox(height: 12),
          if (d.assignments.isEmpty) const Card(child: EmptyBox('لا توجد تكليفات بعد')),
          for (final a in d.assignments) Padding(padding: const EdgeInsets.only(bottom: 10), child: FeatureRow(icon: Icons.assignment_outlined, title: '${a['title']}', subtitle: 'التسليم: ${fmtDate(a['due_at'])} · الدرجة العظمى ${a['max_score']}')),
          const SizedBox(height: 14),
          const SectionHeading(title: 'تقدم المقرر', subtitle: 'الموضوعات التي أنجزها المدرس'),
          const SizedBox(height: 12),
          if (d.topics.isEmpty) const Card(child: EmptyBox('لا توجد موضوعات مسجلة')),
          for (final t in d.topics) Padding(padding: const EdgeInsets.only(bottom: 10), child: FeatureRow(icon: Icons.trending_up_rounded, title: '${t['topic']}', subtitle: '${t['completion_percent']}%${(t['notes'] ?? '').toString().isEmpty ? '' : ' · ${t['notes']}'}')),
        ]),
      ),
    );
  }
}
