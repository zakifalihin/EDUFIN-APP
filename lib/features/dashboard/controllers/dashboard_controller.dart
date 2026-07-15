import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';

class DashboardController {
  final _supabase = Supabase.instance.client;

  // Fungsi mengambil data tugas mendesak
  Future<List<TaskModel>> getUrgentTasks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('tasks')
          .select('*, academic_schedules(subject)')
          .eq('user_id', userId)
          .eq('is_completed', false)
          .order('deadline', ascending: true)
          .limit(3);

      return (response as List)
          .map((json) => TaskModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error ambil data tugas di DashboardController: $e');
      return [];
    }
  }

  // Mengambil data jajan harian akumulatif dan spent per rekening
  Future<Map<String, dynamic>?> getDailyBudget() async {
    try {
      final user = _supabase.auth.currentUser;
      final userId = user?.id;
      if (userId == null) return null;

      // 1. Ambil limit global dari metadata
      final double globalLimit = (user?.userMetadata?['global_budget_limit'] ?? 100000.0).toDouble();

      // 2. Hitung spent harian untuk masing-masing dompet hari ini
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      
      final txRes = await _supabase
          .from('transactions')
          .select('amount, title')
          .eq('user_id', userId)
          .eq('type', 'expense')
          .gte('created_at', startOfDay);

      double totalSpent = 0.0;
      Map<String, double> spentPerWallet = {};

      for (var tx in txRes) {
        final double amount = (tx['amount'] ?? 0.0).toDouble();
        final String title = tx['title'] ?? '';
        totalSpent += amount;

        if (title.startsWith('[')) {
          final closeBracketIdx = title.indexOf(']');
          if (closeBracketIdx != -1) {
            final walletName = title.substring(1, closeBracketIdx).toUpperCase();
            spentPerWallet[walletName] = (spentPerWallet[walletName] ?? 0.0) + amount;
          }
        } else {
          // Fallback ke DOMPET UTAMA
          spentPerWallet['DOMPET UTAMA'] = (spentPerWallet['DOMPET UTAMA'] ?? 0.0) + amount;
        }
      }

      return {
        'global_limit': globalLimit,
        'total_spent': totalSpent,
        'spent_per_wallet': spentPerWallet,
      };
    } catch (e) {
      print('Error ambil budget: $e');
      return null;
    }
  }

  // Mengubah limit jajan harian keseluruhan (Global)
  Future<String?> updateGlobalBudget(double newLimit) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(data: {'global_budget_limit': newLimit}),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Mengubah limit jajan harian untuk satu dompet spesifik
  Future<String?> updateWalletBudget(String walletId, double newLimit) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 'User belum login';

      final walletsObj = user.userMetadata?['wallets'];
      if (walletsObj == null) return 'Data dompet tidak ditemukan';

      List<Map<String, dynamic>> wallets = List<Map<String, dynamic>>.from(
        (walletsObj as List).map((e) => Map<String, dynamic>.from(e)),
      );

      for (var i = 0; i < wallets.length; i++) {
        if (wallets[i]['id'] == walletId) {
          wallets[i]['budget_limit'] = newLimit;
          break;
        }
      }

      await _supabase.auth.updateUser(
        UserAttributes(data: {'wallets': wallets}),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Menyimpan selected dashboard wallet id ke auth metadata agar konsisten
  Future<String?> saveSelectedWalletId(String walletId) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(data: {'selected_dashboard_wallet_id': walletId}),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}