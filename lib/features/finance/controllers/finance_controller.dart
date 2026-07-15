import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:enough_mail/enough_mail.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:edufin/core/utils/email_parser_helper.dart';
import '../models/transaction_model.dart';

class FinanceController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // HELPER: Mengambil list dompet dari Auth User Metadata
  List<Map<String, dynamic>> getWalletsFromMetadata() {
    final user = _supabase.auth.currentUser;
    final walletsObj = user?.userMetadata?['wallets'];
    if (walletsObj != null) {
      return List<Map<String, dynamic>>.from(
        (walletsObj as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }
    // Default wallet jika metadata masih kosong
    return [
      {
        'id': 'w_default',
        'name': 'DOMPET UTAMA',
        'balance': 1000000.0,
        'budget_limit': 100000.0,
      }
    ];
  }

  // HELPER: Menyimpan list dompet ke Auth User Metadata
  Future<void> saveWalletsToMetadata(List<Map<String, dynamic>> wallets) async {
    await _supabase.auth.updateUser(
      UserAttributes(data: {'wallets': wallets}),
    );
  }

  // HELPER: Sinkronisasi jumlah saldo semua dompet ke tabel wallets di database
  Future<void> syncDatabaseWalletBalance(List<Map<String, dynamic>> wallets) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      double totalSum = 0.0;
      for (var w in wallets) {
        totalSum += (w['balance'] ?? 0.0).toDouble();
      }

      // Cari baris di tabel wallets
      final walletRes = await _supabase
          .from('wallets')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (walletRes == null) {
        // Jika belum ada, masukkan baris baru
        await _supabase.from('wallets').insert({
          'user_id': userId,
          'balance': totalSum,
        });
      } else {
        // Jika sudah ada, update
        await _supabase
            .from('wallets')
            .update({'balance': totalSum})
            .eq('user_id', userId);
      }
    } catch (e) {
      print('Error sync wallet balance: $e');
    }
  }

  // Fungsi mengambil data Dashboard Keuangan (mendukung Multi-Rekening)
  Future<Map<String, dynamic>> getFinanceDashboardData({DateTime? filterDate}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User belum login');

      // 1. Ambil list dompet dari metadata
      final List<Map<String, dynamic>> wallets = getWalletsFromMetadata();

      // Hitung total saldo gabungan seluruh rekening
      double totalBalance = 0.0;
      for (var w in wallets) {
        totalBalance += (w['balance'] ?? 0.0).toDouble();
      }

      // 2. Hitung spent harian untuk masing-masing dompet hari ini
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

      // Ambil seluruh transaksi hari ini
      final txTodayRes = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .eq('type', 'expense')
          .gte('created_at', startOfDay);

      final List<dynamic> txToday = txTodayRes as List;

      // Lampirkan 'spent_today' ke tiap dompet berdasarkan awalan prefix [NAMA_DOMPET] di judul
      final List<Map<String, dynamic>> enrichedWallets = wallets.map((w) {
        final walletName = w['name'].toString().toUpperCase();
        final prefix = '[$walletName]';

        double spentAmount = 0.0;
        for (var tx in txToday) {
          final String title = tx['title'] ?? '';
          if (title.toUpperCase().startsWith(prefix)) {
            spentAmount += (tx['amount'] ?? 0.0).toDouble();
          } else if (walletName == 'DOMPET UTAMA' && !title.startsWith('[')) {
            // Fallback untuk transaksi lama tanpa prefix masuk ke DOMPET UTAMA
            spentAmount += (tx['amount'] ?? 0.0).toDouble();
          }
        }

        return {
          ...w,
          'spent_today': spentAmount,
        };
      }).toList();

      // 3. Ambil Transaksi untuk tanggal terpilih
      final DateTime date = filterDate ?? DateTime.now();
      final DateTime startOfDate = DateTime(date.year, date.month, date.day);
      final DateTime endOfDate = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
      final String startStr = startOfDate.toUtc().toIso8601String();
      final String endStr = endOfDate.toUtc().toIso8601String();

      final txRes = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .gte('created_at', startStr)
          .lte('created_at', endStr)
          .order('created_at', ascending: false);
          
      // Bersihkan prefix dompet dari judul saat ditampilkan di UI
      final List<TransactionModel> transactions = (txRes as List).map((e) {
        final Map<String, dynamic> rawJson = Map<String, dynamic>.from(e);
        String title = rawJson['title'] ?? '';
        if (title.startsWith('[')) {
          final closeBracketIdx = title.indexOf(']');
          if (closeBracketIdx != -1 && title.length > closeBracketIdx + 1) {
            title = title.substring(closeBracketIdx + 1).trim();
          }
        }
        rawJson['title'] = title;
        return TransactionModel.fromJson(rawJson);
      }).toList();

      return {
        'total_balance': totalBalance,
        'wallets': enrichedWallets,
        'transactions': transactions,
      };
    } catch (e) {
      print('Error di Finance Controller: $e');
      rethrow;
    }
  }

  // Fungsi untuk memasukkan transaksi baru dikaitkan dengan dompet tertentu
  Future<String?> insertTransaction({
    required String title,
    required double amount,
    required String category,
    required String type,
    required String walletId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'User belum login';

      // 1. Ambil & update saldo dompet di metadata
      final List<Map<String, dynamic>> wallets = getWalletsFromMetadata();
      final idx = wallets.indexWhere((w) => w['id'] == walletId);
      if (idx == -1) return 'Dompet tidak ditemukan';

      final wallet = wallets[idx];
      final double currentBalance = (wallet['balance'] ?? 0.0).toDouble();
      final String walletName = wallet['name'].toString().toUpperCase();

      if (type == 'expense') {
        if (currentBalance - amount < 0) {
          return 'Saldo dompet $walletName tidak mencukupi untuk pengeluaran ini!';
        }
        wallets[idx]['balance'] = currentBalance - amount;
      } else {
        wallets[idx]['balance'] = currentBalance + amount;
      }

      // 2. Simpan metadata dompet terupdate
      await saveWalletsToMetadata(wallets);

      // 3. Sinkronisasikan total saldo baru ke tabel database wallets
      await syncDatabaseWalletBalance(wallets);

      // 4. Masukkan baris transaksi dengan menyematkan prefix dompet di judul
      final formattedTitle = '[$walletName] $title';
      await _supabase.from('transactions').insert({
        'user_id': userId,
        'title': formattedTitle,
        'amount': amount,
        'category': category,
        'type': type,
      });

      return null;
    } catch (e) {
      print('Error insert transaction: $e');
      return e.toString();
    }
  }

  String? _getWalletNameFromTitle(String title) {
    if (title.startsWith('[') && title.contains(']')) {
      return title.substring(1, title.indexOf(']')).trim().toUpperCase();
    }
    return null;
  }

  Future<String?> deleteTransaction(TransactionModel tx) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'User belum login';

      final walletName = _getWalletNameFromTitle(tx.title);
      if (walletName != null) {
        final wallets = getWalletsFromMetadata();
        final idx = wallets.indexWhere((w) => w['name'].toString().toUpperCase() == walletName);
        if (idx != -1) {
          final double balance = (wallets[idx]['balance'] ?? 0.0).toDouble();
          if (tx.type == 'expense') {
            wallets[idx]['balance'] = balance + tx.amount;
          } else {
            wallets[idx]['balance'] = balance - tx.amount;
          }
          await saveWalletsToMetadata(wallets);
          await syncDatabaseWalletBalance(wallets);
        }
      }

      await _supabase.from('transactions').delete().eq('id', tx.id);
      return null;
    } catch (e) {
      print('Error delete transaction: $e');
      return e.toString();
    }
  }

  Future<String?> updateTransaction({
    required TransactionModel oldTx,
    required String newTitle,
    required double newAmount,
    required String newCategory,
    required String newType,
    required String newWalletId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'User belum login';

      final oldWalletName = _getWalletNameFromTitle(oldTx.title);
      final wallets = getWalletsFromMetadata();
      
      if (oldWalletName != null) {
        final idx = wallets.indexWhere((w) => w['name'].toString().toUpperCase() == oldWalletName);
        if (idx != -1) {
          final double balance = (wallets[idx]['balance'] ?? 0.0).toDouble();
          if (oldTx.type == 'expense') {
            wallets[idx]['balance'] = balance + oldTx.amount;
          } else {
            wallets[idx]['balance'] = balance - oldTx.amount;
          }
        }
      }

      final newIdx = wallets.indexWhere((w) => w['id'] == newWalletId);
      if (newIdx == -1) return 'Dompet baru tidak ditemukan';
      
      final newWallet = wallets[newIdx];
      final double currentBalance = (newWallet['balance'] ?? 0.0).toDouble();
      final String newWalletName = newWallet['name'].toString().toUpperCase();

      if (newType == 'expense') {
        if (currentBalance - newAmount < 0) {
          return 'Saldo dompet $newWalletName tidak mencukupi untuk pengeluaran ini!';
        }
        wallets[newIdx]['balance'] = currentBalance - newAmount;
      } else {
        wallets[newIdx]['balance'] = currentBalance + newAmount;
      }

      await saveWalletsToMetadata(wallets);
      await syncDatabaseWalletBalance(wallets);

      final formattedTitle = '[$newWalletName] $newTitle';
      await _supabase.from('transactions').update({
        'title': formattedTitle,
        'amount': newAmount,
        'category': newCategory,
        'type': newType,
      }).eq('id', oldTx.id);

      return null;
    } catch (e) {
      print('Error update transaction: $e');
      return e.toString();
    }
  }

  // CRUD DOMPET 1: Tambah Dompet Baru
  Future<String?> addWallet({
    required String name,
    required double balance,
    required double budgetLimit,
  }) async {
    try {
      final List<Map<String, dynamic>> wallets = getWalletsFromMetadata();

      // Cek duplikasi nama
      final upperName = name.trim().toUpperCase();
      if (wallets.any((w) => w['name'].toString().toUpperCase() == upperName)) {
        return 'Nama dompet sudah terdaftar!';
      }

      final newWallet = {
        'id': 'w_${DateTime.now().millisecondsSinceEpoch}',
        'name': upperName,
        'balance': balance,
        'budget_limit': budgetLimit,
      };

      wallets.add(newWallet);
      await saveWalletsToMetadata(wallets);
      await syncDatabaseWalletBalance(wallets);

      return null;
    } catch (e) {
      print('Error add wallet: $e');
      return e.toString();
    }
  }

  // CRUD DOMPET 2: Update Dompet (Nama, Saldo, dan Budget Limit)
  Future<String?> updateWallet({
    required String walletId,
    required String name,
    required double balance,
    required double budgetLimit,
  }) async {
    try {
      final List<Map<String, dynamic>> wallets = getWalletsFromMetadata();
      final idx = wallets.indexWhere((w) => w['id'] == walletId);
      if (idx == -1) return 'Dompet tidak ditemukan';

      final upperName = name.trim().toUpperCase();
      // Cek duplikasi nama (abaikan milik sendiri)
      if (wallets.any((w) => w['id'] != walletId && w['name'].toString().toUpperCase() == upperName)) {
        return 'Nama dompet sudah terdaftar!';
      }

      wallets[idx]['name'] = upperName;
      wallets[idx]['balance'] = balance;
      wallets[idx]['budget_limit'] = budgetLimit;

      await saveWalletsToMetadata(wallets);
      await syncDatabaseWalletBalance(wallets);

      return null;
    } catch (e) {
      print('Error update wallet: $e');
      return e.toString();
    }
  }

  // CRUD DOMPET 3: Hapus Dompet
  Future<String?> deleteWallet(String walletId) async {
    try {
      final List<Map<String, dynamic>> wallets = getWalletsFromMetadata();
      if (wallets.length <= 1) {
        return 'Anda harus menyisakan minimal satu dompet utama!';
      }

      final idx = wallets.indexWhere((w) => w['id'] == walletId);
      if (idx == -1) return 'Dompet tidak ditemukan';

      wallets.removeAt(idx);
      await saveWalletsToMetadata(wallets);
      await syncDatabaseWalletBalance(wallets);

      return null;
    } catch (e) {
      print('Error delete wallet: $e');
      return e.toString();
    }
  }

  // Fungsi mengambil rekap keuangan berdasarkan rentang tanggal kustom
  Future<Map<String, dynamic>> getFinancialRecap({required DateTime startDate, required DateTime endDate}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User belum login');

      final startStr = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0).toUtc().toIso8601String();
      final endStr = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999).toUtc().toIso8601String();

      final txRes = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .gte('created_at', startStr)
          .lte('created_at', endStr);

      double totalIncome = 0.0;
      double totalExpense = 0.0;
      Map<String, double> categoryExpenses = {};

      for (var tx in txRes as List) {
        final double amount = (tx['amount'] ?? 0.0).toDouble();
        final String type = tx['type'] ?? 'expense';
        String category = tx['category']?.toString().toUpperCase() ?? 'LAINNYA';

        // Map old English categories to Indonesian for uniform recap
        if (category == 'FOOD') category = 'MAKANAN';
        if (category == 'ACADEMIC') category = 'PENDIDIKAN';
        if (category == 'SOCIAL') category = 'SOSIAL';
        if (category == 'HEALTH') category = 'KESEHATAN';
        if (category == 'TRANSPORT') category = 'TRANSPORTASI';
        if (category == 'OTHER') category = 'LAINNYA';

        if (type == 'income') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
          categoryExpenses[category] = (categoryExpenses[category] ?? 0.0) + amount;
        }
      }

      return {
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'category_expenses': categoryExpenses,
      };
    } catch (e) {
      print('Error di getFinancialRecap: $e');
      rethrow;
    }
  }

  // Fungsi mengunduh/share laporan Rekap Keuangan dalam bentuk CSV (Excel) berdasarkan rentang tanggal
  Future<String?> exportToExcel({required DateTime startDate, required DateTime endDate, required List<Map<String, dynamic>> wallets}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'User belum login';

      final startStr = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0).toUtc().toIso8601String();
      final endStr = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999).toUtc().toIso8601String();

      final txRes = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .gte('created_at', startStr)
          .lte('created_at', endStr)
          .order('created_at', ascending: false);

      final rangeStr = '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
      final buffer = StringBuffer();
      buffer.write('\uFEFF');
      buffer.writeln('REKAP KEUANGAN - EDUFIN');
      buffer.writeln('Rentang Tanggal: $rangeStr');
      buffer.writeln();
      buffer.writeln('Tanggal,Nama Transaksi,Kategori,Tipe,Jumlah (Rp),Rekening/Dompet');

      for (var tx in txRes as List) {
        final date = DateTime.parse(tx['created_at'].toString()).toLocal();
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(date);
        final String title = tx['title']?.toString() ?? '';
        final String category = tx['category']?.toString() ?? 'LAINNYA';
        final String type = tx['type'] == 'income' ? 'Pemasukan' : 'Pengeluaran';
        final amount = (tx['amount'] ?? 0).toInt();

        String walletName = 'Dompet Utama';
        if (title.startsWith('[')) {
          final closeBracketIdx = title.indexOf(']');
          if (closeBracketIdx != -1) {
            walletName = title.substring(1, closeBracketIdx).toUpperCase();
          }
        }

        String cleanTitle = title;
        if (title.startsWith('[')) {
          final closeBracketIdx = title.indexOf(']');
          if (closeBracketIdx != -1 && title.length > closeBracketIdx + 1) {
            cleanTitle = title.substring(closeBracketIdx + 1).trim();
          }
        }

        final safeTitle = cleanTitle.replaceAll('"', '""').replaceAll(',', ';');
        final safeCat = category.replaceAll('"', '""').replaceAll(',', ';');

        buffer.writeln('"$dateStr","$safeTitle","$safeCat","$type",$amount,"$walletName"');
      }

      final tempDir = await getTemporaryDirectory();
      final dateSuffix = '${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}';
      final file = File('${tempDir.path}/edufin_rekap_${dateSuffix}.csv');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles([XFile(file.path)], subject: 'Rekap Keuangan CSV');
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Fungsi mengunduh/share laporan Rekap Keuangan dalam bentuk PDF berdasarkan rentang tanggal
  Future<String?> exportToPdf({required DateTime startDate, required DateTime endDate, required List<Map<String, dynamic>> wallets}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'User belum login';

      final startStr = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0).toUtc().toIso8601String();
      final endStr = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999).toUtc().toIso8601String();

      final txRes = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .gte('created_at', startStr)
          .lte('created_at', endStr)
          .order('created_at', ascending: false);

      double totalIncome = 0.0;
      double totalExpense = 0.0;
      final List<Map<String, dynamic>> items = [];

      for (var tx in txRes as List) {
        final double amount = (tx['amount'] ?? 0.0).toDouble();
        final String type = tx['type'] ?? 'expense';
        final String title = tx['title'] ?? '';
        final String category = tx['category']?.toString().toUpperCase() ?? 'LAINNYA';
        final date = DateTime.parse(tx['created_at'].toString()).toLocal();

        if (type == 'income') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
        }

        String cleanTitle = title;
        if (title.startsWith('[')) {
          final closeBracketIdx = title.indexOf(']');
          if (closeBracketIdx != -1 && title.length > closeBracketIdx + 1) {
            cleanTitle = title.substring(closeBracketIdx + 1).trim();
          }
        }

        items.add({
          'date': DateFormat('dd MMM yyyy HH:mm').format(date),
          'title': cleanTitle,
          'category': category,
          'type': type == 'income' ? 'Masuk' : 'Keluar',
          'amount': amount,
        });
      }

      final pdf = pw.Document();
      final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      final rangeStr = '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('EDUFIN - REKAP KEUANGAN', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Periode Laporan: $rangeStr', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 24),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TOTAL PEMASUKAN', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                          pw.SizedBox(height: 4),
                          pw.Text(formatter.format(totalIncome), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TOTAL PENGELUARAN', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                          pw.SizedBox(height: 4),
                          pw.Text(formatter.format(totalExpense), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 32),

              pw.Text('Daftar Transaksi', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['Tanggal', 'Nama Transaksi', 'Kategori', 'Tipe', 'Jumlah'],
                data: items.map((item) {
                  return [
                    item['date'],
                    item['title'],
                    item['category'],
                    item['type'],
                    formatter.format(item['amount']),
                  ];
                }).toList(),
              ),
            ];
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final dateSuffix = '${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}';
      final file = File('${tempDir.path}/edufin_rekap_${dateSuffix}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], subject: 'Rekap Keuangan PDF');
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Fungsi menyimpan kredensial Gmail pengguna ke User Metadata Supabase
  Future<String?> saveGmailCredentials(String email, String password) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 'User belum login';

      await _supabase.auth.updateUser(
        UserAttributes(data: {
          'gmail_user': email,
          'gmail_app_password': password,
        })
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Fungsi sinkronisasi transaksi dari Gmail via IMAP
  Future<Map<String, dynamic>> syncTransactionsFromEmail() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return {'success': false, 'message': 'User belum login'};

      final metadata = user.userMetadata ?? {};
      final bool gmailConnected = metadata['gmail_connected'] == true;
      final gmailUser = metadata['gmail_user']?.toString() ?? '';

      if (!gmailConnected || gmailUser.isEmpty) {
        return {
          'success': false,
          'message': 'Koneksi Gmail belum aktif. Silakan hubungkan akun Google Anda di profil!'
        };
      }

      final googleSignIn = GoogleSignIn.instance;

      GoogleSignInAccount? googleAccount = await googleSignIn.authenticate();

      if (googleAccount == null) {
        return {
          'success': false,
          'message': 'Otorisasi Gmail dibatalkan. Silakan masuk kembali!'
        };
      }

      final List<String> scopes = ['https://www.googleapis.com/auth/gmail.readonly'];
      final authorization = await googleAccount.authorizationClient.authorizeScopes(scopes);
      final accessToken = authorization.accessToken;

      if (accessToken == null || accessToken.isEmpty) {
        return {
          'success': false,
          'message': 'Gagal mengambil token akses Google. Silakan hubungkan ulang!'
        };
      }

      final client = ImapClient(isLogEnabled: false);
      await client.connectToServer('imap.gmail.com', 993, isSecure: true);
      
      try {
        await client.authenticateWithOAuth2(gmailUser, accessToken);
      } catch (loginErr) {
        await client.logout();
        return {
          'success': false,
          'message': 'Autentikasi Gmail via OAuth2 Gagal! Pastikan fitur IMAP sudah diaktifkan di setelan Gmail Anda.'
        };
      }

      await client.selectInbox();

      // Cari email masuk dengan filter subject keyword transfer/transaksi/bca/gopay/ovo/mandiri
      final searchResult = await client.searchMessages(
        searchCriteria: 'SUBJECT "transfer" OR SUBJECT "transaksi" OR SUBJECT "klikbca" OR SUBJECT "gopay" OR SUBJECT "ovo" OR SUBJECT "mandiri"'
      );

      if (searchResult.matchingSequence == null) {
        await client.logout();
        return {'success': true, 'message': 'Tidak ada email transaksi baru ditemukan.'};
      }

      final List<dynamic> processedIdsRaw = metadata['processed_email_ids'] ?? [];
      final Set<String> processedIds = processedIdsRaw.map((e) => e.toString()).toSet();

      final fetchResult = await client.fetchMessages(
        searchResult.matchingSequence!,
        'BODY.PEEK[]',
      );

      int addedCount = 0;
      final List<String> newProcessedIds = [];

      for (final message in fetchResult.messages) {
        final messageId = message.getHeaderValue('Message-ID') ?? message.uid?.toString() ?? '';
        if (messageId.isEmpty || processedIds.contains(messageId)) {
          continue;
        }

        final sender = message.from?.first.email ?? '';
        final subject = message.decodeSubject() ?? '';
        
        // Cek body plain-text atau html
        final body = message.decodeTextPlainPart() ?? message.decodeTextHtmlPart() ?? '';

        final parsed = EmailTransactionParser.parseEmail(
          sender: sender,
          subject: subject,
          body: body,
        );

        if (parsed != null) {
          final String title = parsed['title'];
          final double amount = parsed['amount'];
          final String type = parsed['type'];
          final String category = parsed['category'];
          final String walletName = parsed['wallet_name'];

          final wallets = getWalletsFromMetadata();
          String walletId = wallets.isNotEmpty ? wallets.first['id'] : '';
          
          final walletIdx = wallets.indexWhere(
            (w) => w['name'].toString().toUpperCase() == walletName.toUpperCase()
          );
          if (walletIdx != -1) {
            walletId = wallets[walletIdx]['id'];
          }

          // Buat transaksi baru
          await _supabase.from('transactions').insert({
            'user_id': user.id,
            'title': '[$walletName] $title',
            'amount': amount,
            'type': type,
            'category': category,
          });

          // Update saldo dompet
          if (walletId.isNotEmpty) {
            final double currentBalance = (wallets.firstWhere((w) => w['id'] == walletId)['balance'] ?? 0.0).toDouble();
            final double newBalance = type == 'income' 
                ? currentBalance + amount 
                : currentBalance - amount;

            wallets.firstWhere((w) => w['id'] == walletId)['balance'] = newBalance;
            await saveWalletsToMetadata(wallets);
            await syncDatabaseWalletBalance(wallets);
          }

          addedCount++;
          newProcessedIds.add(messageId);
        }
      }

      if (newProcessedIds.isNotEmpty) {
        final updatedIds = [...processedIds, ...newProcessedIds];
        await _supabase.auth.updateUser(
          UserAttributes(data: {'processed_email_ids': updatedIds})
        );
      }

      await client.logout();
      return {
        'success': true,
        'message': addedCount > 0 
            ? 'Berhasil sinkronisasi $addedCount transaksi baru dari email!'
            : 'Email sudah sinkron. Tidak ada transaksi baru.'
      };
    } catch (e) {
      print('Error di syncTransactionsFromEmail: $e');
      return {'success': false, 'message': 'Gagal sinkronisasi email: ${e.toString()}'};
    }
  }
}