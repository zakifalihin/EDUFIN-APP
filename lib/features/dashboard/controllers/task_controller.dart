import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';

class TaskController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fungsi mengambil semua tugas mendesak yang belum selesai, diurutkan dari yang paling mepet deadline-nya
  Future<List<TaskModel>> getUrgentTasks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User belum login');

      final response = await _supabase
          .from('tasks')
          .select('*, academic_schedules(subject)') // Teknik Relational JOIN
          .eq('user_id', userId)
          .eq('is_completed', false)
          .order('deadline', ascending: true);

      return (response as List).map((e) => TaskModel.fromJson(e)).toList();
    } catch (e) {
      print('Error fetch urgent tasks: $e');
      rethrow;
    }
  }

  Future<String?> insertTask({
    required String title,
    required String taskType,
    required DateTime deadline,
    String? scheduleId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'User belum login';

      await _supabase.from('tasks').insert({
        'user_id': userId,
        'schedule_id': scheduleId, // Bisa bernilai null jika Opsi B (tugas luar kuliah)
        'title': title,
        'task_type': taskType,
        'deadline': deadline.toIso8601String(),
        'is_completed': false,
      });

      return null; // Sukses tanpa error
    } catch (e) {
      print('Error insert task: $e');
      return e.toString();
    }
  }

  /// Method pembantu untuk mengambil semua mata kuliah saat mengisi dropdown di form
  Future<List<Map<String, dynamic>>> getAllSchedulesForDropdown() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('academic_schedules')
          .select('id, subject')
          .eq('user_id', userId);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error get schedules for dropdown: $e');
      return [];
    }
  }

  // Fungsi untuk mengubah status penyelesaian tugas
  Future<String?> toggleTaskCompletion(String taskId, bool isCompleted) async {
    try {
      await _supabase
          .from('tasks')
          .update({'is_completed': isCompleted})
          .eq('id', taskId);
      return null; // Sukses
    } catch (e) {
      print('Error update task completion: $e');
      return e.toString();
    }
  }

  // Fungsi mengambil semua tugas yang sudah selesai
  Future<List<TaskModel>> getCompletedTasks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User belum login');

      final response = await _supabase
          .from('tasks')
          .select('*, academic_schedules(subject)')
          .eq('user_id', userId)
          .eq('is_completed', true)
          .order('deadline', ascending: false)
          .limit(5);

      return (response as List).map((e) => TaskModel.fromJson(e)).toList();
    } catch (e) {
      print('Error fetch completed tasks: $e');
      return [];
    }
  }

  // Fungsi menghapus tugas
  Future<String?> deleteTask(String taskId) async {
    try {
      await _supabase
          .from('tasks')
          .delete()
          .eq('id', taskId);
      return null; // Sukses
    } catch (e) {
      print('Error delete task: $e');
      return e.toString();
    }
  }

  // Fungsi mengupdate tugas secara manual
  Future<String?> updateTask({
    required String taskId,
    required String title,
    required String taskType,
    required DateTime deadline,
    String? scheduleId,
  }) async {
    try {
      await _supabase
          .from('tasks')
          .update({
            'title': title,
            'task_type': taskType,
            'deadline': deadline.toIso8601String(),
            'schedule_id': scheduleId,
          })
          .eq('id', taskId);
      return null; // Sukses
    } catch (e) {
      print('Error update task: $e');
      return e.toString();
    }
  }

  // Fungsi mengambil seluruh tugas pengguna untuk keperluan kalender & rekap mingguan
  Future<List<TaskModel>> getAllTasks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User belum login');

      final response = await _supabase
          .from('tasks')
          .select('*, academic_schedules(subject)')
          .eq('user_id', userId)
          .order('deadline', ascending: true);

      return (response as List).map((e) => TaskModel.fromJson(e)).toList();
    } catch (e) {
      print('Error fetch all tasks: $e');
      return [];
    }
  }
}