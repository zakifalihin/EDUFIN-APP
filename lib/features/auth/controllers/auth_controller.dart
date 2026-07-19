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
        emailRedirectTo: 'com.example.edufin://login-callback',
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

  // 4. Fungsi Login dengan Google
  Future<String?> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.example.edufin://login-callback',
        queryParams: {
          'prompt': 'select_account',
        },
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // 5. Fungsi Reset Sandi (Forgot Password)
  Future<String?> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.example.edufin://login-callback',
      );
      return null; // Sukses
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}