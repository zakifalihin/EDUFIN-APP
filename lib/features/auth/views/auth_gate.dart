import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import '../../../core/views/main_layout.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // StreamBuilder akan terus memantau status login dari Supabase secara real-time
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Tampilkan loading saat sedang mengecek memori HP
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8F9FA),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFFC107)),
            ),
          );
        }
        
        // Ambil data sesi saat ini
        final session = snapshot.data?.session;
        
        // Logika Gerbang: Ada sesi = Masuk Dashboard | Kosong = Lempar ke Login
        if (session != null) {
          return const MainLayout();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}