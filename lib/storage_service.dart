import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._();

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String? getString(String key) => _prefs.getString(key);
  static void setString(String key, String value) {
    _prefs.setString(key, value).catchError((_) => false);
  }

  static int? getInt(String key) => _prefs.getInt(key);
  static void setInt(String key, int value) => _prefs.setInt(key, value);
}
