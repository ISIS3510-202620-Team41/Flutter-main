import 'package:flutter/foundation.dart';

import '../repositories/category_preferences_repository.dart';
import '../services/session_user.dart';

class CategoryPreferencesViewModel extends ChangeNotifier {
  CategoryPreferencesViewModel({
    CategoryPreferencesRepository? repository,
    Future<String?> Function()? userId,
  })  : _repository = repository ?? CategoryPreferencesRepository(),
        _userId = userId ?? currentUserId;

  final CategoryPreferencesRepository _repository;
  final Future<String?> Function() _userId;

  Set<String> selected = {};
  bool isLoading = true;

  bool isSelected(String category) => selected.contains(category);

  Future<void> load() async {
    selected = await _repository.load(await _userId() ?? 'anonymous');
    isLoading = false;
    notifyListeners();
  }

  Future<void> toggle(String category) async {
    selected = {...selected};
    selected.contains(category)
        ? selected.remove(category)
        : selected.add(category);
    notifyListeners();
    await _repository.save(await _userId() ?? 'anonymous', selected);
  }
}