import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  String? userId;
  String? userName;
  String? userEmail;
  bool isLoading = false;
  String error = '';

  bool get isLoggedIn => userId != null;

  Future<void> signIn({
    required String emailOrUsername,
    required String password,
  }) async {
    isLoading = true;
    error = '';
    notifyListeners();

    try {
      await AuthService.signIn(
        emailOrUsername: emailOrUsername,
        password: password,
      );
      userId = AuthService.userId;
      userName = AuthService.userName;
      userEmail = AuthService.userEmail;
      error = '';
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    isLoading = true;
    error = '';
    notifyListeners();

    try {
      await AuthService.signUp(email: email, password: password, name: name);
      error = '';
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    isLoading = true;
    error = '';
    notifyListeners();

    try {
      await AuthService.confirmSignUp(email: email, code: code);
      error = '';
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    }

    isLoading = false;
    notifyListeners();
  }

  void signOut() {
    AuthService.signOut();
    userId = null;
    userName = null;
    userEmail = null;
    notifyListeners();
  }
}
