part of '../../main.dart';

// ───────────────────────── إدارة المستخدمين ─────────────────────────

class UsersPage extends StatefulWidget {
  final AppUser user;
  final String title;
  final bool canEdit;
  final String? onlyRole;
  const UsersPage({super.key, required this.user, required this.title, required this.canEdit, this.onlyRole});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  int _v = 0;
  String _filter = '';
  String _search = '';

  Future<List<Rec>> _load() async {
    final rows = (await profileMap()).values.toList();
    rows.sort((a, b) => '${a['role']}${a['full_name']}'.compareTo('${b['role']}${b['full_name']}'));
    return rows;
  }

  Future<void> _create() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateUserPage()));
    if (mounted) setState(() => _v++);
  }

  Future<void> _changeRole(Rec p) async {
    final r = await formDialog(context, 'تغيير صلاحية ${p['full_name']}', [FormSpec('role', 'الصلاحية', kind: FK.dropdown, options: {for (final x in UserRole.values) x.key: x.label}, initial: p['role'] as String?)]);
    if (r == null || !mounted) return;
    final ok = await guarded(context, () async {
      await db.from('profiles').update({'role': r['role']!}).eq('id', p['id']);
    }, ok: 'تم تغيير الصلاحية');
    if (ok && mounted) setState(() => _v++);
  }

  Future<void> _toggle(Rec p) async {
    final active = p['is_active'] == true;
    if (!await confirmDialog(context, active ? 'إيقاف حساب ${p['full_name']}؟ لن يتمكن من الدخول.' : 'إعادة تفعيل حساب ${p['full_name']}؟')) return;
    if (!mounted) return;
    final ok = await guarded(context, () async {
      // الإيقاف يمر عبر دالة الإدارة كي يُحظر الحساب في Supabase Auth أيضًا.
      final response = await db.functions.invoke('set-user-status', body: {'user_id': p['id'], 'is_active': !active});
      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        throw Exception(data is Map ? (data['error'] ?? 'تعذر تحديث الحساب') : 'تعذر تحديث الحساب');
      }
    }, ok: active ? 'تم إيقاف الحساب' : 'تم تفعيل الحساب');
    if (ok && mounted) setState(() => _v++);
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: widget.title,
        fab: widget.canEdit ? FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.person_add_alt_1), label: const Text('حساب جديد')) : null,
        body: FutureBody<List<Rec>>(
          key: ValueKey(_v),
          load: _load,
          builder: (context, all, reload) {
            final list = all.where((p) {
              if (widget.onlyRole != null && p['role'] != widget.onlyRole) return false;
              if (_filter.isNotEmpty && p['role'] != _filter) return false;
              if (_search.isNotEmpty) {
                final hay = '${p['full_name']} ${p['email']} ${p['student_number'] ?? ''}'.toLowerCase();
                if (!hay.contains(_search.toLowerCase())) return false;
              }
              return true;
            }).toList();
            return refreshList(reload, [
              TextField(onChanged: (v) => setState(() => _search = v.trim()), decoration: const InputDecoration(hintText: 'بحث بالاسم أو البريد أو الرقم الجامعي', prefixIcon: Icon(Icons.search_rounded))),
              if (widget.onlyRole == null) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text('الكل (${all.length})'), selected: _filter.isEmpty, onSelected: (_) => setState(() => _filter = ''))),
                    for (final r in UserRole.values) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text('${r.label} (${all.where((p) => p['role'] == r.key).length})'), selected: _filter == r.key, onSelected: (_) => setState(() => _filter = r.key))),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              if (list.isEmpty) const Card(child: EmptyBox('لا يوجد مستخدمون مطابقون')),
              for (final p in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FeatureRow(
                    icon: parseRole(p['role'] as String?)?.icon ?? Icons.person_outline_rounded,
                    title: '${p['full_name']}${p['is_active'] == true ? '' : '  (موقوف)'}',
                    subtitle: '${p['email']}${(p['student_number'] ?? '').toString().isEmpty ? '' : ' · ${p['student_number']}'}\n${roleLabel(p['role'] as String?)}',
                    trailing: widget.canEdit && p['id'] != widget.user.id
                        ? PopupMenuButton<String>(
                            onSelected: (v) => v == 'role' ? _changeRole(p) : _toggle(p),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'role', child: Text('تغيير الصلاحية')),
                              PopupMenuItem(value: 'toggle', child: Text(p['is_active'] == true ? 'إيقاف الحساب' : 'تفعيل الحساب')),
                            ],
                          )
                        : (p['id'] == widget.user.id ? const Tag('أنت') : null),
                  ),
                ),
            ]);
          },
        ),
      );
}

class CreateUserPage extends StatefulWidget {
  const CreateUserPage({super.key});
  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends State<CreateUserPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _studentNumber = TextEditingController();
  UserRole _role = UserRole.student;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _studentNumber.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.length < 8) {
      snack(context, 'أدخل الاسم والبريد وكلمة مرور لا تقل عن 8 أحرف');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await db.functions.invoke('create-user', body: {
        'full_name': _name.text.trim(),
        'email': _email.text.trim().toLowerCase(),
        'password': _password.text,
        'role': _role.key,
        'student_number': _studentNumber.text.trim(),
        'department': 'قسم معلم حاسوب',
      });
      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        throw Exception(data is Map ? data['error'] ?? 'تعذر إنشاء الحساب' : 'تعذر إنشاء الحساب');
      }
      _name.clear();
      _email.clear();
      _password.clear();
      _studentNumber.clear();
      snack(context, 'تم إنشاء الحساب وإضافته إلى المنصة');
    } on FunctionException catch (e) {
      final d = e.details;
      snack(context, 'تعذر إنشاء الحساب: ${d is Map ? (d['error'] ?? d) : (d ?? e.reasonPhrase ?? 'خطأ بالخدمة')}');
    } catch (e) {
      snack(context, 'تعذر إنشاء الحساب: ${errText(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'إنشاء حساب جديد',
        body: ListView(padding: const EdgeInsets.all(18), children: [
          const Text('تنشئ الإدارة حسابات الطلاب والمدرسين ورئيس القسم. الصلاحية تُحفظ في قاعدة البيانات ولا يحددها المستخدم عند تسجيل الدخول.', style: TextStyle(height: 1.6, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          const FieldLabel('الاسم الكامل'),
          TextField(controller: _name, textInputAction: TextInputAction.next, decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline), hintText: 'الاسم كما سيظهر في المنصة')),
          const SizedBox(height: 14),
          const FieldLabel('البريد الإلكتروني'),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(prefixIcon: Icon(Icons.email_outlined), hintText: 'name@example.com')),
          const SizedBox(height: 14),
          const FieldLabel('كلمة المرور الأولية'),
          TextField(controller: _password, obscureText: true, textInputAction: TextInputAction.next, decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline), hintText: '8 أحرف على الأقل')),
          const SizedBox(height: 14),
          const FieldLabel('نوع الحساب'),
          DropdownButtonFormField<UserRole>(value: _role, items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(), onChanged: _busy ? null : (v) => setState(() => _role = v ?? UserRole.student), decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined))),
          if (_role == UserRole.student) ...[
            const SizedBox(height: 14),
            const FieldLabel('الرقم الجامعي (اختياري)'),
            TextField(controller: _studentNumber, decoration: const InputDecoration(prefixIcon: Icon(Icons.numbers), hintText: 'الرقم الجامعي')),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_add_alt_1),
            label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_busy ? 'جارٍ إنشاء الحساب...' : 'إنشاء الحساب')),
          ),
        ]),
      );
}
