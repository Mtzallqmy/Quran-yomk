import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin_api.dart';
import '../services.dart';

class AdminEntryPage extends ConsumerWidget {
  const AdminEntryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(servicesProvider).adminSession;
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) =>
          session.signedIn ? const AdminCenterPage() : const AdminLoginPage(),
    );
  }
}

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final email = TextEditingController(text: 'mtzallqmy@gmail.com');
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(servicesProvider)
          .adminSession
          .login(email.text, password.text);
    } on AdminApiException catch (value) {
      if (mounted) setState(() => error = value.code);
    } finally {
      password.clear();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('دخول الإدارة')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Icon(Icons.admin_panel_settings_outlined, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'لوحة الإدارة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const <String>[AutofillHints.username],
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(labelText: 'البريد'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      autofillHints: const <String>[AutofillHints.password],
                      onSubmitted: (_) => login(),
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                      ),
                    ),
                    if (error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: busy ? null : login,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('تحقق ودخول'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'الصلاحية تُتحقق من خادم Supabase؛ لا تُحفظ كلمة المرور.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminCenterPage extends ConsumerStatefulWidget {
  const AdminCenterPage({super.key});

  @override
  ConsumerState<AdminCenterPage> createState() => _AdminCenterPageState();
}

class _AdminCenterPageState extends ConsumerState<AdminCenterPage> {
  late Future<List<dynamic>> notifications;
  late Future<List<dynamic>> devices;
  late Future<List<dynamic>> config;
  late Future<List<dynamic>> audit;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    final api = ref.read(servicesProvider).adminSession;
    notifications = api.notifications();
    devices = api.devices();
    config = api.runtimeConfig();
    audit = api.audit();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(servicesProvider).adminSession;
    final overview = api.overview ?? const <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الإدارة'),
        actions: <Widget>[
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => setState(refresh),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: api.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _Metric(
                label: 'كل الأجهزة',
                value: '${overview['devices_total'] ?? 0}',
              ),
              _Metric(
                label: 'الأجهزة النشطة',
                value: '${overview['devices_active'] ?? 0}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _NotificationComposer(api: api, onSaved: () => setState(refresh)),
          _AdminList(
            title: 'الإشعارات والمجدولة',
            future: notifications,
            label: (row) => '${row['title']} — ${row['status']}',
          ),
          _AdminList(
            title: 'الأجهزة',
            future: devices,
            label: (row) =>
                '${row['platform']} ${row['app_version']} — ${row['locale']}',
          ),
          _RuntimeConfig(api: api, future: config),
          _AdminList(
            title: 'آخر عمليات التدقيق',
            future: audit,
            label: (row) => '${row['action']} — ${row['created_at']}',
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.open_in_browser),
              title: Text('المحتوى والإذاعة'),
              subtitle: Text('تبقى العمليات المتقدمة في لوحة الويب الحالية'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class _NotificationComposer extends StatefulWidget {
  const _NotificationComposer({required this.api, required this.onSaved});
  final MobileAdminSession api;
  final VoidCallback onSaved;
  @override
  State<_NotificationComposer> createState() => _NotificationComposerState();
}

class _NotificationComposerState extends State<_NotificationComposer> {
  final title = TextEditingController();
  final body = TextEditingController();
  final targetValue = TextEditingController();
  String target = 'segment';
  DateTime? scheduledAt;
  bool busy = false;

  Future<void> send({bool test = false}) async {
    if (target == 'all' && !test) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إرسال إلى الجميع؟'),
          content: const Text('سيصل الإشعار إلى كل الأجهزة النشطة والموافقة.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => busy = true);
    try {
      final value = <String, dynamic>{
        'title': title.text,
        'body': body.text,
        'type': 'admin_announcements',
        'target_type': target,
        'target': target == 'all'
            ? null
            : target == 'segment'
            ? <String, dynamic>{'platform': 'android'}
            : targetValue.text,
        'payload': <String, dynamic>{'route': '/home'},
        'confirm_all': target == 'all',
        if (scheduledAt != null)
          'scheduled_at': scheduledAt!.toUtc().toIso8601String(),
      };
      if (test) {
        await widget.api.sendTest(value);
      } else {
        await widget.api.createNotification(value);
      }
      widget.onSaved();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر إرسال الإشعار')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          TextField(
            controller: title,
            maxLength: 120,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'العنوان'),
          ),
          TextField(
            controller: body,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'النص'),
          ),
          DropdownButtonFormField<String>(
            initialValue: target,
            decoration: const InputDecoration(labelText: 'الهدف'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(
                value: 'segment',
                child: Text('أجهزة Android النشطة'),
              ),
              DropdownMenuItem(value: 'user', child: Text('مستخدم محدد')),
              DropdownMenuItem(value: 'device', child: Text('جهاز محدد')),
              DropdownMenuItem(value: 'all', child: Text('كل الأجهزة')),
            ],
            onChanged: (value) => setState(() => target = value ?? 'segment'),
          ),
          if (target == 'user' || target == 'device')
            TextField(
              controller: targetValue,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'UUID'),
            ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(
              scheduledAt == null ? 'إرسال الآن' : 'مجدول: $scheduledAt',
            ),
            trailing: scheduledAt == null
                ? null
                : IconButton(
                    onPressed: () => setState(() => scheduledAt = null),
                    icon: const Icon(Icons.close),
                  ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDate: DateTime.now(),
              );
              if (date == null || !context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time != null)
                setState(
                  () => scheduledAt = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  ),
                );
            },
          ),
          Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: busy ? null : () => send(test: true),
                child: const Text('تجربة إلى جهازي'),
              ),
              FilledButton(
                onPressed: busy || title.text.isEmpty || body.text.isEmpty
                    ? null
                    : () => send(),
                child: Text(scheduledAt == null ? 'إرسال الآن' : 'جدولة'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _AdminList extends StatelessWidget {
  const _AdminList({
    required this.title,
    required this.future,
    required this.label,
  });
  final String title;
  final Future<List<dynamic>> future;
  final String Function(Map<String, dynamic>) label;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: Text(title),
      children: <Widget>[
        FutureBuilder<List<dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              );
            if (snapshot.hasError)
              return const ListTile(title: Text('تعذر التحميل'));
            final rows = snapshot.data ?? const <dynamic>[];
            if (rows.isEmpty)
              return const ListTile(title: Text('لا توجد بيانات'));
            return Column(
              children: rows
                  .take(30)
                  .map(
                    (value) => ListTile(
                      title: Text(
                        label(Map<String, dynamic>.from(value as Map)),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}

class _RuntimeConfig extends StatelessWidget {
  const _RuntimeConfig({required this.api, required this.future});
  final MobileAdminSession api;
  final Future<List<dynamic>> future;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: const Text('Runtime Config وFeature Flags'),
      children: <Widget>[
        FutureBuilder<List<dynamic>>(
          future: future,
          builder: (context, snapshot) => Column(
            children: (snapshot.data ?? const <dynamic>[]).map((value) {
              final row = Map<String, dynamic>.from(value as Map);
              final current = row['value'];
              if (current is! bool)
                return ListTile(
                  title: Text('${row['key']}'),
                  subtitle: Text('$current'),
                );
              return SwitchListTile(
                title: Text('${row['key']}'),
                value: current,
                onChanged: (enabled) async {
                  try {
                    await api.updateRuntime(<String, dynamic>{
                      '${row['key']}': enabled,
                    });
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تعذر حفظ الإعداد')),
                      );
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );
}
