import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'features/auth/views/auth_gate.dart';

Future<void> main() async {
  // Wajib dipanggil sebelum inisialisasi package eksternal di Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi lokalisasi tanggal Bahasa Indonesia
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi Google Sign-In
  await GoogleSignIn.instance.initialize();

  // Inisialisasi koneksi ke Supabase
  await Supabase.initialize(
    url: 'https://viyxvzbrgtzdecakkfuk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpeXh2emJyZ3R6ZGVjYWtrZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3OTE4NTYsImV4cCI6MjA5OTM2Nzg1Nn0.0qSDC3Uj_Wxghyvefmj8IhI8NRvSbfLOJhpDnWCn3aA',
  );

  runApp(const EdufinApp());
}

class EdufinApp extends StatelessWidget {
  const EdufinApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EDUFIN',
      debugShowCheckedModeBanner: false, // Menghilangkan pita "DEBUG" di pojok kanan atas
      theme: ThemeData(
        primaryColor: const Color(0xFF0F172A), // Deep Navy Blue
        scaffoldBackgroundColor: const Color(0xFFF8F9FA), // Off-White
        fontFamily: 'Inter', // Bisa disesuaikan jika kamu pakai font khusus
      ),
      // Menjadikan MainLayout (Cangkang Navbar) sebagai halaman pertama yang dimuat
      home: const AuthGate(), 
    );
  }
}