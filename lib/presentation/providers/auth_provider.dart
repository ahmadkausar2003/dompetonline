
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthState {
  final User? user;
  final String? role; // 'student' atau 'admin'
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.role,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    User? user,
    String? role,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  AuthState build() {
    // Mendengarkan perubahan status login secara real-time
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _fetchUserRole(user);
      } else {
        state = const AuthState();
      }
    });
    
    return AuthState(user: _auth.currentUser, isLoading: _auth.currentUser != null);
  }

  Future<void> _fetchUserRole(User user) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        state = state.copyWith(
          user: user,
          role: doc.data()?['role'] as String?,
          isLoading: false,
        );
      } else {
        // Jika tidak ada data, default ke student
        state = state.copyWith(
          user: user,
          role: 'student',
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal mengambil data profil: $e',
      );
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // Tidak perlu set state manual, authStateChanges() akan otomatis berjalan
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> signUp(String email, String password, String role) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        // Simpan data role ke Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await _auth.signOut();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});