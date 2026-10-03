import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;
  bool isSubmitting = false;
  bool isGoogleSubmitting = false;
  String? errorMessage;

  Future<bool> login(String email, String password) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authService.login(email: email.trim(), password: password);
      authSession.setAuthenticated();
      return true;
    } on AuthException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'No pudimos conectar con el servidor. Intenta de nuevo.';
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> loginWithGoogle() async {
    isGoogleSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authService.loginWithGoogle();
      authSession.setAuthenticated();
      return true;
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        errorMessage = 'No fue posible iniciar sesión con Google.';
      }
    } on AuthException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'No pudimos conectar con el servidor. Intenta de nuevo.';
    } finally {
      isGoogleSubmitting = false;
      notifyListeners();
    }
    return false;
  }
}

class RegisterViewModel extends ChangeNotifier {
  RegisterViewModel({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;
  bool isSubmitting = false;
  String? errorMessage;

  Future<bool> register(String name, String email, String password) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authService.register(
        name: name.trim(),
        email: email.trim(),
        password: password,
      );
      await _authService.clearSession();
      authSession.setUnauthenticated();
      return true;
    } on AuthException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'No pudimos conectar con el servidor. Intenta de nuevo.';
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
    return false;
  }
}
