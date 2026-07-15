import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:edufin/features/finance/controllers/finance_controller.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FinanceController _financeController = FinanceController();

  bool _isLoadingData = true;
  String _userName = 'Pengguna EduFin';
  String _profilePhoto = '';
  String _institute = 'Global Institute of Technology & Finance';
  
  int _completedTasksCount = 0;
  double _totalSavings = 0.0;
  int _schedulesCount = 0;

  // Gmail Sync State variables
  String _gmailUser = '';
  bool _isGmailConnected = false;
  bool _isSyncingGmail = false;

  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoadingData = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // 1. Get User profile metadata info
        final metadata = user.userMetadata ?? {};
        _userName = metadata['full_name']?.toString() ?? user.email?.split('@')[0] ?? 'Pengguna EduFin';
        _profilePhoto = metadata['avatar_url']?.toString() ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_userName)}&background=0F172A&color=fff&size=150&bold=true';
        _institute = metadata['institute']?.toString() ?? 'Global Institute of Technology & Finance';

        // Get Gmail status
        _gmailUser = metadata['gmail_user']?.toString() ?? '';
        _isGmailConnected = metadata['gmail_connected'] == true && _gmailUser.isNotEmpty;

        // 2. Fetch completed tasks count from Supabase
        final completedTasksRes = await _supabase
            .from('tasks')
            .select('id')
            .eq('user_id', user.id)
            .eq('is_completed', true);
        _completedTasksCount = (completedTasksRes as List).length;

        // 3. Sum savings balances from metadata wallets
        final List<dynamic> wallets = _financeController.getWalletsFromMetadata();
        _totalSavings = wallets.fold(0.0, (sum, w) => sum + (w['balance'] ?? 0.0).toDouble());

        // 4. Fetch academic schedules count from Supabase
        final schedulesRes = await _supabase
            .from('academic_schedules')
            .select('id')
            .eq('user_id', user.id);
        _schedulesCount = (schedulesRes as List).length;
      }
    } catch (e) {
      debugPrint('Error loading profile info: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  void _connectGoogleAccount() async {
    setState(() => _isSyncingGmail = true);
    try {
      final googleSignIn = GoogleSignIn.instance;
      final account = await googleSignIn.authenticate();
      if (account == null) {
        setState(() => _isSyncingGmail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koneksi Google dibatalkan.'), backgroundColor: Colors.orange),
        );
        return;
      }

      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isSyncingGmail = false);
        return;
      }

      await _supabase.auth.updateUser(
        UserAttributes(data: {
          'gmail_connected': true,
          'gmail_user': account.email,
        })
      );

      await _loadProfileData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil menghubungkan Gmail (${account.email})!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghubungkan Google: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSyncingGmail = false);
    }
  }

  void _disconnectGoogleAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Putuskan Gmail?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin memutuskan akses pembacaan Gmail transaksi dari EduFin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Putuskan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSyncingGmail = true);
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.signOut();

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.auth.updateUser(
        UserAttributes(data: {
          'gmail_connected': false,
          'gmail_user': null,
        })
      );

      await _loadProfileData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koneksi Gmail berhasil diputuskan.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memutuskan Google: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSyncingGmail = false);
    }
  }

  void _syncEmailTransactions() async {
    setState(() => _isSyncingGmail = true);
    final res = await _financeController.syncTransactionsFromEmail();
    if (mounted) {
      setState(() => _isSyncingGmail = false);
      final bool success = res['success'] ?? false;
      final String msg = res['message'] ?? '';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        _loadProfileData();
      }
    }
  }

  void _handleLogout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal logout: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfileData,
          color: const Color(0xFF0F172A),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header (EDUFIN, Avatar, Lonceng)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: NetworkImage(_profilePhoto),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'EDUFIN',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A), size: 24),
                  ],
                ),
                const SizedBox(height: 32),

                // 2. Profile Card besar & Premium Badge
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomCenter,
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Image.network(
                                _profilePhoto,
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC107),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded, size: 10, color: Color(0xFF0F172A)),
                                  SizedBox(width: 4),
                                  Text(
                                    'PREMIUM',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _institute,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 3. Row Statistik Tiga Kolom
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        value: '$_completedTasksCount',
                        label: 'Tasks Done',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        value: _isLoadingData 
                            ? '...' 
                            : currencyFormatter.format(_totalSavings).replaceAll('Rp ', 'Rp'),
                        label: 'Savings',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        value: '${_schedulesCount * 3}h',
                        label: 'Study',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 4. Gmail Connection Card (Relocated from Finance)
                _buildGmailSyncCard(),
                const SizedBox(height: 24),

                // 5. White card containing options list
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildMenuOption(
                        icon: Icons.person_outline_rounded,
                        title: 'Personal Information',
                        showChevron: true,
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        icon: Icons.school_outlined,
                        title: 'Academic Settings',
                        subtitle: 'Syllabus, GPA tracking',
                        showChevron: true,
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Financial Goals',
                        subtitle: 'Target: MacBook Pro M3',
                        showChevron: true,
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        icon: Icons.security_rounded,
                        title: 'Security & Privacy',
                        showChevron: true,
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        showChevron: true,
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        icon: Icons.help_outline_rounded,
                        title: 'Help Center',
                        showChevron: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 6. Logout Button
                Center(
                  child: TextButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGmailSyncCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _isGmailConnected ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isGmailConnected ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isGmailConnected ? Icons.mark_email_read_rounded : Icons.mail_lock_rounded,
            color: _isGmailConnected ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isGmailConnected ? 'Gmail Terhubung ($_gmailUser)' : 'Pencatatan Otomatis dari Gmail',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _isGmailConnected ? const Color(0xFF1E3A8A) : const Color(0xFF78350F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isGmailConnected ? 'Ketuk untuk sinkronisasi transaksi' : 'Hubungkan Gmail & sandi aplikasi Anda',
                  style: TextStyle(
                    fontSize: 10,
                    color: _isGmailConnected ? const Color(0xFF3B82F6) : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          if (_isSyncingGmail)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D4ED8)),
            )
          else if (_isGmailConnected) ...[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.sync_rounded, color: Color(0xFF1D4ED8)),
              onPressed: _syncEmailTransactions,
            ),
            const SizedBox(width: 12),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.link_off_rounded, color: Colors.red),
              onPressed: _disconnectGoogleAccount,
            ),
          ] else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _connectGoogleAccount,
              child: const Text('Hubungkan', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool showChevron,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF475569), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showChevron)
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 20,
      endIndent: 20,
      color: Color(0xFFF1F5F9),
    );
  }
}
