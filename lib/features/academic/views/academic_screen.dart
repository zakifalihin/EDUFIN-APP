import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../controllers/academic_controller.dart';
import '../models/schedule_model.dart';
import '../../dashboard/controllers/task_controller.dart';
import '../../dashboard/models/task_model.dart';

class TimelineItem {
  final String time;
  final String sortTime;
  final String title;
  final String subtitle;
  final String type;
  final bool isCompleted;
  final dynamic original;

  TimelineItem({
    required this.time,
    required this.sortTime,
    required this.title,
    required this.subtitle,
    required this.type,
    this.isCompleted = false,
    this.original,
  });
}

class AcademicScreen extends StatefulWidget {
  const AcademicScreen({Key? key}) : super(key: key);

  @override
  State<AcademicScreen> createState() => _AcademicScreenState();
}

class _AcademicScreenState extends State<AcademicScreen> {
  final AcademicController _academicController = AcademicController();
  final TaskController _taskController = TaskController();
  
  int _selectedDayOfWeek = 1;
  late Future<List<ScheduleModel>> _schedulesFuture;
  late Future<List<TaskModel>> _tasksFuture;

  List<ScheduleModel>? _cachedSchedules;
  List<TaskModel>? _cachedTasks;

  @override
  void initState() {
    super.initState();
    _selectedDayOfWeek = DateTime.now().weekday;
    _fetchData();
  }

  void _fetchData() {
    _schedulesFuture = _academicController.getSchedulesByDay(_selectedDayOfWeek).then((data) {
      setState(() {
        _cachedSchedules = data;
      });
      return data;
    });
    _tasksFuture = _taskController.getAllTasks().then((data) {
      setState(() {
        _cachedTasks = data;
      });
      return data;
    });
  }

  void _changeDay(int dayIndex) {
    setState(() {
      _selectedDayOfWeek = dayIndex;
      _fetchData();
    });
  }

  void _refreshData() {
    setState(() => _fetchData());
  }

  void _parseAndInsertKrs(String rawText) async {
    final lines = rawText.split('\n');
    int addedCount = 0;
    
    final dayMap = {
      'senin': 1, 'mon': 1, 'monday': 1,
      'selasa': 2, 'tue': 2, 'tuesday': 2,
      'rabu': 3, 'wed': 3, 'wednesday': 3,
      'kamis': 4, 'thu': 4, 'thursday': 4,
      'jumat': 5, 'fri': 5, 'friday': 5,
      'sabtu': 6, 'sat': 6, 'saturday': 6,
      'minggu': 7, 'sun': 7, 'sunday': 7,
    };

    final timeRegex = RegExp(r'(\d{2}[:\.]\d{2})\s*[-–—]\s*(\d{2}[:\.]\d{2})');
    final roomRegex = RegExp(r'(?:R(?:uang)?\.?\s*(\w+\d*|Lab\s*\w*))', caseSensitive: false);

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      int day = 1;
      bool foundDay = false;
      for (var entry in dayMap.entries) {
        if (line.toLowerCase().contains(entry.key)) {
          day = entry.value;
          foundDay = true;
          break;
        }
      }
      if (!foundDay) continue;

      final timeMatch = timeRegex.firstMatch(line);
      if (timeMatch == null) continue;
      String startTime = timeMatch.group(1)!.replaceAll('.', ':');
      String endTime = timeMatch.group(2)!.replaceAll('.', ':');

      final roomMatch = roomRegex.firstMatch(line);
      String room = roomMatch != null ? roomMatch.group(0)! : 'Online / Aula';

      String subject = line
          .replaceAll(timeRegex, '')
          .replaceAll(roomRegex, '')
          .replaceAll(RegExp(r'(senin|selasa|rabu|kamis|jumat|sabtu|minggu|mon|tue|wed|thu|fri|sat|sun)', caseSensitive: false), '')
          .replaceAll(RegExp(r'[,|()\-\–\—]'), '')
          .trim();
      
      if (subject.isEmpty) subject = 'Mata Kuliah';

      await _academicController.insertSchedule(
        subject: subject,
        room: room,
        startTime: startTime + ':00',
        endTime: endTime + ':00',
        dayOfWeek: day,
        type: 'class',
      );
      addedCount++;
    }

