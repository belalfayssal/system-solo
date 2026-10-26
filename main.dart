import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const bg = Color(0xFF040A18);
const blue = Color(0xFF3AA0FF);
const red = Color(0xFFFF4D5E);
const statNames = {
  'wisdom': 'الحكمة',
  'creativity': 'الإبداع',
  'language': 'اللغة',
  'discipline': 'الانضباط',
};
final notif = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  // غيّر المنطقة الزمنية هنا إذا انتقلت إلى بلد آخر
  tz.setLocalLocation(tz.getLocation('Africa/Algiers'));
  await notif.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  await notif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  runApp(const App());
}

Future<void> schedule(List<String> times) async {
  await notif.cancelAll();
  for (var i = 0; i < times.length; i++) {
    final p = times[i].split(':');
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    await notif.zonedSchedule(
      i,
      '[ تنبيه من النظام ]',
      'لديك مهام يومية لم تكتمل. افتح النظام الآن.',
      t,
      const NotificationDetails(
          android: AndroidNotificationDetails('quests', 'المهام اليومية',
              importance: Importance.high, priority: Priority.high)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'السيستم',
        theme: ThemeData.dark(useMaterial3: true)
            .copyWith(scaffoldBackgroundColor: bg),
        builder: (c, w) =>
            Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const Home(),
      );
}

class Panel extends StatelessWidget {
  final Widget child;
  final Color color;
  const Panel({super.key, required this.child, this.color = blue});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF071226),
          border: Border.all(color: color, width: 1.2),
          boxShadow: [BoxShadow(color: color.withOpacity(.35), blurRadius: 18)],
        ),
        child: child,
      );
}

