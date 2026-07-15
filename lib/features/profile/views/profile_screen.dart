import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  String _userName = 'Pengguna EduFin';
  String _profilePhoto = '';
  String _institute = 'Global Institute of Technology & Finance';

  // Gmail Sync State variables
  String _gmailUser = '';
  bool _isGmailConnected = false;
  bool _isSyncingGmail = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final metadata = user.userMetadata ?? {};
        _userName = metadata['full_name']?.toString() ?? user.email?.split('@')[0] ?? 'Pengguna EduFin';
        _profilePhoto = metadata['avatar_url']?.toString() ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_userName)}&background=0F172A&color=fff&size=150&bold=true';
        _institute = metadata['institute']?.toString() ?? 'Global Institute of Technology & Finance';

        // Get Gmail status
        _gmailUser = metadata['gmail_user']?.toString() ?? '';
        _isGmailConnected = metadata['gmail_connected'] == true && _gmailUser.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Error loading profile info: $e');
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _openSheet(Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => sheet,
    );
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
                        onTap: () => _openSheet(
                          _PersonalInformationSheet(
                            supabase: _supabase,
                            onSaved: _loadProfileData,
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        icon: Icons.school_outlined,
                        title: 'Academic Settings',
                        subtitle: 'Syllabus, GPA tracking',
                        showChevron: true,
                        onTap: () => _openSheet(
                          _AcademicSettingsSheet(supabase: _supabase),
                        ),
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        icon: Icons.security_rounded,
                        title: 'Security & Privacy',
                        showChevron: true,
                        onTap: () => _openSheet(
                          _SecurityPrivacySheet(supabase: _supabase),
                        ),
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        showChevron: true,
                        onTap: () => _openSheet(
                          _NotificationsSheet(supabase: _supabase),
                        ),
                      ),
                      _buildDivider(),
                      _buildMenuOption(
                        icon: Icons.help_outline_rounded,
                        title: 'Help Center',
                        showChevron: true,
                        onTap: () => _openSheet(const _HelpCenterSheet()),
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
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
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

class _PersonalInformationSheet extends StatefulWidget {
  final SupabaseClient supabase;
  final VoidCallback onSaved;

  const _PersonalInformationSheet({
    Key? key,
    required this.supabase,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<_PersonalInformationSheet> createState() => _PersonalInformationSheetState();
}

class _PersonalInformationSheetState extends State<_PersonalInformationSheet> {
  late TextEditingController _nameController;
  late TextEditingController _instituteController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = widget.supabase.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    _nameController = TextEditingController(text: metadata['full_name']?.toString() ?? user?.email?.split('@')[0] ?? '');
    _instituteController = TextEditingController(text: metadata['institute']?.toString() ?? 'Global Institute of Technology & Finance');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instituteController.dispose();
    super.dispose();
  }

  void _saveInfo() async {
    final name = _nameController.text.trim();
    final institute = _instituteController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await widget.supabase.auth.updateUser(
        UserAttributes(data: {
          'full_name': name,
          'institute': institute,
        })
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informasi pribadi berhasil disimpan!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Personal Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nama Lengkap',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instituteController,
            decoration: InputDecoration(
              labelText: 'Nama Kampus/Institusi',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saveInfo,
                  child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _AcademicSettingsSheet extends StatefulWidget {
  final SupabaseClient supabase;

  const _AcademicSettingsSheet({Key? key, required this.supabase}) : super(key: key);

  @override
  State<_AcademicSettingsSheet> createState() => _AcademicSettingsSheetState();
}

class _AcademicSettingsSheetState extends State<_AcademicSettingsSheet> {
  late TextEditingController _gpaController;
  late TextEditingController _targetGpaController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = widget.supabase.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    _gpaController = TextEditingController(text: metadata['current_gpa']?.toString() ?? '3.50');
    _targetGpaController = TextEditingController(text: metadata['target_gpa']?.toString() ?? '4.00');
  }

  @override
  void dispose() {
    _gpaController.dispose();
    _targetGpaController.dispose();
    super.dispose();
  }

  void _saveAcademicSettings() async {
    final gpa = double.tryParse(_gpaController.text) ?? 0.0;
    final target = double.tryParse(_targetGpaController.text) ?? 0.0;

    setState(() => _isLoading = true);
    try {
      await widget.supabase.auth.updateUser(
        UserAttributes(data: {
          'current_gpa': gpa,
          'target_gpa': target,
        })
      );
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan akademik berhasil disimpan!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Academic Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 20),
          TextField(
            controller: _gpaController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'IPK Sekarang (Current GPA)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetGpaController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Target IPK (Target GPA)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saveAcademicSettings,
                  child: const Text('Simpan Setelan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SecurityPrivacySheet extends StatefulWidget {
  final SupabaseClient supabase;

  const _SecurityPrivacySheet({Key? key, required this.supabase}) : super(key: key);

  @override
  State<_SecurityPrivacySheet> createState() => _SecurityPrivacySheetState();
}

class _SecurityPrivacySheetState extends State<_SecurityPrivacySheet> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _updatePassword() async {
    final password = _passwordController.text.trim();
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password minimal harus 6 karakter!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.supabase.auth.updateUser(UserAttributes(password: password));
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diperbarui!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui password: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Security & Privacy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password Baru',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _updatePassword,
                  child: const Text('Perbarui Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _NotificationsSheet extends StatefulWidget {
  final SupabaseClient supabase;

  const _NotificationsSheet({Key? key, required this.supabase}) : super(key: key);

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool _academicReminders = true;
  bool _budgetAlerts = true;
  bool _weeklySummary = false;

  @override
  void initState() {
    super.initState();
    final metadata = widget.supabase.auth.currentUser?.userMetadata ?? {};
    _academicReminders = metadata['notify_academic'] ?? true;
    _budgetAlerts = metadata['notify_budget'] ?? true;
    _weeklySummary = metadata['notify_weekly'] ?? false;
  }

  void _saveNotificationSettings() async {
    try {
      await widget.supabase.auth.updateUser(
        UserAttributes(data: {
          'notify_academic': _academicReminders,
          'notify_budget': _budgetAlerts,
          'notify_weekly': _weeklySummary,
        })
      );
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setelan notifikasi disimpan!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan setelan: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Notifications Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('Pengingat Jadwal Kuliah', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Kirim notifikasi untuk kelas dan tugas kuliah terdekat'),
            value: _academicReminders,
            activeColor: const Color(0xFF0F172A),
            onChanged: (val) => setState(() => _academicReminders = val),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Peringatan Anggaran (Budget)', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Peringatan jika pengeluaran melebihi batas anggaran dompet'),
            value: _budgetAlerts,
            activeColor: const Color(0xFF0F172A),
            onChanged: (val) => setState(() => _budgetAlerts = val),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Ringkasan Mingguan', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Laporan rekapitulasi keuangan mingguan otomatis'),
            value: _weeklySummary,
            activeColor: const Color(0xFF0F172A),
            onChanged: (val) => setState(() => _weeklySummary = val),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _saveNotificationSettings,
            child: const Text('Simpan Setelan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _HelpCenterSheet extends StatelessWidget {
  const _HelpCenterSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Help Center', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFaqItem(
            question: 'Bagaimana cara menghubungkan email Gmail?',
            answer: 'Pergi ke menu Profile, tekan Hubungkan Gmail, lalu login aman dengan Google OAuth 2.0 1-klik.',
          ),
          _buildFaqItem(
            question: 'Mengapa saldo bank saya tidak boleh minus?',
            answer: 'Saldo bank merepresentasikan uang asli Anda sehingga tidak boleh negatif. Gunakan anggaran jajan jika ingin mencatat anggaran minus.',
          ),
          _buildFaqItem(
            question: 'Bagaimana cara menambahkan jadwal kuliah baru?',
            answer: 'Pergi ke tab Academic, scroll ke bawah, lalu tekan tombol + Add New di sebelah judul Academic Schedule.',
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Layanan dukungan pelanggan dihubungi via email: support@edufin.com')),
              );
            },
            icon: const Icon(Icons.mail, color: Colors.white),
            label: const Text('Hubungi Support Kami', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(answer, style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5)),
        ),
      ],
    );
  }
}
