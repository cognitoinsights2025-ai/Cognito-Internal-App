import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class NoticeService {
  static final NoticeService _i = NoticeService._();
  factory NoticeService() => _i;
  NoticeService._();

  static const _key = 'notices';
  final _uuid = const Uuid();
  final List<Notice> _notices = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _notices.clear();
      _notices.addAll(list.map((e) => Notice.fromJson(e)));
    } else {
      _seedDefaults();
    }
    _loaded = true;
  }

  void _seedDefaults() {
    final now = DateTime.now();
    _notices.addAll([
      Notice(
        id: _uuid.v4(), title: '🎉 Welcome to Cognito Insights!',
        body: 'We are excited to have our new team members on board. Please check your onboarding documents and complete all formalities by this week.',
        type: NoticeType.general, postedBy: 'Admin',
        createdAt: now.subtract(const Duration(hours: 2)), isPinned: true,
      ),
      Notice(
        id: _uuid.v4(), title: '⚠️ Attendance Policy — Mandatory Face Scan',
        body: 'All employees must complete face attendance every day before accessing the system. Attendance is recorded once per day and is mandatory for payroll processing.',
        type: NoticeType.policy, postedBy: 'Admin',
        createdAt: now.subtract(const Duration(days: 1)), isPinned: true,
      ),
      Notice(
        id: _uuid.v4(), title: '🏖️ Public Holiday — May 1st (Labour Day)',
        body: "May 1st, 2026 is a public holiday. The office will remain closed. Enjoy your holiday!",
        type: NoticeType.holiday, postedBy: 'Admin',
        createdAt: now.subtract(const Duration(days: 2)), isPinned: false,
      ),
      Notice(
        id: _uuid.v4(), title: '📋 Monthly Review Meeting',
        body: 'The monthly review meeting is scheduled for April 30, 2026 at 10:00 AM. All team members are requested to prepare their progress reports.',
        type: NoticeType.general, postedBy: 'Admin',
        createdAt: now.subtract(const Duration(days: 3)), isPinned: false,
      ),
    ]);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_notices.map((n) => n.toJson()).toList()));
  }

  Future<List<Notice>> getAll() async {
    await _ensureLoaded();
    final sorted = List<Notice>.from(_notices)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return sorted;
  }

  Future<Notice> create({
    required String title,
    required String body,
    required NoticeType type,
    required String postedBy,
    bool isPinned = false,
  }) async {
    await _ensureLoaded();
    final notice = Notice(
      id: _uuid.v4(), title: title, body: body,
      type: type, postedBy: postedBy,
      createdAt: DateTime.now(), isPinned: isPinned,
    );
    _notices.insert(0, notice);
    await _save();
    return notice;
  }

  Future<void> delete(String id) async {
    await _ensureLoaded();
    _notices.removeWhere((n) => n.id == id);
    await _save();
  }

  Future<void> togglePin(String id) async {
    await _ensureLoaded();
    final idx = _notices.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    _notices[idx] = _notices[idx].copyWith(isPinned: !_notices[idx].isPinned);
    await _save();
  }
}

enum NoticeType { general, urgent, policy, holiday }

class Notice {
  final String id, title, body, postedBy;
  final NoticeType type;
  final DateTime createdAt;
  final bool isPinned;

  Notice({
    required this.id, required this.title, required this.body,
    required this.postedBy, required this.type,
    required this.createdAt, this.isPinned = false,
  });

  Notice copyWith({bool? isPinned}) => Notice(
    id: id, title: title, body: body, postedBy: postedBy,
    type: type, createdAt: createdAt, isPinned: isPinned ?? this.isPinned,
  );

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
    id: j['id'], title: j['title'], body: j['body'],
    postedBy: j['postedBy'], type: NoticeType.values[j['type']],
    createdAt: DateTime.parse(j['createdAt']), isPinned: j['isPinned'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'body': body, 'postedBy': postedBy,
    'type': type.index, 'createdAt': createdAt.toIso8601String(),
    'isPinned': isPinned,
  };

  String get typeLabel {
    switch (type) {
      case NoticeType.general: return 'General';
      case NoticeType.urgent: return 'Urgent';
      case NoticeType.policy: return 'Policy';
      case NoticeType.holiday: return 'Holiday';
    }
  }
}