Future sysDialog(BuildContext c, String t, String b, Color col) => showDialog(
      context: c,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Panel(
          color: col,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t,
                style: TextStyle(
                    color: col, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Text(b,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, height: 1.6)),
            const SizedBox(height: 10),
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text('تأكيد', style: TextStyle(color: col))),
          ]),
        ),
      ),
    );

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Map<String, dynamic> d = {};
  bool ready = false;
  late SharedPreferences sp;

  Map<String, dynamic> defaults() => {
        'name': 'بلال',
        'xp': 0,
        'level': 1,
        'streak': 0,
        'last': '',
        'streakDay': '',
        'times': ['10:00', '13:00', '16:00'],
        'stats': {'wisdom': 0, 'creativity': 0, 'language': 0, 'discipline': 0},
        'quests': [
          {'t': 'تحضير نقطتين للخطبة', 'stat': 'wisdom', 'done': false},
          {'t': 'مراجعة 10 كلمات تركية', 'stat': 'language', 'done': false},
          {'t': 'كتابة فكرة لفيديو', 'stat': 'creativity', 'done': false},
        ],
      };

  @override
  void initState() {
    super.initState();
    init();
  }

  int get lvl => d['level'] as int;
  int get xp => d['xp'] as int;
  int need() => 100 + (lvl - 1) * 50;
  String rank() {
    const r = ['E', 'D', 'C', 'B', 'A', 'S'];
    final i = lvl < 5 ? 0 : lvl < 10 ? 1 : lvl < 15 ? 2 : lvl < 20 ? 3 : lvl < 30 ? 4 : 5;
    return r[i];
  }

  Future<void> init() async {
    sp = await SharedPreferences.getInstance();
    final raw = sp.getString('d');
    d = raw == null ? defaults() : jsonDecode(raw) as Map<String, dynamic>;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    String? msg;
    if (d['last'] != today) {
      if (d['last'] != '') {
        final undone =
            (d['quests'] as List).where((q) => q['done'] != true).length;
        if (undone > 0) {
          final loss = undone * 30;
          final left = xp - loss;
          d['xp'] = left < 0 ? 0 : left;
          d['streak'] = 0;
          msg = 'لم تكتمل $undone من مهام الأمس.\nالعقوبة: -$loss نقطة خبرة.';
        }
      }
      for (final q in d['quests']) {
        q['done'] = false;
      }
      d['last'] = today;
    }
    setState(() => ready = true);
    save();
    schedule(List<String>.from(d['times']));
    if (msg != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => sysDialog(context, '[ فشلت المهمة ]', msg!, red));
    }
  }

  void save() => sp.setString('d', jsonEncode(d));

  void complete(Map q) {
    if (q['done'] == true) return;
    q['done'] = true;
    final s = d['stats'] as Map;
    s[q['stat']] = (s[q['stat']] as int) + 1;
    d['xp'] = xp + 20;
    var up = false;
    while (xp >= need()) {
      d['xp'] = xp - need();
      d['level'] = lvl + 1;
      up = true;
    }
    final all = (d['quests'] as List).every((x) => x['done'] == true);
    String? extra;
    if (all && d['streakDay'] != d['last']) {
      d['streakDay'] = d['last'];
      d['streak'] = (d['streak'] as int) + 1;
      extra = 'اكتملت جميع المهام اليومية.\nالسلسلة: ${d['streak']} يوم';
    }
    setState(() {});
    save();
    if (up) {
      sysDialog(context, '[ ارتفع مستواك ]',
          'المستوى الآن $lvl\nالرتبة: ${rank()}', blue);
    } else if (extra != null) {
      sysDialog(context, '[ اكتملت المهمة ]', extra, blue);
    }
  }

  Future<void> addQuest() async {
    final ctrl = TextEditingController();
    var stat = 'wisdom';
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Dialog(
          backgroundColor: Colors.transparent,
          child: Panel(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('[ مهمة جديدة ]',
                  style: TextStyle(
                      color: blue, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(hintText: 'اسم المهمة')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: statNames.entries
                    .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: stat == e.key,
                          onSelected: (_) => set(() => stat = e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  if (ctrl.text.trim().isNotEmpty) {
                    setState(() => (d['quests'] as List).add(
                        {'t': ctrl.text.trim(), 'stat': stat, 'done': false}));
                    save();
                  }
                  Navigator.pop(c);
                },
                child: const Text('إضافة', style: TextStyle(color: blue)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> editName() async {
    final ctrl = TextEditingController(text: d['name']);
    await showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        child: Panel(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctrl),
            TextButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  setState(() => d['name'] = ctrl.text.trim());
                  save();
                }
                Navigator.pop(c);
              },
              child: const Text('حفظ', style: TextStyle(color: blue)),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> reminders() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          final times = List<String>.from(d['times']);
          return Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              const Text('[ أوقات التنبيه ]',
                  style: TextStyle(
                      color: blue, fontSize: 20, fontWeight: FontWeight.bold)),
              for (final t in times)
                ListTile(
                  title: Text(t),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: red),
                    onPressed: () {
                      times.remove(t);
                      d['times'] = times;
                      save();
                      schedule(times);
                      set(() {});
                    },
                  ),
                ),
              TextButton(
                onPressed: () async {
                  final p = await showTimePicker(
                      context: c, initialTime: TimeOfDay.now());
                  if (p == null) return;
                  final s =
                      '${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')}';
                  if (!times.contains(s)) times.add(s);
                  times.sort();
                  d['times'] = times;
                  save();
                  schedule(times);
                  set(() {});
                },
                child: const Text('إضافة وقت', style: TextStyle(color: blue)),
              ),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Scaffold();
    final quests = d['quests'] as List;
    final stats = d['stats'] as Map;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
          backgroundColor: blue, onPressed: addQuest, child: const Icon(Icons.add)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            const Expanded(
                child: Text('[ نافذة اللاعب ]',
                    style: TextStyle(
                        color: blue, fontSize: 22, fontWeight: FontWeight.bold))),
            IconButton(
                onPressed: reminders,
                icon: const Icon(Icons.notifications_active, color: blue)),
          ]),
          const SizedBox(height: 8),
          Panel(
            child: Row(children: [
              Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(border: Border.all(color: blue, width: 2)),
                child: Text(rank(),
                    style: const TextStyle(
                        color: blue, fontSize: 38, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                          onTap: editName,
                          child: Text(d['name'],
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold))),
                      Text('المستوى $lvl   |   السلسلة ${d['streak']} يوم'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                          value: xp / need(),
                          color: blue,
                          backgroundColor: const Color(0xFF12284A)),
                      const SizedBox(height: 4),
                      Text('$xp / ${need()} خبرة',
                          style: const TextStyle(fontSize: 12)),
                    ]),
              ),
            ]),
          ),
          Panel(
            child: Column(children: [
              for (final e in statNames.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(e.value)),
                    Text('${stats[e.key]}',
                        style: const TextStyle(
                            color: blue, fontWeight: FontWeight.bold)),
                  ]),
                ),
            ]),
          ),
          const Text('[ المهام اليومية ]',
              style: TextStyle(
                  color: blue, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (quests.isEmpty)
            const Text('لا توجد مهام. اضغط + لإضافة أول مهمة.'),
          for (final q in quests)
            InkWell(
              onTap: () => complete(q),
              child: Panel(
                color: q['done'] == true ? const Color(0xFF2A4C7A) : blue,
                child: Row(children: [
                  Icon(
                      q['done'] == true
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(q['t'],
                        style: TextStyle(
                            fontSize: 16,
                            decoration: q['done'] == true
                                ? TextDecoration.lineThrough
                                : null)),
                  ),
                  Text(statNames[q['stat']] ?? '',
                      style: const TextStyle(fontSize: 12, color: blue)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () {
                      setState(() => quests.remove(q));
                      save();
                    },
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 70),
        ]),
      ),
    );
  }
}
