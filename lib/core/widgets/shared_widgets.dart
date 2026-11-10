part of '../../main.dart';

// ───────────────────────── عناصر واجهة مشتركة ─────────────────────────

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: navy, fontSize: 14)));
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const SectionHeading({super.key, required this.title, this.subtitle = ''});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: navy)),
        if (subtitle.isNotEmpty) ...[const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF7B8798)))],
      ]);
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const StatCard({super.key, required this.icon, required this.title, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 20)),
            Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: navy)),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A8D))),
          ]),
        ),
      );
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const ActionTile({super.key, required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: paleBlue, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: blue, size: 23)),
              const SizedBox(height: 9),
              Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.35, fontWeight: FontWeight.w700, color: navy)),
            ]),
          ),
        ),
      );
}

class NoticeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final VoidCallback? onLongPress;
  const NoticeTile({super.key, required this.icon, required this.title, required this.body, required this.time, this.onLongPress});
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: paleBlue, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: blue)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
                  const SizedBox(height: 5),
                  Text(body, style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF6B7A8D))),
                  const SizedBox(height: 7),
                  Text(time, style: const TextStyle(fontSize: 10, color: blue, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  const FeatureRow({super.key, required this.icon, required this.title, required this.subtitle, this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: paleBlue, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: blue)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: navy, fontSize: 13)),
          subtitle: subtitle.isEmpty ? null : Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle, style: const TextStyle(fontSize: 11, height: 1.5, color: muted))),
          trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_left_rounded, color: Color(0xFF94A3B8))),
        ),
      );
}

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, {super.key, this.color = blue});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class EmptyBox extends StatelessWidget {
  final String text;
  const EmptyBox(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(children: [
          const Icon(Icons.inbox_outlined, size: 44, color: Color(0xFFB6C2D1)),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: muted, height: 1.6)),
        ]),
      );
}

class PageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? fab;
  final List<Widget>? actions;
  const PageScaffold({super.key, required this.title, required this.body, this.fab, this.actions});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title), actions: actions), body: body, floatingActionButton: fab);
}

Widget refreshList(Future<void> Function() reload, List<Widget> children) => RefreshIndicator(
      onRefresh: reload,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 90), physics: const AlwaysScrollableScrollPhysics(), children: children),
    );

class FutureBody<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  const FutureBody({super.key, required this.load, required this.builder});
  @override
  State<FutureBody<T>> createState() => _FutureBodyState<T>();
}

class _FutureBodyState<T> extends State<FutureBody<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Future<void> _reload() async {
    final f = widget.load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 44, color: Color(0xFFB6C2D1)),
                  const SizedBox(height: 10),
                  Text('تعذر تحميل البيانات\n${errText(snap.error!)}', textAlign: TextAlign.center, style: const TextStyle(color: muted, height: 1.6)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
                ]),
              ),
            );
          }
          return widget.builder(context, snap.data as T, _reload);
        },
      );
}
