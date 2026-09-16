import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _announcementsUrl =
    'https://qkroecnecdxghcqvvoxn.supabase.co/functions/v1/notifications/announcements';
const _publishableKey = 'sb_publishable_dLYCid35ZkeIE95xqiyHoQ_bEhWWISK';

@immutable
class InAppAnnouncement {
  const InAppAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.priority,
    required this.dismissible,
    this.deepLink,
  });

  factory InAppAnnouncement.fromJson(Map<String, dynamic> value) =>
      InAppAnnouncement(
        id: '${value['id']}',
        title: '${value['title']}',
        body: '${value['body']}',
        priority: (value['priority'] as num?)?.toInt() ?? 0,
        dismissible: value['dismissible'] != false,
        deepLink: value['deep_link'] as String?,
      );

  final String id;
  final String title;
  final String body;
  final int priority;
  final bool dismissible;
  final String? deepLink;
}

class AnnouncementService extends ChangeNotifier {
  AnnouncementService(this._preferences, {http.Client? client})
    : _client = client ?? http.Client();

  final SharedPreferences _preferences;
  final http.Client _client;
  List<InAppAnnouncement> _items = const <InAppAnnouncement>[];

  List<InAppAnnouncement> get items => List.unmodifiable(_items);
  InAppAnnouncement? get current => _items.isEmpty ? null : _items.first;

  Future<void> refresh() async {
    try {
      final response = await _client
          .get(
            Uri.parse(_announcementsUrl),
            headers: const <String, String>{'apikey': _publishableKey},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? decoded['data'] : null;
      final rows = data is Map ? data['items'] : null;
      if (rows is! List) return;
      final next =
          rows
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (row) =>
                    InAppAnnouncement.fromJson(Map<String, dynamic>.from(row)),
              )
              .where((item) => !_dismissed(item.id))
              .toList()
            ..sort((left, right) => right.priority.compareTo(left.priority));
      _items = next;
      notifyListeners();
    } catch (_) {
      // Announcements must never block offline startup.
    }
  }

  bool _dismissed(String id) =>
      _preferences.getBool('announcement:dismissed:$id') ?? false;

  Future<void> dismiss(String id) async {
    await _preferences.setBool('announcement:dismissed:$id', true);
    _items = _items.where((item) => item.id != id).toList();
    notifyListeners();
  }
}
