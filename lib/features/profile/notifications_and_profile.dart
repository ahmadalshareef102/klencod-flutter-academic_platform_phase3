part of '../../main.dart';

// ───────────────────────── الإشعارات والحساب ─────────────────────────

class NotificationsPage extends StatelessWidget {
  final AppUser user;
  const NotificationsPage({super.key, required this.user});
  @override
  Widget build(BuildContext context) => FutureBody<List<Rec>>(
        load: () => loadAnnouncements(user),
        builder: (context, list, reload) => refreshList(reload, [
          const SizedBox(height: 10),
          const Text('الإشعارات', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 7),
          const Text('آخر الإعلانات الأكاديمية', style: TextStyle(color: muted)),
          const SizedBox(height: 20),
          if (list.isEmpty) const Card(child: EmptyBox('لا توجد إشعارات حتى الآن')),
          for (final a in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: NoticeTile(icon: Icons.campaign_rounded, title: '${a['title']}', body: '${a['body']}', time: '${fmtDateTime(a['published_at'])} · ${audienceAr[a['audience']] ?? ''}')),
        ]),
      );
}

class ProfilePage extends StatelessWidget {
  final AppUser user;
  final VoidCallback onLogout;
  const ProfilePage({super.key, required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
        const Text('حسابي', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              CircleAvatar(radius: 38, backgroundColor: paleBlue, child: Icon(user.role.icon, color: blue, size: 38)),
              const SizedBox(height: 14),
              Text(user.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy)),
              const SizedBox(height: 5),
              Text(user.role.label, style: const TextStyle(color: muted)),
              const SizedBox(height: 18),
              const Divider(),
              ProfileInfoRow(label: 'البريد الإلكتروني', value: user.email),
              if ((user.studentNumber ?? '').isNotEmpty) ProfileInfoRow(label: 'الرقم الجامعي', value: user.studentNumber!),
              const ProfileInfoRow(label: 'الجهة التعليمية', value: 'كلية التربية – زبيد'),
              ProfileInfoRow(label: 'نوع الحساب', value: user.role.label),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        FeatureRow(icon: Icons.support_agent_rounded, title: 'المساعدة والدعم', subtitle: 'الشكاوى والمقترحات', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComplaintsPage(user: user)))),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const Padding(padding: EdgeInsets.all(13), child: Text('تسجيل الخروج')),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB42318), side: const BorderSide(color: Color(0xFFF0C7C4), width: 1.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      ]);
}

class ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const ProfileInfoRow({super.key, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, color: navy, fontSize: 13))),
        ]),
      );
}
