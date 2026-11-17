import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records pages the reader explicitly marks as read in the current khatmah.
class ReadingJourneyStore extends ChangeNotifier {
  ReadingJourneyStore(this._preferences, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _load();
  }

  static const pageCount = 604;
  static const _key = 'mushaf:reading-journey:v1';

  final SharedPreferences _preferences;
  final DateTime Function() _clock;
  Map<int, String> _pages = {};
  int _dailyGoal = 5;
  int _completedKhatmahs = 0;
  bool _saving = false;

  int get dailyGoal => _dailyGoal;
  int get pagesRead => _pages.length;
  int get completedKhatmahs => _completedKhatmahs;
  bool get khatmahComplete => pagesRead == pageCount;
  int? get firstUnreadPage {
    for (var page = 1; page <= pageCount; page++) {
      if (!hasRead(page)) return page;
    }
    return null;
  }

  bool hasRead(int page) => _pages.containsKey(page);

  int get pagesReadToday {
    final today = _dateKey(_clock());
    return _pages.values.where((date) => date == today).length;
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void _load() {
    try {
      final raw = _preferences.getString(_key);
      if (raw == null) return;
      final state = jsonDecode(raw);
      if (state is! Map<String, dynamic>) return;
      final goal = state['dailyGoal'];
      if (goal is int && goal >= 1 && goal <= pageCount) _dailyGoal = goal;
      final khatmahs = state['completedKhatmahs'];
      if (khatmahs is int && khatmahs >= 0) _completedKhatmahs = khatmahs;
      final pages = state['pages'];
      if (pages is! Map<String, dynamic>) return;
      for (final entry in pages.entries) {
        final page = int.tryParse(entry.key);
        final date = entry.value;
        if (page != null &&
            page >= 1 &&
            page <= pageCount &&
            date is String &&
            DateTime.tryParse(date) != null) {
          _pages[page] = date;
        }
      }
    } on FormatException {
      // A damaged record cannot prevent access to the reader.
    } on TypeError {
      // An unexpected preference type cannot prevent app startup.
    }
  }

  Future<bool> togglePage(int page) {
    RangeError.checkValueInInterval(page, 1, pageCount, 'page');
    final pages = Map<int, String>.of(_pages);
    if (pages.remove(page) == null) pages[page] = _dateKey(_clock());
    return _save(pages, _dailyGoal, _completedKhatmahs);
  }

  Future<bool> setDailyGoal(int goal) {
    RangeError.checkValueInInterval(goal, 1, pageCount, 'goal');
    return _save(_pages, goal, _completedKhatmahs);
  }

  Future<bool> startNextKhatmah() async {
    if (!khatmahComplete) return false;
    return _save({}, _dailyGoal, _completedKhatmahs + 1);
  }

  Future<bool> _save(Map<int, String> pages, int goal, int completed) async {
    if (_saving) return false;
    _saving = true;
    try {
      final saved = await _preferences.setString(
        _key,
        jsonEncode({
          'dailyGoal': goal,
          'completedKhatmahs': completed,
          'pages': {
            for (final entry in pages.entries) '${entry.key}': entry.value,
          },
        }),
      );
      if (!saved) return false;
      _pages = pages;
      _dailyGoal = goal;
      _completedKhatmahs = completed;
      notifyListeners();
      return true;
    } on Exception {
      return false;
    } finally {
      _saving = false;
    }
  }
}