    if (mounted) {
      if (addedCount > 0) {
        _refreshData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil mengimpor $addedCount jadwal dari teks!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengenali format jadwal. Pastikan baris teks memiliki Hari, Jam (08:00 - 10:00), dan nama matkul.'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    String rawName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email?.split('@').first ??
        'Mahasiswa';
    final String userName = rawName
        .split(' ')
        .map((str) => str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1)}' : '')
        .join(' ');

    final String? avatarUrl = user?.userMetadata?['avatar_url'] ??
        user?.userMetadata?['photo_url'];
    final String profilePhoto = avatarUrl ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}&background=0F172A&color=fff&size=150&bold=true';

    final now = DateTime.now();
    final int currentWeekday = now.weekday;
    final DateTime mondayOfThisWeek = now.subtract(Duration(days: currentWeekday - 1));
    final List<DateTime> weekDates = List.generate(7, (index) => mondayOfThisWeek.add(Duration(days: index)));
    final List<String> dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER (tanpa tombol Add manual)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(profilePhoto),
                        ),
                        const SizedBox(width: 12),
                        const Text('EDUFIN', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const Icon(Icons.notifications_outlined, size: 28, color: Color(0xFF0F172A)),
                  ],
                ),
              ),

              // 2. DATE SELECTOR
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: 7,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final dayDate = weekDates[index];
                    final dayIndex = index + 1;
                    final label = dayLabels[index];
                    final dateStr = dayDate.day.toString();
                    return _buildDateItem(label, dateStr, _selectedDayOfWeek == dayIndex, () => _changeDay(dayIndex));
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 3. STATS CARD (COMBINED & DINAMIS & CLICKABLE)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FutureBuilder<List<TaskModel>>(
                  future: _tasksFuture,
                  builder: (context, taskSnapshot) {
                    if (taskSnapshot.connectionState == ConnectionState.waiting && _cachedTasks == null) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Center(child: CircularProgressIndicator(color: Color(0xFFFFC107))),
                      );
                    }
                    final allTasks = _cachedTasks ?? taskSnapshot.data ?? [];
                    return _buildCombinedWeeklyCard(allTasks, weekDates);
                  },
                ),
              ),
              const SizedBox(height: 20),

              // 5. TIMELINE ACADEMIC SCHEDULE & TASKS
              FutureBuilder<List<dynamic>>(
                future: Future.wait([_schedulesFuture, _tasksFuture]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && (_cachedSchedules == null || _cachedTasks == null)) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      color: Colors.white,
                      child: const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
                    );
                  }

                  final results = snapshot.data ?? [[], []];
                  final daySchedules = _cachedSchedules ?? (snapshot.data != null ? snapshot.data![0] as List<ScheduleModel> : []);
                  final allTasks = _cachedTasks ?? (snapshot.data != null ? snapshot.data![1] as List<TaskModel> : []);

                  final activeDate = weekDates[_selectedDayOfWeek - 1];

                  // Filter tasks for this day
                  final dayTasks = allTasks.where((t) {
                    return t.deadline.year == activeDate.year &&
                           t.deadline.month == activeDate.month &&
                           t.deadline.day == activeDate.day;
                  }).toList();

                  // Map to unified TimelineItem
                  final List<TimelineItem> timelineItems = [];

                  for (var s in daySchedules) {
                    timelineItems.add(TimelineItem(
                      time: '${s.startTime} - ${s.endTime}',
                      sortTime: s.startTime,
                      title: s.subject,
                      subtitle: s.room,
                      type: s.type,
                      original: s,
                    ));
                  }

                  for (var t in dayTasks) {
                    final formattedTime = DateFormat('HH:mm').format(t.deadline);
                    timelineItems.add(TimelineItem(
                      time: formattedTime,
                      sortTime: formattedTime,
                      title: t.title,
                      subtitle: t.taskType.toUpperCase(),
                      type: 'task',
                      isCompleted: t.isCompleted,
                      original: t,
                    ));
                  }

                  // Sort chronologically
                  timelineItems.sort((a, b) => a.sortTime.compareTo(b.sortTime));

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header timeline dengan tombol + Add New
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Academic Schedule',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                                ),
                                builder: (ctx) => _AddScheduleBottomSheet(controller: _academicController, onSuccess: _refreshData),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFFFFC107)),
                              label: const Text('Add New', style: TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        if (timelineItems.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text(
                                  'Hari Ini Bebas Kuliah & Tugas! 🎉',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Waktunya istirahat atau nugas untuk besok.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: timelineItems.length,
                            itemBuilder: (context, idx) {
                              final item = timelineItems[idx];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Waktu Kegiatan
                                      SizedBox(
                                        width: 80,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              item.time.split(' - ').first,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            if (item.time.contains(' - '))
                                              Text(
                                                item.time.split(' - ').last,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Bullet indicator line
                                      Column(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: item.type == 'task' ? const Color(0xFFF97316) : const Color(0xFFFFC107),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Expanded(
                                            child: Container(
                                              width: 2,
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      // Event or Task Card
                                      Expanded(
                                        child: item.type == 'task'
                                            ? _buildTimelineTaskCard(item.original as TaskModel)
                                            : _buildDynamicEventCard(item.original as ScheduleModel, isClash: false),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 32),

                        // BANNER KRS GENERATOR
                        GestureDetector(
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            builder: (ctx) => _KrsParserBottomSheet(onParse: _parseAndInsertKrs),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
                            child: const Row(
                              children: [
                                Icon(Icons.auto_awesome, color: Color(0xFFFFC107), size: 24),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Generate Jadwal Otomatis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      SizedBox(height: 4),
                                      Text('Foto KRS atau copy teks dari grup kelas.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCombinedWeeklyCard(List<TaskModel> allTasks, List<DateTime> weekDates) {
    final startOfWeek = DateTime(weekDates[0].year, weekDates[0].month, weekDates[0].day, 0, 0, 0);
    final endOfWeek = DateTime(weekDates[6].year, weekDates[6].month, weekDates[6].day, 23, 59, 59);

    final weeklyTasks = allTasks.where((t) {
      return t.deadline.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
             t.deadline.isBefore(endOfWeek.add(const Duration(seconds: 1)));
    }).toList();

    final totalTasks = weeklyTasks.length;
    final completedTasks = weeklyTasks.where((t) => t.isCompleted).length;
    final double progress = totalTasks > 0 ? (completedTasks / totalTasks) : 1.0;

    final pendingTasks = weeklyTasks.where((t) => !t.isCompleted).toList();
    pendingTasks.sort((a, b) => a.deadline.compareTo(b.deadline));

    String deadlineText = '';
    if (pendingTasks.isNotEmpty) {
      final nextTask = pendingTasks.first;
      final diffDays = nextTask.deadline.difference(DateTime.now()).inDays;
      final sisaStr = diffDays == 0 
          ? 'Hari ini' 
          : diffDays < 0 
              ? 'Terlambat ${diffDays.abs()} hari'
              : '$diffDays hari lagi';
      deadlineText = '${nextTask.title} ($sisaStr)';
    } else {
      deadlineText = totalTasks > 0 ? 'Semua tugas minggu ini selesai! 🚀' : 'Bebas tugas minggu ini! 🎉';
    }

    return GestureDetector(
      onTap: () => _showWeeklyTasksDetailSheet(context, weeklyTasks),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: CircularProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    color: const Color(0xFFFFC107),
                    strokeWidth: 6,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ringkasan Tugas Minggu Ini',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completedTasks dari $totalTasks Selesai',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.assignment_turned_in_rounded, size: 12, color: Color(0xFFFFC107)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          deadlineText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  void _showWeeklyTasksDetailSheet(BuildContext context, List<TaskModel> weeklyTasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daftar Tugas Minggu Ini',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (weeklyTasks.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Tidak ada tugas untuk minggu ini. 🚀',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: weeklyTasks.length,
                    itemBuilder: (context, idx) {
                      final t = weeklyTasks[idx];
                      final isOverdue = !t.isCompleted && t.deadline.isBefore(DateTime.now());
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: t.isCompleted ? const Color(0xFFF1F5F9) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isOverdue 
                                ? Colors.red.shade100 
                                : t.isCompleted 
                                    ? Colors.grey.shade200 
                                    : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: t.isCompleted,
                              activeColor: const Color(0xFF0F172A),
                              onChanged: (bool? val) async {
                                final bool targetValue = val ?? false;
                                
                                // 1. Optimistic Update di sheet local state
                                setSheetState(() {
                                  final itemIdx = weeklyTasks.indexWhere((element) => element.id == t.id);
                                  if (itemIdx != -1) {
                                    weeklyTasks[itemIdx] = TaskModel(
                                      id: t.id,
                                      scheduleId: t.scheduleId,
                                      title: t.title,
                                      taskType: t.taskType,
                                      deadline: t.deadline,
                                      isCompleted: targetValue,
                                      subjectName: t.subjectName,
                                    );
                                  }
                                });

                                // 2. Optimistic Update di parent cachedTasks state
                                setState(() {
                                  if (_cachedTasks != null) {
                                    final itemIdx = _cachedTasks!.indexWhere((element) => element.id == t.id);
                                    if (itemIdx != -1) {
                                      _cachedTasks![itemIdx] = TaskModel(
                                        id: t.id,
                                        scheduleId: t.scheduleId,
                                        title: t.title,
                                        taskType: t.taskType,
                                        deadline: t.deadline,
                                        isCompleted: targetValue,
                                        subjectName: t.subjectName,
                                      );
                                    }
                                  }
                                });

                                // 3. Panggil API di background
                                final err = await _taskController.toggleTaskCompletion(t.id, targetValue);
                                if (err != null) {
                                  // Revert jika gagal
                                  setSheetState(() {
                                    final itemIdx = weeklyTasks.indexWhere((element) => element.id == t.id);
                                    if (itemIdx != -1) {
                                      weeklyTasks[itemIdx] = TaskModel(
                                        id: t.id,
                                        scheduleId: t.scheduleId,
                                        title: t.title,
                                        taskType: t.taskType,
                                        deadline: t.deadline,
                                        isCompleted: !targetValue,
                                        subjectName: t.subjectName,
                                      );
                                    }
                                  });

                                  setState(() {
                                    if (_cachedTasks != null) {
                                      final itemIdx = _cachedTasks!.indexWhere((element) => element.id == t.id);
                                      if (itemIdx != -1) {
                                        _cachedTasks![itemIdx] = TaskModel(
                                          id: t.id,
                                          scheduleId: t.scheduleId,
                                          title: t.title,
                                          taskType: t.taskType,
                                          deadline: t.deadline,
                                          isCompleted: !targetValue,
                                          subjectName: t.subjectName,
                                        );
                                      }
                                    }
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Gagal memperbarui tugas: $err'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: t.isCompleted ? Colors.grey : const Color(0xFF0F172A),
                                      decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${t.subjectName ?? 'Tugas Umum'} • ${DateFormat('EEEE, d MMMM - HH:mm', 'id_ID').format(t.deadline)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isOverdue ? Colors.red : Colors.grey.shade600,
                                      fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOverdue 
                                    ? Colors.red.shade50 
                                    : t.isCompleted 
                                        ? Colors.grey.shade200 
                                        : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                t.taskType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isOverdue 
                                      ? Colors.red 
                                      : t.isCompleted 
                                          ? Colors.grey 
                                          : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineTaskCard(TaskModel task) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: task.isCompleted ? const Color(0xFFF1F5F9) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: task.isCompleted ? Colors.grey : const Color(0xFFF97316),
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.isCompleted,
            activeColor: const Color(0xFF0F172A),
            onChanged: (bool? val) async {
              final bool targetValue = val ?? false;

              // 1. Optimistic Update
              setState(() {
                if (_cachedTasks != null) {
                  final idx = _cachedTasks!.indexWhere((element) => element.id == task.id);
                  if (idx != -1) {
                    _cachedTasks![idx] = TaskModel(
                      id: task.id,
                      scheduleId: task.scheduleId,
                      title: task.title,
                      taskType: task.taskType,
                      deadline: task.deadline,
                      isCompleted: targetValue,
                      subjectName: task.subjectName,
                    );
                  }
                }
              });

              // 2. API call in background
              final err = await _taskController.toggleTaskCompletion(task.id, targetValue);
              if (err != null) {
                // Revert
                setState(() {
                  if (_cachedTasks != null) {
                    final idx = _cachedTasks!.indexWhere((element) => element.id == task.id);
                    if (idx != -1) {
                      _cachedTasks![idx] = TaskModel(
                        id: task.id,
                        scheduleId: task.scheduleId,
                        title: task.title,
                        taskType: task.taskType,
                        deadline: task.deadline,
                        isCompleted: !targetValue,
                        subjectName: task.subjectName,
                      );
                    }
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal memperbarui status tugas: $err'), backgroundColor: Colors.red),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: task.isCompleted ? Colors.grey : const Color(0xFF0F172A),
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.subjectName ?? "Tugas Umum"} • Deadline ${DateFormat('HH:mm').format(task.deadline)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: task.isCompleted ? Colors.grey : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicEventCard(ScheduleModel schedule, {required bool isClash}) {
    Color bgColor = const Color(0xFFD9E4FF);
    Color borderCol = const Color(0xFF0F172A);
    Color textCol = const Color(0xFF0F172A);

    if (schedule.type == 'seminar') {
      bgColor = const Color(0xFFF3E8FF);
      borderCol = Colors.purple;
    } else if (schedule.type == 'lab') {
      bgColor = const Color(0xFFDCFCE7);
      borderCol = Colors.green.shade700;
    } else if (schedule.type == 'group') {
      bgColor = const Color(0xFFEEF2F6);
      borderCol = Colors.grey.shade500;
      textCol = Colors.grey.shade600;
    }

    if (isClash) {
      bgColor = const Color(0xFFFFE2E2);
      borderCol = Colors.red;
      textCol = Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: isClash ? Border.all(color: borderCol, width: 1.5) : Border(left: BorderSide(color: borderCol, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isClash ? '⚠ Bentrok!\n${schedule.subject}' : schedule.subject,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textCol),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${schedule.room} • ${schedule.startTime} - ${schedule.endTime}', 
            style: TextStyle(fontSize: 11, color: textCol.withValues(alpha: 0.7), height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (schedule.taskCount > 0 && !isClash)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red.shade700),
                  const SizedBox(width: 4),
                  Text('${schedule.taskCount} Tugas Urgent', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildDateItem(String day, String date, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 65,
        decoration: BoxDecoration(color: isActive ? const Color(0xFF0F172A) : const Color(0xFFEBEBEB), borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(day, style: TextStyle(color: isActive ? Colors.white70 : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(date, style: TextStyle(color: isActive ? Colors.white : const Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _AddScheduleBottomSheet extends StatefulWidget {
  final AcademicController controller;
  final VoidCallback onSuccess;
  const _AddScheduleBottomSheet({required this.controller, required this.onSuccess});

  @override
  State<_AddScheduleBottomSheet> createState() => _AddScheduleBottomSheetState();
}

class _AddScheduleBottomSheetState extends State<_AddScheduleBottomSheet> {
  final _subjectController = TextEditingController();
  final _roomController = TextEditingController();
  
  int _selectedDay = 1;
  String _selectedType = 'class';
  
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 30);
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  void _submit() async {
    final subject = _subjectController.text.trim();
    final room = _roomController.text.trim();
    
    if (subject.isEmpty || room.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mata kuliah dan ruangan tidak boleh kosong!'), backgroundColor: Colors.red),
      );
      return;
    }

    String formatTimeOfDay(TimeOfDay tod) {
      final hour = tod.hour.toString().padLeft(2, '0');
      final minute = tod.minute.toString().padLeft(2, '0');
      return "$hour:$minute:00";
    }

    setState(() => _isLoading = true);

    final err = await widget.controller.insertSchedule(
      subject: subject,
      room: room,
      startTime: formatTimeOfDay(_startTime),
      endTime: formatTimeOfDay(_endTime),
      dayOfWeek: _selectedDay,
      type: _selectedType,
    );

    setState(() => _isLoading = false);

    if (err == null) {
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan jadwal: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tambah Jadwal Manual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _subjectController,
            decoration: InputDecoration(
              labelText: 'Nama Mata Kuliah / Kegiatan',
              hintText: 'Misal: Kalkulus II',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _roomController,
            decoration: InputDecoration(
              labelText: 'Ruangan / Tautan Kelas',
              hintText: 'Misal: Ruang Lab 304 atau Zoom Link',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Hari',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  initialValue: _selectedDay,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Senin')),
                    DropdownMenuItem(value: 2, child: Text('Selasa')),
                    DropdownMenuItem(value: 3, child: Text('Rabu')),
                    DropdownMenuItem(value: 4, child: Text('Kamis')),
                    DropdownMenuItem(value: 5, child: Text('Jumat')),
                    DropdownMenuItem(value: 6, child: Text('Sabtu')),
                    DropdownMenuItem(value: 7, child: Text('Minggu')),
                  ],
                  onChanged: (v) => setState(() => _selectedDay = v ?? 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Jenis',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  initialValue: _selectedType,
                  items: const [
                    DropdownMenuItem(value: 'class', child: Text('Kuliah')),
                    DropdownMenuItem(value: 'lab', child: Text('Praktikum')),
                    DropdownMenuItem(value: 'seminar', child: Text('Seminar')),
                    DropdownMenuItem(
                      value: 'group',
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Belajar Kelompok'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedType = v ?? 'class'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Waktu Kegiatan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time, size: 16, color: Color(0xFF0F172A)),
                  label: Text(
                    'Mulai: ${_startTime.format(context)}',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                  ),
                  onPressed: _pickStartTime,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time, size: 16, color: Color(0xFF0F172A)),
                  label: Text(
                    'Selesai: ${_endTime.format(context)}',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                  ),
                  onPressed: _pickEndTime,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Simpan Jadwal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _KrsParserBottomSheet extends StatefulWidget {
  final Function(String) onParse;
  const _KrsParserBottomSheet({Key? key, required this.onParse}) : super(key: key);

  @override
  State<_KrsParserBottomSheet> createState() => _KrsParserBottomSheetState();
}

class _KrsParserBottomSheetState extends State<_KrsParserBottomSheet> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Auto-Generate dari Teks KRS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          const Text(
            'Tempelkan teks KRS atau info kelas Anda di bawah ini.\nContoh format:\nSenin - 08:00-10:00 - Aljabar Linear - R.402\nSelasa - 13:00-15:00 - Kimia Dasar - Lab',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Tempelkan teks di sini...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              final text = _textController.text.trim();
              Navigator.pop(context);
              if (text.isNotEmpty) {
                widget.onParse(text);
              }
            },
            child: const Text('Parse & Tambahkan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}