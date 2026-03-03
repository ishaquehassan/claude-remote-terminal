import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static const _key = 'language';
  bool _isUrdu = false;
  bool get isUrdu => _isUrdu;

  LanguageService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isUrdu = prefs.getString(_key) == 'ur';
    notifyListeners();
  }

  Future<void> toggle() async {
    _isUrdu = !_isUrdu;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _isUrdu ? 'ur' : 'en');
    notifyListeners();
  }
}
