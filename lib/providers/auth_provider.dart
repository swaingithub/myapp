import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) {
          _isLoading = false;
          notifyListeners();
          verificationCompleted(credential);
        },
        verificationFailed: (e) {
          _isLoading = false;
          notifyListeners();
          verificationFailed(e);
        },
        codeSent: (verificationId, resendToken) {
          _isLoading = false;
          notifyListeners();
          codeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInWithPhoneCredential(AuthCredential credential) async {
    _isLoading = true;
    notifyListeners();
    try {
      UserCredential cred = await _authService.signInWithCredential(credential);
      if (cred.user != null) {
        // Check if user exists, if not create new user
        // For now, we just save/update the user
        UserModel newUser = UserModel(
          uid: cred.user!.uid,
          phoneNumber: cred.user!.phoneNumber,
        );
        await _databaseService.saveUser(newUser);
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signInWithEmailAndPassword(email, password);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      UserCredential cred =
          await _authService.signUpWithEmailAndPassword(email, password);
      if (cred.user != null) {
        UserModel newUser = UserModel(
          uid: cred.user!.uid,
          email: email,
        );
        await _databaseService.saveUser(newUser);
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
