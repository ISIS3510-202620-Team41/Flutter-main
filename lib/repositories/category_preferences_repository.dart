import 'package:shared_preferences/shared_preferences.dart';

class CategoryPreferencesRepository {
  static String _key(String userId) => 'favorite_categories_$userId';

  Future<Set<String>> load(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_key(userId)) ?? const []).toSet();
  }

  Future<void> save(String userId, Set<String> categories) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_key(userId), categories.toList()..sort());
  }
}