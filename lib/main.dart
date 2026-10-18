
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShadowDisciplineApp());
}

class ShadowDisciplineApp extends StatelessWidget {
  const ShadowDisciplineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SHADOW DISCIPLINE',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080912),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF905CFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const ShadowHome(),
    );
  }
}

class ShadowHome extends StatefulWidget {
  const ShadowHome({super.key});

  @override
  State<ShadowHome> createState() => _ShadowHomeState();
}

class _ShadowHomeState extends State<ShadowHome> {
  bool arabic = true;
  bool loading = true;
  String username = 'SHADOW';
  String path = 'discipline';

  int xp = 0;
  int totalCompleted = 0;
  int selectedTab = 0;

  int focusMinutes = 25;
  int secondsLeft = 25 * 60;
  bool timerRunning = false;

  Timer? timer;
  final TextEditingController nameController =
      TextEditingController();

  final Set<int> completedTasks = {};

  final List<Map<String, dynamic>> tasks = [
    {'ar': 'استيقظ مبكراً', 'en': 'Wake up early', 'xp': 20},
    {'ar': 'اقرأ وتعلم شيئاً جديداً', 'en': 'Read and learn', 'xp': 25},
    {'ar': 'تمرّن وحرّك جسمك', 'en': 'Exercise your body', 'xp': 30},
    {'ar': 'ابتعد عن المشتتات', 'en': 'Avoid distractions', 'xp': 25},
    {'ar': 'خطط لأهداف الغد', 'en': 'Plan tomorrow', 'xp': 20},
  ];

  String get todayKey {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  String tr(String ar, String en) => arabic ? ar : en;

  int get level => xp ~/ 100 + 1;
  int get levelProgress => xp % 100;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDate = prefs.getString('taskDate') ?? '';
    if (savedDate != todayKey) {
      await prefs.setString('taskDate', todayKey);
      await prefs.setStringList('completedTasks', []);
    }

    if (!mounted) return;

    setState(() {
      arabic = prefs.getBool('arabic') ?? true;
      username = prefs.getString('username') ?? 'SHADOW';
      path = prefs.getString('path') ?? 'discipline';
      xp = prefs.getInt('xp') ?? 0;
      totalCompleted = prefs.getInt('totalCompleted') ?? 0;

      completedTasks.addAll(
        (prefs.getStringList('completedTasks') ?? [])
            .map((value) => int.tryParse(value))
            .whereType<int>(),
      );

      nameController.text = username;
      loading = false;
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('arabic', arabic);
    await prefs.setString('username', username);
    await prefs.setString('path', path);
    await prefs.setInt('xp', xp);
    await prefs.setInt('totalCompleted', totalCompleted);
    await prefs.setString('taskDate', todayKey);

    await prefs.setStringList(
      'completedTasks',
      completedTasks.map((value) => value.toString()).toList(),
    );
  }

  Future<void> changeLanguage(bool value) async {
    setState(() => arabic = value);
    await saveData();
  }

  Future<void> completeTask(int index) async {
    if (completedTasks.contains(index)) return;

    setState(() {
      completedTasks.add(index);
      xp += tasks[index]['xp'] as int;
      totalCompleted++;
    });

    await saveData();
  }

  void startTimer() {
    if (timerRunning) return;

    if (secondsLeft <= 0) {
      setState(() => secondsLeft = focusMinutes * 60);
    }

    setState(() => timerRunning = true);

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (secondsLeft <= 1) {
        t.cancel();

        setState(() {
          secondsLeft = 0;
          timerRunning = false;
          xp += 15;
        });

        saveData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'أحسنت! انتهت الجلسة. حصلت على 15 XP',
                'Session complete! You earned 15 XP.',
              ),
            ),
          ),
        );
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  void pauseTimer() {
    timer?.cancel();
    setState(() => timerRunning = false);
  }

  void resetTimer() {
    timer?.cancel();

    setState(() {
      timerRunning = false;
      secondsLeft = focusMinutes * 60;
    });
  }

