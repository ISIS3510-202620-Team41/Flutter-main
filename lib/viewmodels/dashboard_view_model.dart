import 'package:flutter/foundation.dart';

class DashboardViewModel extends ChangeNotifier {
  int selectedIndex = 0;

  void selectTab(int index) {
    if (selectedIndex == index) return;
    selectedIndex = index;
    notifyListeners();
  }
}
