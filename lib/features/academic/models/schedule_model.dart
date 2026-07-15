class ScheduleModel {
  final String id;
  final String subject;
  final String room;
  final String startTime;
  final String endTime;
  final int dayOfWeek;
  final String type;
  final int taskCount;

  ScheduleModel({
    required this.id,
    required this.subject,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.dayOfWeek,
    required this.type,
    this.taskCount = 0,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    // Fungsi pembantu untuk memotong format "08:00:00" menjadi "08:00"
    String formatTime(String? timeStr) {
      if (timeStr == null || timeStr.isEmpty) return '00:00';
      final parts = timeStr.split(':');
      if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
      return timeStr;
    }

    int countTasks = 0;
    if (json['tasks'] != null) {
      final List tasksList = json['tasks'] as List;
      countTasks = tasksList.where((t) => t['is_completed'] == false).length;
    }

    return ScheduleModel(
      id: json['id'] ?? '',
      subject: json['subject'] ?? '',
      room: json['room'] ?? '',
      startTime: formatTime(json['start_time']),
      endTime: formatTime(json['end_time']),
      dayOfWeek: json['day_of_week'] ?? 1,
      type: json['type'] ?? 'class',
      taskCount: countTasks,
    );
  }
}