  Future<void> resetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('إعادة ضبط التقدم؟', 'Reset progress?')),
        content: Text(
          tr(
            'سيتم حذف نقاطك والمهام المنجزة.',
            'Your XP and completed missions will be erased.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('تأكيد', 'Confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      xp = 0;
      totalCompleted = 0;
      completedTasks.clear();
    });

    await saveData();
  }

  @override
  void dispose() {
    timer?.cancel();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF10111D),
          title: const Text(
            'SHADOW DISCIPLINE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => changeLanguage(!arabic),
              icon: const Icon(Icons.language),
              tooltip: tr('تغيير اللغة', 'Change language'),
            ),
          ],
        ),
        body: IndexedStack(
          index: selectedTab,
          children: [
            homePage(),
            tasksPage(),
            focusPage(),
            profilePage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedTab,
          onDestinationSelected: (value) {
            setState(() => selectedTab = value);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: tr('الرئيسية', 'Home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.task_alt),
              label: tr('المهام', 'Tasks'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.timer_outlined),
              label: tr('التركيز', 'Focus'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              label: tr('حسابي', 'Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget homePage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF30205C),
                Color(0xFF11121F),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF7750C8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.bolt,
                size: 40,
                color: Color(0xFFC4A5FF),
              ),
              const SizedBox(height: 12),
              Text(
                tr('أهلاً بك، $username', 'Welcome, $username'),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'ابنِ انضباطك. قوِّ عقلك. اصنع مستقبلك.',
                  'Build discipline. Strengthen your mind. Shape your future.',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${tr('المستوى', 'LEVEL')} $level'),
                  Text('$levelProgress / 100 XP'),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: levelProgress / 100,
                  minHeight: 9,
                  backgroundColor: Colors.white12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: statCard(
                tr('نقاط الخبرة', 'EXPERIENCE'),
                '$xp',
                Icons.bolt,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: statCard(
                tr('المهام المنجزة', 'TASKS DONE'),
                '$totalCompleted',
                Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        sectionTitle(tr('مهمات اليوم', 'TODAY MISSIONS')),
        const SizedBox(height: 12),
        ...List.generate(
          tasks.length,
          (index) => taskTile(index),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => setState(() => selectedTab = 2),
          icon: const Icon(Icons.timer),
          label: Text(tr('ابدأ التركيز', 'Start focusing')),
        ),
      ],
    );
  }

  Widget tasksPage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        sectionTitle(tr('مهماتك اليومية', 'DAILY MISSIONS')),
        const SizedBox(height: 8),
        Text(
          tr(
            'أكمل المهام واجمع نقاط الخبرة لرفع مستواك.',
            'Complete missions and earn XP to level up.',
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          tasks.length,
          (index) => taskTile(index),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_month),
            title: Text(tr('مهام يومية', 'Daily missions')),
            subtitle: Text(
              tr(
                'تتجدد المهام يومياً وتبقى نقاط الخبرة محفوظة.',
                'Missions reset daily while your XP stays saved.',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget focusPage() {
    final minutesText =
        (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final secondsText =
        (secondsLeft % 60).toString().padLeft(2, '0');

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 10),
        sectionTitle(tr('وضع التركيز', 'FOCUS MODE')),
        const SizedBox(height: 8),
        Text(
          tr(
            'اختر مدة الجلسة وركّز على هدف واحد.',
            'Choose a session length and focus on one goal.',
          ),
        ),
        const SizedBox(height: 30),
        Center(
          child: Container(
            width: 235,
            height: 235,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF905CFF),
                width: 5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x448B5CF6),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.hourglass_bottom,
                    size: 32,
                    color: Color(0xFFC4A5FF),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$minutesText:$secondsText',
                    style: const TextStyle(
                      fontSize: 43,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(tr('دقيقة : ثانية', 'MIN : SEC')),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(child: Text(tr('مدة الجلسة', 'SESSION LENGTH'))),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [15, 25, 30, 45, 60].map((value) {
            return ChoiceChip(
              label: Text('$value ${tr('د', 'min')}'),
              selected: focusMinutes == value,
              onSelected: timerRunning
                  ? null
                  : (_) {
                      setState(() {
                        focusMinutes = value;
                        secondsLeft = value * 60;
                      });
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: timerRunning ? pauseTimer : startTimer,
                icon: Icon(
                  timerRunning ? Icons.pause : Icons.play_arrow,
                ),
                label: Text(
                  timerRunning
                      ? tr('إيقاف مؤقت', 'Pause')
                      : tr('ابدأ', 'Start'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: resetTimer,
              icon: const Icon(Icons.refresh),
              tooltip: tr('إعادة', 'Reset'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            tr(
              'إكمال الجلسة يمنحك 15 نقطة XP.',
              'Completing a session earns 15 XP.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget profilePage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SizedBox(height: 10),
        const Center(
          child: CircleAvatar(
            radius: 43,
            backgroundColor: Color(0xFF30205C),
            child: Icon(
              Icons.person,
              size: 46,
              color: Color(0xFFC4A5FF),
            ),
          ),
        ),
        const SizedBox(height: 20),
        sectionTitle(tr('ملفك الشخصي', 'YOUR PROFILE')),
        const SizedBox(height: 14),
        TextField(
          controller: nameController,
          maxLength: 24,
          decoration: InputDecoration(
            labelText: tr('اسم المستخدم', 'Username'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        FilledButton(
          onPressed: () async {
            final value = nameController.text.trim();

            setState(() {
              username = value.isEmpty ? 'SHADOW' : value;
            });

            await saveData();

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr('تم حفظ الاسم', 'Username saved')),
              ),
            );
          },
          child: Text(tr('حفظ الاسم', 'Save username')),
        ),
        const SizedBox(height: 24),
        sectionTitle(tr('لغة التطبيق', 'APP LANGUAGE')),
        RadioListTile<bool>(
          value: true,
          groupValue: arabic,
          title: const Text('العربية'),
          onChanged: (value) {
            if (value != null) changeLanguage(value);
          },
        ),
        RadioListTile<bool>(
          value: false,
          groupValue: arabic,
          title: const Text('English'),
          onChanged: (value) {
            if (value != null) changeLanguage(value);
          },
        ),
        const SizedBox(height: 20),
        sectionTitle(tr('مسار التطور', 'GROWTH PATH')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: path,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'discipline',
              child: Text(tr('الانضباط الشخصي', 'Personal discipline')),
            ),
            DropdownMenuItem(
              value: 'student',
              child: Text(tr('الطالب', 'Student')),
            ),
            DropdownMenuItem(
              value: 'athlete',
              child: Text(tr('الرياضي', 'Athlete')),
            ),
            DropdownMenuItem(
              value: 'creator',
              child: Text(tr('صانع المحتوى', 'Content creator')),
            ),
          ],
          onChanged: (value) async {
            if (value == null) return;
            setState(() => path = value);
            await saveData();
          },
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const Icon(Icons.save_outlined),
            title: Text(tr('حفظ التقدم', 'Progress saving')),
            subtitle: Text(
              tr(
                'يُحفظ التقدم على هذا الجهاز.',
                'Progress is saved on this device.',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: resetProgress,
          icon: const Icon(Icons.restart_alt),
          label: Text(tr('إعادة ضبط التقدم', 'Reset progress')),
        ),
      ],
    );
  }

  Widget taskTile(int index) {
    final task = tasks[index];
    final done = completedTasks.contains(index);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF131420),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              done ? const Color(0xFF164E3B) : const Color(0xFF30205C),
          child: Icon(
            done ? Icons.check : Icons.bolt,
            color: done ? Colors.greenAccent : const Color(0xFFC4A5FF),
          ),
        ),
        title: Text(
          arabic ? task['ar'] as String : task['en'] as String,
          style: TextStyle(
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? Colors.white54 : Colors.white,
          ),
        ),
        subtitle: Text('+${task['xp']} XP'),
        trailing: done
            ? const Ic