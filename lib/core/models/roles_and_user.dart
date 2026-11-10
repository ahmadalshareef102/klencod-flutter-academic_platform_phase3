part of '../../main.dart';

// ───────────────────────── الأدوار والمستخدم ─────────────────────────

enum UserRole { student, teacher, head, admin }

extension RoleDetails on UserRole {
  String get label => switch (this) {
        UserRole.student => 'طالب',
        UserRole.teacher => 'مدرس',
        UserRole.head => 'رئيس القسم',
        UserRole.admin => 'إدارة الكلية',
      };
  String get key => switch (this) {
        UserRole.student => 'student',
        UserRole.teacher => 'teacher',
        UserRole.head => 'head',
        UserRole.admin => 'admin',
      };
  String get greeting => switch (this) {
        UserRole.student => 'مرحباً بك في رحلتك التعليمية',
        UserRole.teacher => 'إدارة مقرراتك ومتابعة طلابك',
        UserRole.head => 'متابعة أداء القسم والمقررات',
        UserRole.admin => 'نظرة شاملة على العملية التعليمية',
      };
  IconData get icon => switch (this) {
        UserRole.student => Icons.school_rounded,
        UserRole.teacher => Icons.cast_for_education_rounded,
        UserRole.head => Icons.account_tree_rounded,
        UserRole.admin => Icons.admin_panel_settings_rounded,
      };
  bool get isStaff => this != UserRole.student;
  bool get isManager => this == UserRole.admin || this == UserRole.head;
}

UserRole? parseRole(String? v) {
  for (final r in UserRole.values) {
    if (r.key == v) return r;
  }
  return null;
}

String roleLabel(String? v) => parseRole(v)?.label ?? (v ?? '—');

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? studentNumber;
  const AppUser({required this.id, required this.name, required this.email, required this.role, this.studentNumber});
}

Future<AppUser> loadAppUser(User user) async {
  final p = await db.from('profiles').select('full_name, email, role, is_active, student_number').eq('id', user.id).maybeSingle();
  if (p == null) {
    await db.auth.signOut();
    throw const AuthException('الحساب غير مضاف إلى ملفات المنصة. راجع إدارة الكلية.');
  }
  if (p['is_active'] == false) {
    await db.auth.signOut();
    throw const AuthException('هذا الحساب موقوف. راجع إدارة الكلية.');
  }
  final role = parseRole(p['role'] as String?);
  if (role == null) {
    await db.auth.signOut();
    throw const AuthException('صلاحية الحساب غير صحيحة؛ راجع إدارة المنصة.');
  }
  final fullName = (p['full_name'] as String?)?.trim() ?? '';
  return AppUser(
    id: user.id,
    name: fullName.isNotEmpty ? fullName : (user.email ?? ''),
    email: (p['email'] as String?) ?? (user.email ?? ''),
    role: role,
    studentNumber: p['student_number'] as String?,
  );
}
