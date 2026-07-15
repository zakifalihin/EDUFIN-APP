import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controllers/finance_controller.dart';
import '../models/transaction_model.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({Key? key}) : super(key: key);

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _InsideModalBottomSheet extends StatefulWidget {
  final FinanceController controller;
  final VoidCallback onSuccess;
  final String? initialWalletId;

  const _InsideModalBottomSheet({
    Key? key,
    required this.controller,
    required this.onSuccess,
    this.initialWalletId,
  }) : super(key: key);

  @override
  State<_InsideModalBottomSheet> createState() => _InsideModalBottomSheetState();
}

class _InsideModalBottomSheetState extends State<_InsideModalBottomSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'MAKANAN';
  String _selectedType = 'expense';
  late List<Map<String, dynamic>> _wallets;
  late String _selectedWalletId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _wallets = widget.controller.getWalletsFromMetadata();
    // Default ke wallet terpilih/pertama, hindari virtual w_overall
    final initialId = widget.initialWalletId;
    if (initialId != null && initialId != 'w_overall' && _wallets.any((w) => w['id'] == initialId)) {
      _selectedWalletId = initialId;
    } else {
      _selectedWalletId = _wallets.isNotEmpty ? _wallets.first['id'] : '';
    }
  }

  void _submitData() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form tidak boleh kosong atau bernilai nol!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final error = await widget.controller.insertTransaction(
      title: title,
      amount: amount,
      category: _selectedCategory,
      type: _selectedType,
      walletId: _selectedWalletId,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 12,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFEE2E2), width: 2),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Transaksi Ditolak',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error.contains('tidak mencukupi') 
                        ? 'Saldo dompet tidak mencukupi untuk melakukan pengeluaran ini. Silakan gunakan dompet lain atau ubah nominal!'
                        : 'Gagal menyimpan transaksi: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Paham, Kembali',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 24, left: 24, right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tambah Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Nama Transaksi', hintText: 'Misal: Beli Nasi Goreng'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah Uang (Rp)', hintText: 'Misal: 20000'),
            ),
            const SizedBox(height: 16),
            const Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              items: ['MAKANAN', 'TRANSPORTASI', 'KESEHATAN', 'PENDIDIKAN', 'SOSIAL', 'LAINNYA'].map((String val) {
                return DropdownMenuItem<String>(value: val, child: Text(val));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 16),
            const Text('Potong dari Rekening / Dompet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            DropdownButton<String>(
              value: _selectedWalletId,
              isExpanded: true,
              items: _wallets.map((w) {
                return DropdownMenuItem<String>(
                  value: w['id'].toString(),
                  child: Text(w['name'].toString().toUpperCase()),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedWalletId = val!),
            ),
            const SizedBox(height: 16),
            const Text('Jenis Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              items: [
                {'val': 'expense', 'label': 'Pengeluaran (Expense)'},
                {'val': 'income', 'label': 'Pemasukan (Income)'}
              ].map((item) {
                return DropdownMenuItem<String>(value: item['val'], child: Text(item['label']!));
              }).toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                  : const Text('Simpan Transaksi', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceScreenState extends State<FinanceScreen> {
  final FinanceController _controller = FinanceController();
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  int _selectedWalletIndex = 0;
  DateTime _selectedTransactionDate = DateTime.now();
  Map<String, dynamic>? _loadedFinanceData;
  bool _isLoadingFinanceData = true;

  @override
  void initState() {
    super.initState();
    _loadData(showFullLoading: true);
  }

  Future<void> _loadData({bool showFullLoading = true}) async {
    if (showFullLoading) {
      setState(() {
        _isLoadingFinanceData = true;
      });
    }
    try {
      final data = await _controller.getFinanceDashboardData(filterDate: _selectedTransactionDate);
      if (mounted) {
        setState(() {
          _loadedFinanceData = data;
          _isLoadingFinanceData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingFinanceData = false;
        });
      }
    }
  }

  void _refreshData() {
    _selectedTransactionDate = DateTime.now();
    _loadData(showFullLoading: true);
  }

  void _showFinancialRecapSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FinancialRecapSheet(controller: _controller),
    );
  }

  void _showAddTransactionSheet(String activeWalletId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _InsideModalBottomSheet(
        controller: _controller,
        onSuccess: _refreshData,
        initialWalletId: activeWalletId,
      ),
    );
  }

  void _showAddWalletDialog() {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    final budgetCtrl = TextEditingController(text: '100000');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Dompet Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Dompet (Misal: GOPAY, MANDIRI):', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107)))),
                ),
                const SizedBox(height: 16),
                const Text('Saldo Awal (Rp):', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: balCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: 'Rp ', focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107)))),
                ),
                const SizedBox(height: 16),
                const Text('Limit Jajan Harian (Rp):', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: budgetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: 'Rp ', focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107)))),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final balance = double.tryParse(balCtrl.text.trim()) ?? 0;
                final limit = double.tryParse(budgetCtrl.text.trim()) ?? 100000;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama tidak boleh kosong!'), backgroundColor: Colors.red));
                  return;
                }

                final error = await _controller.addWallet(name: name, balance: balance, budgetLimit: limit);
                if (context.mounted) Navigator.pop(context);

                if (error == null) {
                  _refreshData();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107)),
              child: const Text('Tambah', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectCustomDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedTransactionDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

    if (picked != null) {
      setState(() {
        _selectedTransactionDate = picked;
      });
      _loadData(showFullLoading: false);
    }
  }

  String _getDateHeaderText() {
    final DateTime today = DateTime.now();
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    if (DateUtils.isSameDay(_selectedTransactionDate, today)) {
      return 'Recent Transactions (Hari Ini)';
    } else if (DateUtils.isSameDay(_selectedTransactionDate, yesterday)) {
      return 'Recent Transactions (Kemarin)';
    } else {
      return 'Recent Transactions (${DateFormat('dd MMM yyyy').format(_selectedTransactionDate)})';
    }
  }

  Widget _buildCalendarStrip() {
    final List<DateTime> dates = List.generate(7, (index) {
      return _selectedTransactionDate.subtract(Duration(days: 3 - index));
    });

    return Container(
      height: 70,
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final DateTime date = dates[index];
                final bool isSelected = DateUtils.isSameDay(date, _selectedTransactionDate);
                final String dayName = DateFormat('E').format(date).toUpperCase();
                final String dayNumber = DateFormat('d').format(date);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTransactionDate = date;
                    });
                    _loadData(showFullLoading: false);
                  },
                  child: Container(
                    width: 52,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white70 : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayNumber,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _selectCustomDate,
            child: Container(
              width: 52,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: Color(0xFF0F172A),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditWalletDialog(Map<String, dynamic> wallet) {
    final nameCtrl = TextEditingController(text: wallet['name']);
    final balCtrl = TextEditingController(text: wallet['balance'].toInt().toString());
    final budgetCtrl = TextEditingController(text: wallet['budget_limit'].toInt().toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Rekening Dompet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Dompet:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107)))),
                ),
                const SizedBox(height: 16),
                const Text('Saldo Saat Ini (Rp):', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: balCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: 'Rp ', focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107)))),
                ),
                const SizedBox(height: 16),
                const Text('Limit Jajan Harian (Rp):', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: budgetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: 'Rp ', focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107)))),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final balance = double.tryParse(balCtrl.text.trim()) ?? 0;
                final limit = double.tryParse(budgetCtrl.text.trim()) ?? 0;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama tidak boleh kosong!'), backgroundColor: Colors.red));
                  return;
                }

                final error = await _controller.updateWallet(
                  walletId: wallet['id'],
                  name: name,
                  balance: balance,
                  budgetLimit: limit,
                );
                if (context.mounted) Navigator.pop(context);

                if (error == null) {
                  _refreshData();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107)),
              child: const Text('Simpan', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteWallet(Map<String, dynamic> wallet) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Dompet', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Apakah Anda yakin ingin menghapus rekening "${wallet['name']}"? Semua saldo di dalamnya tidak akan terakumulasi lagi.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                final error = await _controller.deleteWallet(wallet['id']);
                if (context.mounted) Navigator.pop(context);

                if (error == null) {
                  setState(() {
                    _selectedWalletIndex = 0; // Kembalikan ke kartu pertama
                  });
                  _refreshData();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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

    if (_isLoadingFinanceData && _loadedFinanceData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
      );
    }

    if (_loadedFinanceData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Gagal memuat data keuangan'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadData(showFullLoading: true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final data = _loadedFinanceData!;
    final double totalBalanceCombined = (data['total_balance'] ?? 0.0).toDouble();
    final List<Map<String, dynamic>> wallets = List<Map<String, dynamic>>.from(data['wallets'] ?? []);
    final List<TransactionModel> transactions = data['transactions'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Builder(
          builder: (context) {

            // Reset selected index jika keluar dari batas list dompet (karena ada aksi hapus dompet)
            if (_selectedWalletIndex >= wallets.length) {
              _selectedWalletIndex = 0;
            }

            final bool isAddPage = _selectedWalletIndex == wallets.length;
            final activeWallet = isAddPage ? wallets.first : wallets[_selectedWalletIndex];



            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(profilePhoto),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('EDUFIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF64748B))),
                              SizedBox(height: 2),
                              Text('Keuangan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.bar_chart_rounded, size: 22, color: Color(0xFF0F172A)),
                              onPressed: _showFinancialRecapSheet,
                              tooltip: 'Rekap Keuangan',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.notifications_outlined, size: 22, color: Color(0xFF0F172A)),
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Info Total Saldo Gabungan (Kecil di atas carousel)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Saldo Gabungan', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text(currencyFormatter.format(totalBalanceCombined), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Carousel PageView Dompet Rekening
                  SizedBox(
                    height: 215,
                    child: PageView.builder(
                      itemCount: wallets.length + 1,
                      controller: PageController(viewportFraction: 0.88, initialPage: _selectedWalletIndex),
                      onPageChanged: (idx) {
                        setState(() {
                          _selectedWalletIndex = idx;
                        });
                      },
                      itemBuilder: (context, index) {
                        if (index == wallets.length) {
                          return _buildAddWalletCard();
                        }
                        final wallet = wallets[index];
                        final isSelected = index == _selectedWalletIndex;
                        return _buildWalletCard(wallet, isSelected);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(wallets.length + 1, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: index == _selectedWalletIndex ? 16 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: index == _selectedWalletIndex ? const Color(0xFF0F172A) : Colors.grey.shade300,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // 4. Header Recent Transactions & Calendar Strip
                  _buildCalendarStrip(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getDateHeaderText(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: isAddPage ? null : () => _showAddTransactionSheet(activeWallet['id']),
                        icon: const Icon(Icons.add, size: 16, color: Color(0xFFB48811)),
                        label: const Text('Add New', style: TextStyle(color: Color(0xFFB48811), fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 5. List Riwayat Transaksi
                  if (transactions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: const Center(child: Text('Belum ada riwayat transaksi masuk.', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildTransactionItem(transactions[index]),
                    ),

                  const SizedBox(height: 32),

                  // 6. Insight Pintar FinAI
                  _buildAiInsightCard(),

                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWalletCard(Map<String, dynamic> wallet, bool isSelected) {
    final String name = wallet['name'].toString().toUpperCase();
    final double balance = (wallet['balance'] ?? 0.0).toDouble();
    final double limit = (wallet['budget_limit'] ?? 100000.0).toDouble();
    final double spent = (wallet['spent_today'] ?? 0.0).toDouble();
    final double remaining = limit - spent;
    final double spentPercent = limit > 0 ? (spent / limit) : 0.0;
    final double percentLeft = limit > 0 ? (remaining / limit) * 100 : 0;

    // Pilih gradien warna berdasarkan nama dompet/provider agar menarik & premium
    List<Color> gradientColors = [const Color(0xFF0F172A), const Color(0xFF1E293B)]; // Default Dark Navy
    Color textColor = Colors.white;
    Color subtextColor = Colors.white70;
    Color subtext54Color = Colors.white54;
    Color dividerColor = Colors.white12;
    Color progressBgColor = Colors.white.withOpacity(0.15);

    if (name.contains('BCA')) {
      gradientColors = [const Color(0xFF003D7C), const Color(0xFF005EAF)]; // BCA Deep Blue
    } else if (name.contains('MANDIRI')) {
      gradientColors = [const Color(0xFF1C3F94), const Color(0xFF0F255C)]; // Mandiri Blue & Navy
    } else if (name.contains('BRI')) {
      gradientColors = [const Color(0xFF00529C), const Color(0xFF002C6C)]; // BRI Royal Blue
    } else if (name.contains('BNI')) {
      gradientColors = [const Color(0xFF005E6A), const Color(0xFF008D96)]; // BNI Turquoise Green
    } else if (name.contains('BSI') || name.contains('SYARIAH')) {
      gradientColors = [const Color(0xFF005F5F), const Color(0xFF008080)]; // BSI Teal
    } else if (name.contains('JAGO')) {
      gradientColors = [const Color(0xFFFFD54F), const Color(0xFFF57F17)]; // Jago Yellow/Orange
      textColor = const Color(0xFF0F172A);
      subtextColor = const Color(0xFF334155);
      subtext54Color = const Color(0xFF475569);
      dividerColor = Colors.black.withOpacity(0.08);
      progressBgColor = Colors.black.withOpacity(0.1);
    } else if (name.contains('GOPAY')) {
      gradientColors = [const Color(0xFF00AED6), const Color(0xFF0085A6)]; // GoPay Cyan
    } else if (name.contains('OVO')) {
      gradientColors = [const Color(0xFF4C2A86), const Color(0xFF2B1354)]; // OVO Purple
    } else if (name.contains('DANA')) {
      gradientColors = [const Color(0xFF118EEA), const Color(0xFF0B62A4)]; // DANA Sky Blue
    } else if (name.contains('SHOPEEPAY') || name.contains('SHOPEE')) {
      gradientColors = [const Color(0xFFEE4D2D), const Color(0xFFF57F20)]; // ShopeePay Orange
    } else if (name.contains('LINKAJA')) {
      gradientColors = [const Color(0xFFE61B2B), const Color(0xFF9F0D18)]; // LinkAja Red
    } else if (name.contains('CASH') || name.contains('TUNAI') || name.contains('DOMPET')) {
      gradientColors = [const Color(0xFF065F46), const Color(0xFF10B981)]; // Cash Green
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(color: textColor, fontSize: 13, letterSpacing: 1.2, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (wallet['id'] != 'w_overall')
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: subtextColor, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showEditWalletDialog(wallet),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: subtextColor, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _confirmDeleteWallet(wallet),
                    ),
                  ],
                )
            ],
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SALDO REKENING', style: TextStyle(color: subtext54Color, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text(
                currencyFormatter.format(balance),
                style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          Divider(color: dividerColor, height: 16, thickness: 1),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sisa Jajan: ${currencyFormatter.format(remaining.clamp(0.0, double.infinity))}',
                    style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${percentLeft.toInt()}% Sisa',
                    style: TextStyle(color: subtextColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 5,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: progressBgColor,
                  borderRadius: BorderRadius.circular(2.5),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (1.0 - spentPercent).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: spentPercent >= 0.9
                          ? Colors.redAccent
                          : spentPercent >= 0.75
                              ? Colors.orangeAccent
                              : const Color(0xFFFFC107),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terpakai: ${currencyFormatter.format(spent)}',
                    style: TextStyle(color: subtext54Color, fontSize: 9),
                  ),
                  Text(
                    'Limit: ${currencyFormatter.format(limit)}',
                    style: TextStyle(color: subtext54Color, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddWalletCard() {
    return GestureDetector(
      onTap: _showAddWalletDialog,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Color(0xFF0F172A), size: 36),
            SizedBox(height: 8),
            Text(
              'Tambah Dompet Baru',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'GoPay, Mandiri, BCA, Dana, dll.',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDeleteTransactionSheet(TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _EditDeleteTransactionBottomSheet(
        controller: _controller,
        transaction: tx,
        onSuccess: () {
          setState(() {});
          if (mounted) {
            _refreshData();
          }
        },
      ),
    );
  }

  Widget _buildTransactionItem(TransactionModel tx) {
    final cat = tx.category.toUpperCase();
    IconData iconData = Icons.receipt_long;
    if (cat == 'FOOD' || cat == 'MAKANAN') iconData = Icons.restaurant;
    if (cat == 'ACADEMIC' || cat == 'PENDIDIKAN') iconData = Icons.print;
    if (cat == 'SOCIAL' || cat == 'SOSIAL') iconData = Icons.local_cafe;
    if (cat == 'TRANSPORTASI' || cat == 'TRANSPORT') iconData = Icons.directions_car;
    if (cat == 'KESEHATAN' || cat == 'HEALTH') iconData = Icons.medical_services;
    if (tx.type == 'income') iconData = Icons.account_balance_wallet;

    String timeStr = DateFormat('hh:mm a').format(tx.createdAt);
    String sign = tx.type == 'expense' ? '-' : '+';
    Color amountColor = tx.type == 'expense' ? Colors.red.shade600 : Colors.green.shade600;
    Color iconBgColor = tx.type == 'expense' ? Colors.red.shade50 : Colors.green.shade50;

    return GestureDetector(
      onTap: () => _showEditDeleteTransactionSheet(tx),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(16)),
              child: Icon(iconData, color: amountColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final today = DateTime.now();
                      final yesterday = today.subtract(const Duration(days: 1));
                      String dateLabel = '';
                      if (DateUtils.isSameDay(tx.createdAt, today)) {
                        dateLabel = 'Today';
                      } else if (DateUtils.isSameDay(tx.createdAt, yesterday)) {
                        dateLabel = 'Yesterday';
                      } else {
                        dateLabel = DateFormat('dd MMM yyyy').format(tx.createdAt);
                      }
                      return Text('$dateLabel, $timeStr', style: const TextStyle(color: Colors.grey, fontSize: 12));
                    },
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$sign ${currencyFormatter.format(tx.amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: amountColor)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: Text(tx.category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiInsightCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0).withOpacity(0.5), borderRadius: BorderRadius.circular(24)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFFB48811)),
              SizedBox(width: 8),
              Text('AI Financial Insight', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 16),
          Text('"You\'ve spent 20% more on coffee this week compared to your average. Switching to the campus library coffee could save you Rp 150.000 monthly."', style: TextStyle(color: Color(0xFF475569), fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

class _FinancialRecapSheet extends StatefulWidget {
  final FinanceController controller;

  const _FinancialRecapSheet({Key? key, required this.controller}) : super(key: key);

  @override
  State<_FinancialRecapSheet> createState() => _FinancialRecapSheetState();
}

class _FinancialRecapSheetState extends State<_FinancialRecapSheet> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = true;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  Map<String, double> _categoryExpenses = {};
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchRecap();
  }



  void _fetchRecap() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.controller.getFinancialRecap(startDate: _startDate, endDate: _endDate);
      if (mounted) {
        setState(() {
          _totalIncome = (res['total_income'] ?? 0.0).toDouble();
          _totalExpense = (res['total_expense'] ?? 0.0).toDouble();
          _categoryExpenses = Map<String, double>.from(res['category_expenses'] ?? {});
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _exportExcel() async {
    setState(() => _isLoading = true);
    final wallets = widget.controller.getWalletsFromMetadata();
    final err = await widget.controller.exportToExcel(startDate: _startDate, endDate: _endDate, wallets: wallets);
    if (mounted) setState(() => _isLoading = false);

    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export Excel: $err'), backgroundColor: Colors.red),
      );
    }
  }

  void _exportPdf() async {
    setState(() => _isLoading = true);
    final wallets = widget.controller.getWalletsFromMetadata();
    final err = await widget.controller.exportToPdf(startDate: _startDate, endDate: _endDate, wallets: wallets);
    if (mounted) setState(() => _isLoading = false);

    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export PDF: $err'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
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

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchRecap();
    }
  }

  Widget _buildDateRangeSelector() {
    final rangeText = '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}';
    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded, color: Color(0xFFB48811), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rentang Tanggal Rekap (Ketuk untuk Mengubah)', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    rangeText,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rangeTextStr = '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}';
    final totalTurnover = _totalIncome + _totalExpense;
    final double incomePercent = totalTurnover > 0 ? _totalIncome / totalTurnover : 0.5;
    final double expensePercent = totalTurnover > 0 ? _totalExpense / totalTurnover : 0.5;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Rekap Keuangan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.table_view_rounded, color: Colors.green),
                    tooltip: 'Export Excel (CSV)',
                    onPressed: _exportExcel,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                    tooltip: 'Export PDF',
                    onPressed: _exportPdf,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),

          _buildDateRangeSelector(),
          const SizedBox(height: 20),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'Pemasukan',
                                amount: _totalIncome,
                                icon: Icons.arrow_downward_rounded,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'Pengeluaran',
                                amount: _totalExpense,
                                icon: Icons.arrow_upward_rounded,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Perbandingan Rasio',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Pemasukan vs Pengeluaran ($rangeTextStr)',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.grey.shade100,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Row(
                                    children: [
                                      if (_totalIncome > 0)
                                        Expanded(
                                          flex: (incomePercent * 100).toInt().clamp(1, 99),
                                          child: Container(color: Colors.green),
                                        ),
                                      if (_totalExpense > 0)
                                        Expanded(
                                          flex: (expensePercent * 100).toInt().clamp(1, 99),
                                          child: Container(color: Colors.red),
                                        ),
                                      if (_totalIncome == 0 && _totalExpense == 0)
                                        Expanded(child: Container(color: Colors.grey.shade300)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Pemasukan (${(incomePercent * 100).toInt()}%Sisa)',
                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Pengeluaran (${(expensePercent * 100).toInt()}%Spent)',
                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'Rincian Pengeluaran Kategori',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 12),
                        if (_categoryExpenses.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Center(
                              child: Text(
                                'Tidak ada pengeluaran pada periode ini.',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          ..._categoryExpenses.entries.map((entry) {
                            final categoryName = entry.key;
                            final amount = entry.value;
                            final ratio = _totalExpense > 0 ? amount / _totalExpense : 0.0;

                            Color barColor = const Color(0xFF0F172A);
                            if (categoryName == 'MAKANAN') barColor = Colors.orange;
                            if (categoryName == 'TRANSPORTASI') barColor = Colors.blue;
                            if (categoryName == 'KESEHATAN') barColor = Colors.teal;
                            if (categoryName == 'PENDIDIKAN') barColor = Colors.purple;
                            if (categoryName == 'SOSIAL') barColor = Colors.pink;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        categoryName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        currencyFormatter.format(amount),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Stack(
                                    children: [
                                      Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: ratio.clamp(0.0, 1.0),
                                        child: Container(
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: barColor,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${(ratio * 100).toInt()}% dari total pengeluaran',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currencyFormatter.format(amount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditDeleteTransactionBottomSheet extends StatefulWidget {
  final FinanceController controller;
  final TransactionModel transaction;
  final VoidCallback onSuccess;

  const _EditDeleteTransactionBottomSheet({
    Key? key,
    required this.controller,
    required this.transaction,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<_EditDeleteTransactionBottomSheet> createState() => _EditDeleteTransactionBottomSheetState();
}

class _EditDeleteTransactionBottomSheetState extends State<_EditDeleteTransactionBottomSheet> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late String _selectedCategory;
  late String _selectedType;
  late List<Map<String, dynamic>> _wallets;
  late String _selectedWalletId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    String cleanTitle = widget.transaction.title;
    if (cleanTitle.startsWith('[') && cleanTitle.contains(']')) {
      cleanTitle = cleanTitle.substring(cleanTitle.indexOf(']') + 1).trim();
    }

    _titleController = TextEditingController(text: cleanTitle);
    _amountController = TextEditingController(text: widget.transaction.amount.toStringAsFixed(0));
    _selectedCategory = widget.transaction.category;
    _selectedType = widget.transaction.type;
    
    _wallets = widget.controller.getWalletsFromMetadata();
    
    String? walletName;
    if (widget.transaction.title.startsWith('[') && widget.transaction.title.contains(']')) {
      walletName = widget.transaction.title.substring(1, widget.transaction.title.indexOf(']')).trim().toUpperCase();
    }
    
    final wIdx = _wallets.indexWhere((w) => w['name'].toString().toUpperCase() == walletName);
    if (wIdx != -1) {
      _selectedWalletId = _wallets[wIdx]['id'];
    } else {
      _selectedWalletId = _wallets.isNotEmpty ? _wallets.first['id'] : '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submitUpdate() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form tidak boleh kosong atau bernilai nol!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final error = await widget.controller.updateTransaction(
      oldTx: widget.transaction,
      newTitle: title,
      newAmount: amount,
      newCategory: _selectedCategory,
      newType: _selectedType,
      newWalletId: _selectedWalletId,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 12,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFEE2E2), width: 2),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Transaksi Ditolak',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error.contains('tidak mencukupi') 
                        ? 'Saldo dompet tidak mencukupi untuk melakukan pengeluaran ini. Silakan gunakan dompet lain atau ubah nominal!'
                        : 'Gagal mengubah transaksi: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Paham, Kembali',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
  }

  void _deleteTx() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin menghapus transaksi ini? Saldo dompet akan disesuaikan kembali.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final error = await widget.controller.deleteTransaction(widget.transaction);
    setState(() => _isLoading = false);

    if (error == null) {
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $error'), backgroundColor: Colors.red),
        );
      }
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Detail & Edit Transaksi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Judul Transaksi',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Jumlah Uang (Rupiah)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Dompet',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            value: _selectedWalletId,
            items: _wallets
                .map((w) => DropdownMenuItem<String>(
                      value: w['id'],
                      child: Text(w['name']),
                    ))
                .toList(),
            onChanged: (val) => setState(() => _selectedWalletId = val ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Jenis Transaksi',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            value: _selectedType,
            items: const [
              DropdownMenuItem(value: 'income', child: Text('Pemasukan (Income)')),
              DropdownMenuItem(value: 'expense', child: Text('Pengeluaran (Expense)')),
            ],
            onChanged: (val) => setState(() => _selectedType = val ?? 'expense'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            value: _selectedCategory,
            items: const [
              DropdownMenuItem(value: 'MAKANAN', child: Text('Makanan & Minuman')),
              DropdownMenuItem(value: 'PENDIDIKAN', child: Text('Pendidikan / Kuliah')),
              DropdownMenuItem(value: 'SOSIAL', child: Text('Sosial / Hiburan')),
              DropdownMenuItem(value: 'TRANSPORTASI', child: Text('Transportasi')),
              DropdownMenuItem(value: 'KESEHATAN', child: Text('Kesehatan')),
              DropdownMenuItem(value: 'LAINNYA', child: Text('Lainnya')),
            ],
            onChanged: (val) => setState(() => _selectedCategory = val ?? 'LAINNYA'),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          else ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submitUpdate,
              child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade400),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _deleteTx,
              icon: Icon(Icons.delete_forever, color: Colors.red.shade600),
              label: Text('Hapus Transaksi', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold)),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}