class TaskModel {
  final String id;
  final String? scheduleId;
  final String title;
  final String taskType; // 'academic', 'organization', 'personal'
  final DateTime deadline;
  final bool isCompleted;
  final String? subjectName; // Menampung nama matkul hasil dari teknik JOIN database

  TaskModel({
    required this.id,
    this.scheduleId,
    required this.title,
    required this.taskType,
    required this.deadline,
    required this.isCompleted,
    this.subjectName,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? '',
      scheduleId: json['schedule_id'],
      title: json['title'] ?? '',
      taskType: json['task_type'] ?? 'personal',
      deadline: DateTime.parse(json['deadline']),
      isCompleted: json['is_completed'] ?? false,
      // Membaca object hasil relasi JOIN table academic_schedules
      subjectName: json['academic_schedules'] != null 
          ? json['academic_schedules']['subject'] 
          : null,
    );
  }
}