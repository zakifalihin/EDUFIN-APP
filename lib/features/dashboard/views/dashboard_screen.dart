import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/task_controller.dart';
import '../models/task_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardController _dashController = DashboardController();
  final TaskController _taskController = TaskController();

  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _showCompletedTasks = false;
  List<TaskModel> _urgentTasks = [];
  List<TaskModel> _completedTasks = [];
  Map<String, dynamic>? _budgetData;
  String _selectedDashboardWalletId = 'overall';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _selectedDashboardWalletId = user?.userMetadata?['selected_dashboard_wallet_id']?.toString() ?? 'overall';
    _fetchData();
  }

  void _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final savedWalletId = user?.userMetadata?['selected_dashboard_wallet_id']?.toString() ?? 'overall';
      final results = await Future.wait([
        _taskController.getUrgentTasks(), // Index [0]
        _dashController.getDailyBudget(), // Index [1]
        _taskController.getCompletedTasks(), // Index [2]
      ]);

      if (mounted) {
        setState(() {
          _selectedDashboardWalletId = savedWalletId;
          _urgentTasks = List<TaskModel>.from(results[0] as Iterable);
          _budgetData = results[1] as Map<String, dynamic>?;
          _completedTasks = List<TaskModel>.from(results[2] as Iterable);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _refreshData() {
    _fetchData();
  }

  void _toggleTaskCompletion(TaskModel task, bool isCompleted) async {
    final updatedTask = TaskModel(
      id: task.id,
      scheduleId: task.scheduleId,
      title: task.title,
      taskType: task.taskType,
      deadline: task.deadline,
      isCompleted: isCompleted,
      subjectName: task.subjectName,
    );

    // 1. Optimistic Update (UI Terupdate Instan!)
    setState(() {
      if (isCompleted) {
        _urgentTasks.removeWhere((t) => t.id == task.id);
        _completedTasks.insert(0, updatedTask);
      } else {
        _completedTasks.removeWhere((t) => t.id == task.id);
        _urgentTasks.add(updatedTask);
        _urgentTasks.sort((a, b) => a.deadline.compareTo(b.deadline));
      }
    });

    // 2. Kirim update ke database
    final err = await _taskController.toggleTaskCompletion(task.id, isCompleted);
    if (err != null) {
      _refreshData(); // Rollback jika gagal
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui tugas: $err'), backgroundColor: Colors.red),
        );
      }
    } else {
      // Perbarui budget di background secara halus
      try {
        final updatedBudget = await _dashController.getDailyBudget();
        if (mounted) {
          setState(() {
            _budgetData = updatedBudget;
          });
        }
      } catch (_) {}
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi ☀️';
    if (hour < 15) return 'Selamat Siang 🌤️';
    if (hour < 19) return 'Selamat Sore 🌅';
    return 'Selamat Malam 🌙';
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now);
    if (difference.isNegative) {
      return 'Terlewat';
    }
    if (difference.inDays == 0) {
      return 'Hari ini, ${DateFormat('HH:mm').format(deadline)}';
    } else if (difference.inDays == 1) {
      return 'Besok, ${DateFormat('HH:mm').format(deadline)}';
    } else {
      return DateFormat('dd MMM, HH:mm').format(deadline);
    }
  }

  void _confirmDeleteTask(TaskModel task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Tugas', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus tugas "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await _taskController.deleteTask(task.id);
              if (err == null) {
                _refreshData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tugas berhasil dihapus')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus tugas: $err'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editTask(TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _EditTaskBottomSheet(
        controller: _taskController,
        task: task,
        onSuccess: _refreshData,
      ),
    );
  }

  void _showEditDashboardBudgetDialog(List<Map<String, dynamic>> wallets) async {
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _EditDashboardBudgetSheet(
        wallets: wallets,
        initialSelectedWalletId: _selectedDashboardWalletId,
        controller: _dashController,
        onSuccess: _refreshData,
      ),
    );

    if (selectedId != null && mounted) {
      setState(() {
        _selectedDashboardWalletId = selectedId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ambil nama dan foto profil dari metadata Supabase Auth dengan fallback email/mahasiswa
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            // Ambil daftar dompet dari metadata untuk dropdown selector
            final walletsObj = user?.userMetadata?['wallets'];
            List<Map<String, dynamic>> wallets = [];
            if (walletsObj != null) {
              wallets = List<Map<String, dynamic>>.from(
                (walletsObj as List).map((e) => Map<String, dynamic>.from(e)),
              );
            }

            if (_isLoading && _urgentTasks.isEmpty && _budgetData == null) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
            }
            if (_errorMessage != null && _urgentTasks.isEmpty && _budgetData == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Gagal memuat data: $_errorMessage', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshData,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                        child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                ),
              );
            }

            final urgentTasks = _urgentTasks;
            final completedTasks = _completedTasks;

            // Hitung limit dan spent sesuai filter pilihan dompet di Dashboard
            double limit = 0.0;
            double spent = 0.0;

            if (_selectedDashboardWalletId == 'overall') {
              if (wallets.isNotEmpty) {
                for (var w in wallets) {
                  limit += (w['budget_limit'] ?? 100000.0).toDouble();
                }
              } else {
                limit = (_budgetData?['global_limit'] ?? 100000.0).toDouble();
              }
              spent = (_budgetData?['total_spent'] ?? 0.0).toDouble();
            } else {
              final activeWallet = wallets.firstWhere(
                (w) => w['id'].toString() == _selectedDashboardWalletId,
                orElse: () => {'name': 'DOMPET', 'budget_limit': 100000.0},
              );
              limit = (activeWallet['budget_limit'] ?? 100000.0).toDouble();
              final spentMap = _budgetData?['spent_per_wallet'] as Map?;
              spent = (spentMap?[activeWallet['name'].toString().toUpperCase()] ?? 0.0).toDouble();
            }

            final double remaining = limit - spent;
            final double spentPercent = limit > 0 ? (spent / limit) : 0.0;
            final double percentLeft = limit > 0 ? (remaining / limit) * 100 : 0;

            return RefreshIndicator(
              onRefresh: () async {
                _refreshData();
              },
              color: const Color(0xFF0F172A),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: NetworkImage(profilePhoto),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_getGreeting(), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 2),
                                    Text(
                                      userName, 
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.notifications_outlined, size: 24, color: Color(0xFF0F172A)),
                            onPressed: () {
                              // Fitur notifikasi
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // KARTU FINANCE
                    GestureDetector(
                      onTap: () => _showEditDashboardBudgetDialog(wallets),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (limit == 0) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedDashboardWalletId == 'overall'
                                          ? 'Anggaran Jajan (Keseluruhan)'
                                          : 'Anggaran Jajan (${wallets.firstWhere((w) => w['id'].toString() == _selectedDashboardWalletId, orElse: () => {'name': 'DOMPET'})['name'].toString().toUpperCase()})',
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Batas anggaran harian belum diatur. Klik kartu ini untuk memilih rekening dan mengatur jatah harianmu.',
                                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                              ),
                            ] else ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedDashboardWalletId == 'overall'
                                          ? 'Anggaran Jajan (Keseluruhan)'
                                          : 'Anggaran Jajan (${wallets.firstWhere((w) => w['id'].toString() == _selectedDashboardWalletId, orElse: () => {'name': 'DOMPET'})['name'].toString().toUpperCase()})',
                                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('${percentLeft.toInt()}% Sisa', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.edit_outlined, color: Colors.white70, size: 16),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currencyFormatter.format(remaining),
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 20),
                              // Visual Progress Bar (Anggaran Tersisa)
                              Container(
                                height: 8,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (1.0 - spentPercent).clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: spentPercent >= 0.9 
                                            ? [Colors.red, Colors.redAccent] 
                                            : spentPercent >= 0.75 
                                                ? [Colors.orange, Colors.orangeAccent] 
                                                : [const Color(0xFFFFC107), const Color(0xFFFFD54F)],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Terpakai: ${currencyFormatter.format(spent)}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Limit: ${currencyFormatter.format(limit)}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      textAlign: TextAlign.end,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // URGENT TASKS HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Tugas Mendesak', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            if (urgentTasks.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFFFC107).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                  '${urgentTasks.length}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB48811)),
                                ),
                              ),
                            ]
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            builder: (ctx) => _AddTaskBottomSheet(controller: _taskController, onSuccess: _refreshData),
                          ),
                          icon: const Icon(Icons.add, size: 16, color: Color(0xFFB48811)),
                          label: const Text('Add Task', style: TextStyle(color: Color(0xFFB48811), fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),

                    // LIST TUGAS
                    if (urgentTasks.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade300),
                            const SizedBox(height: 12),
                            const Text('Semua tugas selesai!', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 4),
                            const Text('Tidak ada tugas mendesak untuk saat ini.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    else
                      ...urgentTasks.map((task) => _buildTaskCard(task)),

                    // SEKSI KOLAPS TUGAS SELESAI
                    if (completedTasks.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => setState(() => _showCompletedTasks = !_showCompletedTasks),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text('Tugas Selesai', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                                    child: Text(
                                      '${completedTasks.length}',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                _showCompletedTasks ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_showCompletedTasks)
                        ...completedTasks.map((task) => _buildCompletedTaskCard(task)),
                    ],

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final isAcademic = task.taskType == 'academic';
    final badgeColor = isAcademic ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
    final badgeText = isAcademic ? 'Akademik' : 'Personal';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              _toggleTaskCompletion(task, true);
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                color: Colors.transparent,
              ),
              child: const Icon(Icons.check, size: 14, color: Colors.transparent),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.subjectName ?? badgeText,
                          style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _formatDeadline(task.deadline),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
            onSelected: (value) {
              if (value == 'edit') {
                _editTask(task);
              } else if (value == 'delete') {
                _confirmDeleteTask(task);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0F172A)),
                    SizedBox(width: 8),
                    Text('Edit Tugas', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus Tugas', style: TextStyle(fontSize: 13, color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedTaskCard(TaskModel task) {
    return Opacity(
      opacity: 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                _toggleTaskCompletion(task, false);
              },
              child: Icon(Icons.check_circle, color: Colors.green.shade500, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                      decoration: TextDecoration.lineThrough,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.subjectName ?? (task.taskType == 'academic' ? 'Akademik' : 'Personal'),
                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
              onSelected: (value) {
                if (value == 'edit') {
                  _editTask(task);
                } else if (value == 'delete') {
                  _confirmDeleteTask(task);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0F172A)),
                      SizedBox(width: 8),
                      Text('Edit Tugas', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Hapus Tugas', style: TextStyle(fontSize: 13, color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTaskBottomSheet extends StatefulWidget {
  final TaskController controller;
  final VoidCallback onSuccess;
  const _AddTaskBottomSheet({required this.controller, required this.onSuccess});

  @override
  State<_AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<_AddTaskBottomSheet> {
  final _titleController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now().add(const Duration(days: 1));
  List<Map<String, dynamic>> _schedules = [];
  String? _selectedScheduleId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.getAllSchedulesForDropdown().then((val) => setState(() => _schedules = val));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
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

    if (pickedDate != null) {
      setState(() {
        _selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
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

    if (pickedTime != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  void _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tugas tidak boleh kosong!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final err = await widget.controller.insertTask(
      title: title,
      taskType: _selectedScheduleId != null ? 'academic' : 'personal',
      deadline: _selectedDateTime,
      scheduleId: _selectedScheduleId,
    );

    setState(() => _isLoading = false);

    if (err == null) {
      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan tugas: $err'), backgroundColor: Colors.red),
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
              const Text('Tambah Tugas Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Nama Tugas',
              hintText: 'Misal: Laporan Praktikum Jaringan',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            decoration: InputDecoration(
              labelText: 'Mata Kuliah (Opsional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
              ),
            ),
            hint: const Text('Pilih Mata Kuliah'),
            initialValue: _selectedScheduleId,
            items: [
              const DropdownMenuItem(value: null, child: Text('Tidak ada (Tugas Pribadi)')),
              ..._schedules.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['subject']))),
            ],
            onChanged: (v) => setState(() => _selectedScheduleId = v),
          ),
          const SizedBox(height: 18),
          const Text('Batas Waktu (Deadline)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0F172A)),
                  label: Text(
                    DateFormat('dd MMM yyyy').format(_selectedDateTime),
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                  ),
                  onPressed: _pickDate,
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
                    DateFormat('HH:mm').format(_selectedDateTime),
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                  ),
                  onPressed: _pickTime,
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
                : const Text('Simpan Tugas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _EditTaskBottomSheet extends StatefulWidget {
  final TaskController controller;
  final TaskModel task;
  final VoidCallback onSuccess;
  const _EditTaskBottomSheet({required this.controller, required this.task, required this.onSuccess});

  @override
  State<_EditTaskBottomSheet> createState() => _EditTaskBottomSheetState();
}

class _EditTaskBottomSheetState extends State<_EditTaskBottomSheet> {
  late final TextEditingController _titleController;
  late DateTime _selectedDateTime;
  List<Map<String, dynamic>> _schedules = [];
  String? _selectedScheduleId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _selectedDateTime = widget.task.deadline;
    _selectedScheduleId = widget.task.scheduleId;
    widget.controller.getAllSchedulesForDropdown().then((val) => setState(() => _schedules = val));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: now.subtract(const Duration(days: 365)), // Memungkinkan tanggal lalu jika mengedit
      lastDate: now.add(const Duration(days: 365)),
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

    if (pickedDate != null) {
      setState(() {
        _selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
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

    if (pickedTime != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  void _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tugas tidak boleh kosong!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final err = await widget.controller.updateTask(
      taskId: widget.task.id,
      title: title,
      taskType: _selectedScheduleId != null ? 'academic' : 'personal',
      deadline: _selectedDateTime,
      scheduleId: _selectedScheduleId,
    );

    setState(() => _isLoading = false);

    if (err == null) {
      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui tugas: $err'), backgroundColor: Colors.red),
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
              const Text('Edit Tugas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Nama Tugas',
              hintText: 'Misal: Laporan Praktikum Jaringan',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            decoration: InputDecoration(
              labelText: 'Mata Kuliah (Opsional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
              ),
            ),
            hint: const Text('Pilih Mata Kuliah'),
            initialValue: _selectedScheduleId,
            items: [
              const DropdownMenuItem(value: null, child: Text('Tidak ada (Tugas Pribadi)')),
              ..._schedules.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['subject']))),
            ],
            onChanged: (v) => setState(() => _selectedScheduleId = v),
          ),
          const SizedBox(height: 18),
          const Text('Batas Waktu (Deadline)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0F172A)),
                  label: Text(
                    DateFormat('dd MMM yyyy').format(_selectedDateTime),
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                  ),
                  onPressed: _pickDate,
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
                    DateFormat('HH:mm').format(_selectedDateTime),
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                  ),
                  onPressed: _pickTime,
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
                : const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _EditDashboardBudgetSheet extends StatefulWidget {
  final List<Map<String, dynamic>> wallets;
  final String initialSelectedWalletId;
  final DashboardController controller;
  final VoidCallback onSuccess;

  const _EditDashboardBudgetSheet({
    required this.wallets,
    required this.initialSelectedWalletId,
    required this.controller,
    required this.onSuccess,
  });

  @override
  State<_EditDashboardBudgetSheet> createState() => _EditDashboardBudgetSheetState();
}

class _EditDashboardBudgetSheetState extends State<_EditDashboardBudgetSheet> {
  late String _selectedWalletId;
  late List<Map<String, dynamic>> _controllers;
  late TextEditingController _singleController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialSelectedWalletId;
    _initControllers();
  }

  void _initControllers() {
    _controllers = widget.wallets.map((w) {
      return {
        'id': w['id'].toString(),
        'name': w['name'].toString(),
        'controller': TextEditingController(text: (w['budget_limit'] ?? 100000.0).toInt().toString()),
      };
    }).toList();

    if (_selectedWalletId != 'overall') {
      final activeWallet = widget.wallets.firstWhere(
        (w) => w['id'].toString() == _selectedWalletId, 
        orElse: () => {'budget_limit': 100000.0}
      );
      _singleController = TextEditingController(text: (activeWallet['budget_limit'] ?? 100000.0).toInt().toString());
    } else {
      _singleController = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      (c['controller'] as TextEditingController).dispose();
    }
    _singleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24, left: 24, right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Anggaran & Rekening', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // SECTION 1: TAMPILKAN REKENING
            const Text('PILIH TAMPILAN DOMPET / REKENING', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Overall Pill
                  _buildWalletPill(
                    id: 'overall',
                    name: 'Keseluruhan',
                    gradientColors: [const Color(0xFF0F172A), const Color(0xFF334155)],
                    isSelected: _selectedWalletId == 'overall',
                  ),
                  ...widget.wallets.map((w) {
                    final String name = w['name'].toString().toUpperCase();
                    List<Color> gradientColors = [const Color(0xFF475569), const Color(0xFF64748B)];
                    if (name.contains('BCA')) {
                      gradientColors = [const Color(0xFF003D7C), const Color(0xFF005EAF)];
                    } else if (name.contains('MANDIRI')) {
                      gradientColors = [const Color(0xFF1C3F94), const Color(0xFF0F255C)];
                    } else if (name.contains('BRI')) {
                      gradientColors = [const Color(0xFF00529C), const Color(0xFF002C6C)];
                    } else if (name.contains('BNI')) {
                      gradientColors = [const Color(0xFF005E6A), const Color(0xFF008D96)];
                    } else if (name.contains('BSI') || name.contains('SYARIAH')) {
                      gradientColors = [const Color(0xFF005F5F), const Color(0xFF008080)];
                    } else if (name.contains('JAGO')) {
                      gradientColors = [const Color(0xFFFFD54F), const Color(0xFFF57F17)];
                    } else if (name.contains('GOPAY')) {
                      gradientColors = [const Color(0xFF00AED6), const Color(0xFF0085A6)];
                    } else if (name.contains('OVO')) {
                      gradientColors = [const Color(0xFF4C2A86), const Color(0xFF2B1354)];
                    } else if (name.contains('DANA')) {
                      gradientColors = [const Color(0xFF118EEA), const Color(0xFF0B62A4)];
                    } else if (name.contains('SHOPEEPAY') || name.contains('SHOPEE')) {
                      gradientColors = [const Color(0xFFEE4D2D), const Color(0xFFF57F20)];
                    } else if (name.contains('LINKAJA')) {
                      gradientColors = [const Color(0xFFE61B2B), const Color(0xFF9F0D18)];
                    } else if (name.contains('CASH') || name.contains('TUNAI')) {
                      gradientColors = [const Color(0xFF065F46), const Color(0xFF10B981)];
                    }

                    return _buildWalletPill(
                      id: w['id'].toString(),
                      name: name,
                      gradientColors: gradientColors,
                      isSelected: _selectedWalletId == w['id'].toString(),
                    );
                  }).toList(),
                ],
              ),
            ),
            
            const SizedBox(height: 28),
            
            // SECTION 2: EDIT LIMIT ANGGARAN
            const Text('ATUR LIMIT JAJAN HARIAN', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 16),
            
            if (_selectedWalletId == 'overall') ...[
              // Edit All limits
              ..._controllers.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['name'].toString().toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: c['controller'] as TextEditingController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixText: 'Rp ',
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107))),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ] else ...[
              // Edit single limit
              TextField(
                controller: _singleController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107))),
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _saveData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Simpan & Terapkan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletPill({
    required String id,
    required String name,
    required List<Color> gradientColors,
    required bool isSelected,
  }) {
    final bool isDarkText = name.contains('JAGO');

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWalletId = id;
          _initControllers();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected ? gradientColors : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? (isDarkText ? Colors.black26 : Colors.white24) 
                : const Color(0xFFE2E8F0), 
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradientColors[0].withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Text(
          name,
          style: TextStyle(
            color: isSelected 
                ? (isDarkText ? const Color(0xFF0F172A) : Colors.white) 
                : const Color(0xFF475569),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _saveData() async {
    setState(() => _isLoading = true);
    bool hasError = false;
    String? errMsg;

    // Simpan filter tampilan dompet aktif ke metadata
    final saveErr = await widget.controller.saveSelectedWalletId(_selectedWalletId);
    if (saveErr != null) {
      hasError = true;
      errMsg = saveErr;
    }

    if (!hasError) {
      if (_selectedWalletId == 'overall') {
        // Simpan semua limit dompet
        for (var c in _controllers) {
          final id = c['id'].toString();
          final newLimit = double.tryParse((c['controller'] as TextEditingController).text.trim()) ?? 0;
          if (newLimit < 0) {
            hasError = true;
            errMsg = 'Limit tidak boleh kurang dari 0!';
            break;
          }
          final err = await widget.controller.updateWalletBudget(id, newLimit);
          if (err != null) {
            hasError = true;
            errMsg = err;
            break;
          }
        }
      } else {
        // Simpan limit untuk dompet tunggal
        final newLimit = double.tryParse(_singleController.text.trim()) ?? 0;
        if (newLimit < 0) {
          hasError = true;
          errMsg = 'Limit tidak boleh kurang dari 0!';
        } else {
          final err = await widget.controller.updateWalletBudget(_selectedWalletId, newLimit);
          if (err != null) {
            hasError = true;
            errMsg = err;
          }
        }
      }
    }

    setState(() => _isLoading = false);

    if (!hasError) {
      widget.onSuccess();
      if (mounted) Navigator.pop(context, _selectedWalletId);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg ?? 'Gagal menyimpan anggaran'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
