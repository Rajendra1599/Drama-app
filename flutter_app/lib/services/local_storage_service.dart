import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/watch_history.dart';

class LocalStorageService {
  static const String _keyTerms = 'has_accepted_terms';
  static const String _keyAuth = 'user_authenticated';
  static const String _keyToken = 'jwt_token';
  static const String _keyPhone = 'user_phone';
  static const String _keyEmail = 'user_email';
  static const String _keyName = 'user_name';
  static const String _keyAvatar = 'user_avatar';
  static const String _keyAdmin = 'is_admin_logged_in';
  static const String _keyWatchlist = 'watchlist_ids';
  static const String _keyHistory = 'watch_history_records';
  static const String _keyCatalogCache = 'cached_catalog_json';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String get cachedCatalog => _prefs?.getString(_keyCatalogCache) ?? '';
  static Future<void> setCachedCatalog(String val) async => await _prefs?.setString(_keyCatalogCache, val);

  static bool get hasAcceptedTerms => _prefs?.getBool(_keyTerms) ?? false;
  static Future<void> setAcceptedTerms(bool val) async => await _prefs?.setBool(_keyTerms, val);

  static bool get isAuthenticated => _prefs?.getBool(_keyAuth) ?? false;
  static Future<void> setAuthenticated(bool val) async => await _prefs?.setBool(_keyAuth, val);

  static String get token => _prefs?.getString(_keyToken) ?? '';
  static Future<void> setToken(String token) async => await _prefs?.setString(_keyToken, token);

  static String get phone => _prefs?.getString(_keyPhone) ?? '';
  static Future<void> setPhone(String phone) async => await _prefs?.setString(_keyPhone, phone);

  static String get email => _prefs?.getString(_keyEmail) ?? '';
  static Future<void> setEmail(String email) async => await _prefs?.setString(_keyEmail, email);

  static String get name => _prefs?.getString(_keyName) ?? '';
  static Future<void> setName(String name) async => await _prefs?.setString(_keyName, name);

  static String get avatar => _prefs?.getString(_keyAvatar) ?? '';
  static Future<void> setAvatar(String avatar) async => await _prefs?.setString(_keyAvatar, avatar);

  static bool get isAdmin => _prefs?.getBool(_keyAdmin) ?? false;
  static Future<void> setAdmin(bool val) async => await _prefs?.setBool(_keyAdmin, val);

  static Future<void> clearAuth() async {
    await _prefs?.setBool(_keyAuth, false);
    await _prefs?.setString(_keyToken, '');
    await _prefs?.setString(_keyPhone, '');
    await _prefs?.setString(_keyEmail, '');
    await _prefs?.setString(_keyName, '');
    await _prefs?.setString(_keyAvatar, '');
    await _prefs?.setBool(_keyAdmin, false);
  }

  static List<String> getWatchlist() {
    return _prefs?.getStringList(_keyWatchlist) ?? [];
  }

  static Future<void> setWatchlist(List<String> list) async {
    await _prefs?.setStringList(_keyWatchlist, list);
  }

  static List<WatchHistory> getWatchHistory() {
    final raw = _prefs?.getStringList(_keyHistory) ?? [];
    return raw.map((str) {
      try {
        return WatchHistory.fromJson(jsonDecode(str));
      } catch (e) {
        return null;
      }
    }).whereType<WatchHistory>().toList();
  }

  static Future<void> saveWatchHistory(List<WatchHistory> history) async {
    final encoded = history.map((item) => jsonEncode(item.toJson())).toList();
    await _prefs?.setStringList(_keyHistory, encoded);
  }
}
