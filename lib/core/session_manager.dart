import 'dart:io' as dart_io;
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyBearerToken = "BEARER_TOKEN";
  static const String _keyTokenExpiry = "TOKEN_EXPIRY";
  static const String _keyUserEmail = "USER_EMAIL";
  static const String _keyUserName = "USER_NAME";
  static const String _keyUserStore = "USER_STORE";
  static const String _keyRememberLogin = "REMEMBER_LOGIN";
  static const String _keyMsPassword = "MS_PASSWORD";
  static const String _keyPrinterIp = "PRINTER_IP";
  static const String _keyProfilePhoto = "PROFILE_PHOTO";
  static const String _keyNickname = "PROFILE_NICKNAME";
  static const int tokenExpiryDays = 14;
  static const String defaultPrinterIp = "10.25.168.24";
  static const int printerPort = 9100;

  static SessionManager? instance;
  static SharedPreferences? _prefs;

  static Future<SessionManager> getInstance() async {
    _prefs ??= await SharedPreferences.getInstance();
    instance ??= SessionManager._();
    return instance!;
  }

  SessionManager._();

  void saveToken(String token) {
    final expiry =
        DateTime.now().millisecondsSinceEpoch + (tokenExpiryDays * 24 * 60 * 60 * 1000);
    _prefs!.setString(_keyBearerToken, token);
    _prefs!.setInt(_keyTokenExpiry, expiry);
    _prefs!.setBool(_keyRememberLogin, true);
  }

  void saveTokenWithExpiry(String token, {int? expiryEpochSeconds}) {
    final expiry = (expiryEpochSeconds != null
            ? expiryEpochSeconds * 1000
            : DateTime.now().millisecondsSinceEpoch +
                (tokenExpiryDays * 24 * 60 * 60 * 1000))
        .clamp(
            DateTime.now().millisecondsSinceEpoch,
            DateTime.now()
                .add(const Duration(days: 365))
                .millisecondsSinceEpoch);
    _prefs!.setString(_keyBearerToken, token);
    _prefs!.setInt(_keyTokenExpiry, expiry);
    _prefs!.setBool(_keyRememberLogin, true);
  }

  String? getToken() {
    final token = _prefs!.getString(_keyBearerToken);
    if (token == null || token.isEmpty) return null;
    if (isTokenExpired()) {
      clearToken();
      return null;
    }
    return token;
  }

  bool isLoggedIn() {
    final remember = _prefs!.getBool(_keyRememberLogin) ?? false;
    final token = getToken();
    return remember && token != null && token.isNotEmpty;
  }

  bool isTokenExpired() {
    final expiry = _prefs!.getInt(_keyTokenExpiry) ?? 0;
    if (expiry == 0) return false;
    return DateTime.now().millisecondsSinceEpoch > expiry;
  }

  void clearToken() {
    _prefs!.remove(_keyBearerToken);
    _prefs!.remove(_keyTokenExpiry);
    _prefs!.setBool(_keyRememberLogin, false);
  }

  void saveUserInfo(String email, String name, String store) {
    _prefs!.setString(_keyUserEmail, email);
    _prefs!.setString(_keyUserName, name);
    _prefs!.setString(_keyUserStore, store);
  }

  String? getUserEmail() => _prefs!.getString(_keyUserEmail);
  String? getUserName() => _prefs!.getString(_keyUserName);
  String getUserStore() => _prefs!.getString(_keyUserStore) ?? "L291";

  void saveCredentials(String email, String password) {
    _prefs!.setString(_keyUserEmail, email);
    _prefs!.setString(_keyMsPassword, password);
  }

  String? getSavedPassword() => _prefs!.getString(_keyMsPassword);

  bool hasSavedCredentials() {
    final email = getUserEmail();
    final senha = getSavedPassword();
    return email != null &&
        email.isNotEmpty &&
        senha != null &&
        senha.isNotEmpty;
  }

  String getPrinterIp() {
    try {
      return _prefs!.getString(_keyPrinterIp)?.trim().isNotEmpty == true
          ? _prefs!.getString(_keyPrinterIp)!.trim()
          : defaultPrinterIp;
    } catch (_) {
      return defaultPrinterIp;
    }
  }

  void savePrinterIp(String ip) {
    try {
      _prefs!.setString(_keyPrinterIp, ip.trim());
    } catch (_) {}
  }

  void saveProfilePhoto(String path) {
    try {
      _prefs!.setString(_keyProfilePhoto, path);
    } catch (_) {}
  }

  String? getProfilePhoto() {
    try {
      final path = _prefs!.getString(_keyProfilePhoto);
      if (path == null || path.isEmpty) return null;
      final file = dart_io.File(path);
      return file.existsSync() ? path : null;
    } catch (_) {
      return null;
    }
  }

  void clearProfilePhoto() {
    try {
      _prefs!.remove(_keyProfilePhoto);
    } catch (_) {}
  }

  void saveNickname(String nickname) {
    try {
      _prefs!.setString(_keyNickname, nickname.trim());
    } catch (_) {}
  }

  String? getNickname() {
    try {
      final v = _prefs!.getString(_keyNickname);
      return (v == null || v.trim().isEmpty) ? null : v.trim();
    } catch (_) {
      return null;
    }
  }

  void clearNickname() {
    try {
      _prefs!.remove(_keyNickname);
    } catch (_) {}
  }

  void clearCredentials() {
    _prefs!.remove(_keyMsPassword);
  }

  void clearAll() {
    _prefs!.clear();
  }
}
