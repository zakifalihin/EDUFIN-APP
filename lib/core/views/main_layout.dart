import 'package:flutter/material.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../features/dashboard/views/dashboard_screen.dart';
import '../../features/finance/views/finance_screen.dart';
// 1. TAMBAHKAN IMPORT INI AGAR TIDAK ERROR
import '../../features/academic/views/academic_screen.dart'; 
import '../../features/profile/views/profile_screen.dart'; 

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const FinanceScreen(),
    const AcademicScreen(), // Ini memanggil halaman Academic yang baru dibuat
    const ProfileScreen(),
  ];

  // 2. UBAH FUNGSI INI: Sekarang khusus untuk Scan Struk AI
  void _showDirectReceiptScanner(BuildContext context) {
    // Sebagai *placeholder* sementara sebelum kita pasang AI Kamera-nya
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: 200,
        child: Column(
          children: [
            const Icon(Icons.document_scanner, size: 48, color: Color(0xFFB48811)),
            const SizedBox(height: 16),
            const Text('AI Receipt Scanner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Fitur kamera cerdas untuk membaca struk kasir akan segera ditambahkan di sini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _pages[_currentIndex], 
      
      floatingActionButton: FloatingActionButton(
        // 3. ARAHKAN TOMBOL KE FUNGSI SCANNER
        onPressed: () => _showDirectReceiptScanner(context),
        backgroundColor: const Color(0xFFFFC107),
        // Warnanya diubah jadi biru dongker agar kontras dan elegan
        child: const Icon(Icons.auto_awesome, color: Color(0xFF0F172A), size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}