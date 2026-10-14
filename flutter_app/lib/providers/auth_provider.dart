import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';
import '../config/firebase_config.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isAdminLoggedIn = false;
  bool _hasAcceptedTerms = false;
  String _phoneNumber = '';
  String _email = '';
  String _displayName = '';
  String _avatar = '';
  String _currentUserId = '';
  bool _isLoading = false;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  bool get isAdminLoggedIn => _isAdminLoggedIn;
  bool get hasAcceptedTerms => _hasAcceptedTerms;
  String get phoneNumber => _phoneNumber;
  String get email => _email;
  String get displayName => _displayName;
  String get avatar => _avatar;
  String get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _loadState();
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    if (FirebaseConfig.isConfigured) {
      GoogleAuthWebService.initFirebase(FirebaseConfig.toMap());
      return;
    }
    final config = await ApiService.fetchFirebaseConfig();
    if (config != null && (config['apiKey']?.toString().isNotEmpty ?? false)) {
      GoogleAuthWebService.initFirebase(config);
    }
  }

  void _loadState() {
    _isAuthenticated = LocalStorageService.isAuthenticated;
    _hasAcceptedTerms = LocalStorageService.hasAcceptedTerms;
    _isAdminLoggedIn = LocalStorageService.isAdmin;
    _phoneNumber = LocalStorageService.phone;
    _email = LocalStorageService.email;
    _displayName = LocalStorageService.name;
    _avatar = LocalStorageService.avatar;
    _currentUserId = _isAuthenticated && _email.isNotEmpty
        ? 'user_${_email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}'
        : '';

    notifyListeners();
  }

  Future<void> acceptTerms() async {
    _hasAcceptedTerms = true;
    await LocalStorageService.setAcceptedTerms(true);
    notifyListeners();
  }

  Future<bool> signInWithGoogle({String? customEmail, String? customName, String? customPhoto}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _initFirebase();
      String? email = customEmail;
      String? name = customName;
      String? photo = customPhoto;

      // Trigger device account chooser (Web GSI / Android Google Play Services)
      if (email == null || email.isEmpty) {
        final profile = await GoogleAuthWebService.triggerGoogleAccountChooser();
        if (profile == null) {
          _isLoading = false;
          _errorMessage = 'Sign-in cancelled';
          notifyListeners();
          return false;
        }
        if (profile['error'] != null) {
          _isLoading = false;
          _errorMessage = profile['error']?.toString() ?? 'Google Sign-in failed';
          notifyListeners();
          return false;
        }
        if (profile['email'] == null) {
          _isLoading = false;
          _errorMessage = 'No Google account selected';
          notifyListeners();
          return false;
        }
        email = profile['email']?.toString();
        name = profile['displayName']?.toString() ?? email?.split('@')[0];
        photo = profile['photoUrl']?.toString();
      }

      final cleanEmail = email!.trim().toLowerCase();
      if (!cleanEmail.contains('@')) {
        _errorMessage = 'Invalid Google account selected.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final finalName = (name != null && name.isNotEmpty) ? name : cleanEmail.split('@')[0];
      final avatarUrl = (photo != null && photo.isNotEmpty)
          ? photo
          : 'https://api.dicebear.com/7.x/initials/svg?seed=${Uri.encodeComponent(finalName)}';

      final res = await ApiService.signInWithGoogle(
        email: cleanEmail,
        displayName: finalName,
        photoUrl: avatarUrl,
      );

      if (res['success'] == true) {
        _isAuthenticated = true;
        _email = res['email'] ?? email;
        _displayName = res['displayName'] ?? name;
        _avatar = res['photoUrl'] ?? avatarUrl;
        _currentUserId = res['userId'] ?? 'user_google_active';

        if (res['token'] != null) {
          await LocalStorageService.setToken(res['token']);
        }
        await LocalStorageService.setAuthenticated(true);
        await LocalStorageService.setEmail(_email);
        await LocalStorageService.setName(_displayName);
        await LocalStorageService.setAvatar(_avatar);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Google Sign-In failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Google Sign-In error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.sendOtp(phone);
      _isLoading = false;
      notifyListeners();
      return res;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': 'Failed to send OTP'};
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.verifyOtp(phone, otp);
      if (res['success'] == true) {
        _isAuthenticated = true;
        _phoneNumber = '+91 ${phone.replaceAll(RegExp(r'[^0-9]'), '').substring(phone.length >= 10 ? phone.length - 10 : 0)}';
        _currentUserId = res['userId'] ?? 'user_9876543210';
        if (res['token'] != null) {
          await LocalStorageService.setToken(res['token']);
        }
        await LocalStorageService.setAuthenticated(true);
        await LocalStorageService.setPhone(_phoneNumber);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Invalid OTP';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Verification error: $e';
      notifyListeners();
      return false;
    }
  }

  void bypassLoginForTesting() async {
    _isAuthenticated = true;
    _phoneNumber = '+91 98765 43210';
    _currentUserId = 'user_9876543210';
    await LocalStorageService.setAuthenticated(true);
    await LocalStorageService.setPhone(_phoneNumber);
    notifyListeners();
  }

  bool loginAdmin(String id, String password) {
    final cleanId = id.trim().toLowerCase();
    final cleanPass = password.trim();

    final isValidId = cleanId == 'bhuyanrajendra598@gmail.com' ||
                      cleanId == 'admin@storyup.com' ||
                      cleanId == 'admin';
    final isValidPass = cleanPass == 'admin123' || cleanPass == 'storyup2026';

    if (isValidId && isValidPass) {
      _isAdminLoggedIn = true;
      _email = cleanId.contains('@') ? cleanId : 'bhuyanrajendra598@gmail.com';
      LocalStorageService.setAdmin(true);
      LocalStorageService.setEmail(_email);
      notifyListeners();
      return true;
    }
    return false;
  }

  void logoutAdmin() {
    _isAdminLoggedIn = false;
    LocalStorageService.setAdmin(false);
    notifyListeners();
  }

  Future<void> logoutUser() async {
    _isAuthenticated = false;
    _isAdminLoggedIn = false;
    _phoneNumber = '';
    _email = '';
    _displayName = '';
    _avatar = '';
    _currentUserId = '';
    await LocalStorageService.clearAuth();
    await GoogleAuthWebService.signOut();
    notifyListeners();
  }
}
