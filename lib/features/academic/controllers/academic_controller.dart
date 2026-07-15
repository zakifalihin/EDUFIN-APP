import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule_model.dart';

class AcademicController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Mengambil daftar jadwal berdasarkan filter hari (1-7)
  Future<List<ScheduleModel>> getSchedulesByDay(int dayOfWeek) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User belum login');

      final response = await _supabase
          .from('academic_schedules')
          .select('*, tasks(id, is_completed)')
          .eq('user_id', userId)
          .eq('day_of_week', dayOfWeek)
          .order('start_time', ascending: true);

      return (response as List).map((e) => ScheduleModel.fromJson(e)).toList();
    } catch (e) {
      print('Error fetch academic schedules: $e');
      rethrow;
    }
  }

  /// Mengambil jadwal kuliah beserta relasi jumlah tugas yang belum selesai
  Future<List<Map<String, dynamic>>> getSchedulesWithTasksCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User belum login');

      // Ambil jadwal kuliah
      final response = await _supabase
          .from('academic_schedules')
          .select('''
            *,
            tasks(id, is_completed)
          ''') // Teknik Sub-Query Join untuk menarik data tugas yang menempel pada matkul ini
          .eq('user_id', userId);

      final List<Map<String, dynamic>> schedules = List<Map<String, dynamic>>.from(response);

      // Hitung jumlah tugas yang belum selesai untuk setiap matkul secara lokal
      for (var schedule in schedules) {
        final List tasks = schedule['tasks'] ?? [];
        final int uncompletedCount = tasks.where((t) => t['is_completed'] == false).length;
        
        // Simpan field baru ke dalam map untuk dibaca di UI nanti
        schedule['uncompleted_tasks_count'] = uncompletedCount;
      }

      return schedules;
    } catch (e) {
      print('Error fetch schedules with tasks: $e');
      rethrow;
    }
  }

  // Fungsi untuk menambahkan jadwal manual
  Future<String?> insertSchedule({
    required String subject,
    required String room,
    required String startTime,
    required String endTime,
    required int dayOfWeek,
    required String type,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'User belum login';

      await _supabase.from('academic_schedules').insert({
        'user_id': userId,
        'subject': subject,
        'room': room,
        'start_time': startTime,
        'end_time': endTime,
        'day_of_week': dayOfWeek,
        'type': type,
      });

      return null; // Sukses
    } catch (e) {
      print('Error insert schedule: $e');
      return e.toString();
    }
  }
}