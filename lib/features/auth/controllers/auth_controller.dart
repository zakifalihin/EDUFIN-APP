import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Fungsi Registrasi (Sign Up)
  Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName}, // Menyimpan nama lengkap ke metadata user
      );
      return null; // Mengembalikan null jika sukses (tidak ada error)
    } on AuthException catch (e) {
      return e.message; // Mengembalikan pesan error dari Supabase (misal: email sudah terdaftar)
    } catch (e) {
      return e.toString();
    }
  }

  // 2. Fungsi Login (Sign In)
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null; // Sukses
    } on AuthException catch (e) {
      return e.message; // Mengembalikan pesan error (misal: password salah)
    } catch (e) {
      return e.toString();
    }
  }

  // 3. Fungsi Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}