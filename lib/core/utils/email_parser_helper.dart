import 'dart:developer' as dev;

class EmailTransactionParser {
  /// Mengurai subjek, isi email, dan pengirim untuk menghasilkan objek transaksi.
  /// Mengembalikan Map jika berhasil diurai, atau null jika bukan email transaksi/tidak cocok.
  static Map<String, dynamic>? parseEmail({
    required String sender,
    required String subject,
    required String body,
  }) {
    final cleanSender = sender.toLowerCase();
    final cleanSubject = subject.toLowerCase();
    final cleanBody = body.toLowerCase();

    // 1. Deteksi Bank / Dompet berdasarkan Pengirim atau Konten
    String walletName = 'DOMPET UTAMA';
    if (cleanSender.contains('klikbca') || cleanSender.contains('bca') || cleanBody.contains('klikbca') || cleanBody.contains('m-bca')) {
      walletName = 'BCA';
    } else if (cleanSender.contains('mandiri') || cleanBody.contains('livin') || cleanBody.contains('mandiri online')) {
      walletName = 'MANDIRI';
    } else if (cleanSender.contains('go-jek') || cleanSender.contains('gopay') || cleanBody.contains('gopay')) {
      walletName = 'GOPAY';
    } else if (cleanSender.contains('ovo') || cleanBody.contains('ovo.id') || cleanBody.contains('ovo transaction')) {
      walletName = 'OVO';
    }

    // 2. Deteksi Tipe (Pemasukan / Pengeluaran)
    String type = 'expense';
    if (cleanSubject.contains('transfer masuk') ||
        cleanSubject.contains('kredit') ||
        cleanBody.contains('transfer masuk') ||
        cleanBody.contains('kredit') ||
        cleanBody.contains('top up berhasil') ||
        cleanBody.contains('penerimaan dana') ||
        cleanBody.contains('topup')) {
      type = 'income';
    }

    // 3. Ekstraksi Nominal (Mencari pola Rp 50.000 atau Rp. 50.000 atau IDR 50,000)
    double amount = 0.0;
    // Regex mencari angka setelah kata Rp, Rp., IDR, IDR.
    final amountReg = RegExp(r'(rp\.?|idr\.?)\s*([0-9]{1,3}(\.[0-9]{3})*(,[0-9]+)?)', caseSensitive: false);
    final match = amountReg.firstMatch(cleanBody) ?? amountReg.firstMatch(cleanSubject);

    if (match != null) {
      final valStr = match.group(2) ?? '';
      // BCA menggunakan format titik untuk ribuan, hilangkan titik
      // Jika ada koma di ujung (desimal), hilangkan desimalnya untuk kesederhanaan
      String cleanVal = valStr.split(',')[0].replaceAll('.', '').trim();
      amount = double.tryParse(cleanVal) ?? 0.0;
    }

    if (amount <= 0) {
      // Cari angka murni jika regex di atas gagal
      final amountRegMurni = RegExp(r'\b([0-9]{1,3}(\.[0-9]{3})+)\b');
      final matchMurni = amountRegMurni.firstMatch(cleanBody);
      if (matchMurni != null) {
        final valStr = matchMurni.group(1) ?? '';
        amount = double.tryParse(valStr.replaceAll('.', '')) ?? 0.0;
      }
    }

    if (amount <= 0) {
      dev.log('Gagal mengurai nominal dari email. Subject: $subject');
      return null; // Tidak dapat nominal
    }

    // 4. Ekstraksi Judul Transaksi (Title)
    String title = 'Transaksi Otomatis';
    if (walletName == 'BCA') {
      if (type == 'income') {
        title = 'Transfer Masuk BCA';
      } else {
        // Cari nama penerima m-transfer sukses ke 1234567 a/n BUDI
        final bcaTargetReg = RegExp(r'a/n\s+([a-zA-Z\s]+?)\s+sebesar', caseSensitive: false);
        final bcaTargetMatch = bcaTargetReg.firstMatch(body);
        if (bcaTargetMatch != null) {
          title = 'Transfer ke ${(bcaTargetMatch.group(1) ?? '').trim().toUpperCase()}';
        } else {
          title = 'M-Transfer BCA';
        }
      }
    } else if (walletName == 'GOPAY') {
      if (cleanBody.contains('gofood')) {
        title = 'Belanja GoFood';
      } else if (cleanBody.contains('goride') || cleanBody.contains('gocar')) {
        title = 'Perjalanan GoJek';
      } else {
        title = 'Pembayaran GoPay';
      }
    } else if (walletName == 'MANDIRI') {
      title = type == 'income' ? 'Transfer Masuk Mandiri' : 'Transfer Keluar Mandiri';
    } else if (walletName == 'OVO') {
      title = type == 'income' ? 'Top Up OVO' : 'Pembayaran OVO';
    } else {
      title = 'Notifikasi Email $walletName';
    }

    // 5. Klasifikasi Kategori Otomatis berdasarkan kata kunci judul/isi email
    String category = 'LAINNYA';
    final lowerTitle = title.toLowerCase();
    if (cleanBody.contains('gofood') || cleanBody.contains('grabfood') || lowerTitle.contains('makan') || cleanBody.contains('restoran') || cleanBody.contains('kopi')) {
      category = 'MAKANAN';
    } else if (cleanBody.contains('goride') || cleanBody.contains('gocar') || cleanBody.contains('grab') || cleanBody.contains('trans') || cleanBody.contains('bensin') || cleanBody.contains('kai') || cleanBody.contains('tiket')) {
      category = 'TRANSPORTASI';
    } else if (cleanBody.contains('apotek') || cleanBody.contains('dokter') || cleanBody.contains('sakit') || cleanBody.contains('obat') || cleanBody.contains('klinik')) {
      category = 'KESEHATAN';
    } else if (cleanBody.contains('sekolah') || cleanBody.contains('kuliah') || cleanBody.contains('spp') || cleanBody.contains('buku') || cleanBody.contains('kursus')) {
      category = 'PENDIDIKAN';
    } else if (cleanBody.contains('zakat') || cleanBody.contains('donasi') || cleanBody.contains('sedekah') || cleanBody.contains('kondangan') || cleanBody.contains('sosial')) {
      category = 'SOSIAL';
    }

    return {
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'wallet_name': walletName,
    };
  }
}
