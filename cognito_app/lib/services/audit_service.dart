import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AuditService {
  static final AuditService _i = AuditService._();
  factory AuditService() => _i;
  AuditService._();

  static const _key = 'audit_logs';
  final _uuid = const Uuid();

  final List<AuditLog> _logs = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _logs.clear();
      _logs.addAll(list.map((e) => AuditLog.fromJson(e)));
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_logs.map((e) => e.toJson()).toList()));
  }

  Future<AuditLog> log({
    required String userId,
    required String userName,
    required String action,
    String? detail,
    String? sessionId,
  }) async {
    await _ensureLoaded();
    final entry = AuditLog(
      id: _uuid.v4(),
      userId: userId,
      userName: userName,
      action: action,
      detail: detail ?? '',
      sessionId: sessionId ?? '',
      timestamp: DateTime.now(),
    );
    _logs.insert(0, entry);
    // Keep only last 500 logs
    if (_logs.length > 500) _logs.removeRange(500, _logs.length);
    await _save();
    return entry;
  }

  Future<List<AuditLog>> getAllLogs({String? filterUserId, String? filterAction}) async {
    await _ensureLoaded();
    return _logs.where((l) {
      if (filterUserId != null && l.userId != filterUserId) return false;
      if (filterAction != null && !l.action.toLowerCase().contains(filterAction.toLowerCase())) return false;
      return true;
    }).toList();
  }

  Future<void> clearOlderThan(int days) async {
    await _ensureLoaded();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    _logs.removeWhere((l) => l.timestamp.isBefore(cutoff));
    await _save();
  }

  /// Returns audit logs for a specific calendar date.
  Future<List<AuditLog>> getLogsForDate(DateTime date) async {
    await _ensureLoaded();
    return _logs
        .where((l) =>
            l.timestamp.year == date.year &&
            l.timestamp.month == date.month &&
            l.timestamp.day == date.day)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
}

class AuditLog {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String detail;
  final String sessionId;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.detail,
    required this.sessionId,
    required this.timestamp,
  });

  factory AuditLog.fromJson(Map<String, dynamic> j) => AuditLog(
        id: j['id'],
        userId: j['userId'],
        userName: j['userName'],
        action: j['action'],
        detail: j['detail'] ?? '',
        sessionId: j['sessionId'] ?? '',
        timestamp: DateTime.parse(j['timestamp']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'action': action,
        'detail': detail,
        'sessionId': sessionId,
        'timestamp': timestamp.toIso8601String(),
      };

  String get actionIcon {
    switch (action) {
      case 'login': return '🔑';
      case 'logout': return '🚪';
      case 'auto_logout': return '⏱️';
      case 'attendance': return '📷';
      case 'task_update': return '✅';
      case 'message_sent': return '💬';
      case 'mail_sent': return '📧';
      case 'notice_created': return '📢';
      default: return '📋';
    }
  }
}
