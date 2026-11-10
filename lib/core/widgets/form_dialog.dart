part of '../../main.dart';

// ───────────────────────── نموذج إدخال عام ─────────────────────────

enum FK { text, multiline, number, date, dropdown, password }

class FormSpec {
  final String key;
  final String label;
  final FK kind;
  final bool required;
  final Map<String, String>? options;
  final String? initial;
  const FormSpec(this.key, this.label, {this.kind = FK.text, this.required = true, this.options, this.initial});
}

Future<Map<String, String>?> formDialog(BuildContext context, String title, List<FormSpec> specs, {String okLabel = 'حفظ', String? intro}) {
  return showDialog<Map<String, String>>(context: context, builder: (_) => _FormDialog(title: title, specs: specs, okLabel: okLabel, intro: intro));
}

String? nz(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

class _FormDialog extends StatefulWidget {
  final String title;
  final List<FormSpec> specs;
  final String okLabel;
  final String? intro;
  const _FormDialog({required this.title, required this.specs, required this.okLabel, this.intro});
  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  final _c = <String, TextEditingController>{};
  final _sel = <String, String>{};
  String? _err;

  @override
  void initState() {
    super.initState();
    for (final s in widget.specs) {
      _c[s.key] = TextEditingController(text: s.initial ?? '');
      if (s.kind == FK.dropdown) {
        final opts = s.options ?? const <String, String>{};
        _sel[s.key] = (s.initial != null && opts.containsKey(s.initial)) ? s.initial! : (opts.isNotEmpty ? opts.keys.first : '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final out = <String, String>{};
    for (final s in widget.specs) {
      final v = s.kind == FK.dropdown ? (_sel[s.key] ?? '') : _c[s.key]!.text.trim();
      if (s.required && v.isEmpty) {
        setState(() => _err = 'الحقل مطلوب: ${s.label}');
        return;
      }
      if (s.kind == FK.number && v.isNotEmpty && num.tryParse(v) == null) {
        setState(() => _err = 'أدخل رقماً صحيحاً في: ${s.label}');
        return;
      }
      out[s.key] = v;
    }
    Navigator.pop(context, out);
  }

  Widget _field(FormSpec s) {
    switch (s.kind) {
      case FK.dropdown:
        final opts = s.options ?? const <String, String>{};
        if (opts.isEmpty) return const Text('لا توجد خيارات متاحة بعد', style: TextStyle(color: muted));
        return DropdownButtonFormField<String>(
          value: _sel[s.key],
          isExpanded: true,
          items: opts.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _sel[s.key] = v ?? ''),
        );
      case FK.date:
        return TextField(
          controller: _c[s.key],
          readOnly: true,
          decoration: const InputDecoration(hintText: 'اضغط لاختيار التاريخ', suffixIcon: Icon(Icons.calendar_month_outlined)),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => _c[s.key]!.text = dayKey(d));
          },
        );
      case FK.multiline:
        return TextField(controller: _c[s.key], maxLines: 4, minLines: 3);
      case FK.number:
        return TextField(controller: _c[s.key], keyboardType: const TextInputType.numberWithOptions(decimal: true));
      case FK.password:
        return TextField(controller: _c[s.key], obscureText: true);
      case FK.text:
        return TextField(controller: _c[s.key]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.intro != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(widget.intro!, style: const TextStyle(height: 1.6, color: muted, fontSize: 13))),
            for (final s in widget.specs) ...[
              Padding(padding: const EdgeInsets.only(bottom: 6, top: 6), child: Text(s.required ? s.label : '${s.label} (اختياري)', style: const TextStyle(fontWeight: FontWeight.w700, color: navy, fontSize: 13))),
              _field(s),
            ],
            if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err!, style: const TextStyle(color: Color(0xFFB42318), fontSize: 12))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _submit, child: Text(widget.okLabel)),
      ],
    );
  }
}
