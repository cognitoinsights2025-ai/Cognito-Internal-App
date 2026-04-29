import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceService {
  static final AttendanceService _i = AttendanceService._();
  factory AttendanceService() => _i;
  AttendanceService._();

  static const _prefix = 'att_';
  static const _allKey = 'attendance_records';
  final List<AttendanceRecord> _records = [];
  bool _loaded = false;

  String _todayKey(String userId) {
    final d = DateTime.now();
    return '$_prefix${userId}_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<bool> isAttendanceDoneToday(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_todayKey(userId)) ?? false;
  }

  Future<void> markAttendance({
    required String userId,
    required String userName,
    String? photoPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _todayKey(userId);
    await prefs.setBool(key, true);

    await _ensureLoaded();
    final today = DateTime.now();

    // Enforce 9 AM to 5 PM window
    // (If outside this window, we can still record it but maybe UI handles warning)
    // Or we just allow marking anytime but record the timestamp

    // Find if we already have a record for today
    final existingIdx = _records.indexWhere((r) =>
        r.userId == userId &&
        r.date.year == today.year &&
        r.date.month == today.month &&
        r.date.day == today.day);

    if (existingIdx >= 0) {
      final existing = _records[existingIdx];
      // Prevent rapid duplicate marks within 1 minute
      if (today.difference(existing.logins.last).inMinutes > 1) {
        existing.logins.add(today);
      }
    } else {
      _records.insert(0, AttendanceRecord(
        userId: userId,
        userName: userName,
        date: today,
        logins: [today],
        photoPath: photoPath ?? '',
        isPresent: true,
      ));
    }
    await _saveRecords();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_allKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _records.clear();
      _records.addAll(list.map((e) => AttendanceRecord.fromJson(e)));
    }
    _loaded = true;
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_allKey,
        jsonEncode(_records.map((r) => r.toJson()).toList()));
  }

  Future<List<AttendanceRecord>> getRecordsForUser(String userId) async {
    await _ensureLoaded();
    return _records.where((r) => r.userId == userId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<AttendanceRecord>> getAllTodayRecords() async {
    await _ensureLoaded();
    final today = DateTime.now();
    return _records.where((r) =>
        r.date.year == today.year &&
        r.date.month == today.month &&
        r.date.day == today.day).toList();
  }

  Future<List<AttendanceRecord>> getAll() async {
    await _ensureLoaded();
    return List.from(_records)..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Returns how many days present this month for a user
  Future<int> getPresentCountThisMonth(String userId) async {
    await _ensureLoaded();
    final now = DateTime.now();
    return _records.where((r) =>
        r.userId == userId &&
        r.date.year == now.year &&
        r.date.month == now.month &&
        r.isPresent).length;
  }

  /// Returns all attendance records for a specific date.
  Future<List<AttendanceRecord>> getRecordsForDate(DateTime date) async {
    await _ensureLoaded();
    return _records
        .where((r) =>
            r.date.year == date.year &&
            r.date.month == date.month &&
            r.date.day == date.day)
        .toList()
      ..sort((a, b) => a.logins.first.compareTo(b.logins.first));
  }

  /// Returns a map of {day → present count} for a given year-month.
  Future<Map<int, int>> getMonthlyPresenceCounts(
      int year, int month, List<String> allEmployeeIds) async {
    await _ensureLoaded();
    final Map<int, int> result = {};
    final relevant = _records.where(
        (r) => r.date.year == year && r.date.month == month && r.isPresent);
    for (final r in relevant) {
      result[r.date.day] = (result[r.date.day] ?? 0) + 1;
    }
    return result;
  }
}

class AttendanceRecord {
  final String userId, userName, photoPath;
  final DateTime date;
  final List<DateTime> logins;
  final bool isPresent;

  AttendanceRecord({
    required this.userId, required this.userName,
    required this.date, required this.logins,
    required this.photoPath, required this.isPresent,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) {
    List<DateTime> parsedLogins;
    if (j['logins'] != null) {
      parsedLogins = (j['logins'] as List).map((e) => DateTime.parse(e)).toList();
    } else {
      parsedLogins = [DateTime.parse(j['clockIn'])]; // backward compatibility
    }
    
    return AttendanceRecord(
      userId: j['userId'], userName: j['userName'],
      date: DateTime.parse(j['date']), logins: parsedLogins,
      photoPath: j['photoPath'] ?? '', isPresent: j['isPresent'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId, 'userName': userName,
    'date': date.toIso8601String(), 'logins': logins.map((e) => e.toIso8601String()).toList(),
    'photoPath': photoPath, 'isPresent': isPresent,
  };

  String get clockInFormatted {
    if (logins.isEmpty) return '--:--';
    final first = logins.first;
    final h = first.hour.toString().padLeft(2, '0');
    final m = first.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get clockOutFormatted {
    if (logins.length <= 1) return '--:--';
    final last = logins.last;
    final h = last.hour.toString().padLeft(2, '0');
    final m = last.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  
  bool get isOutsideWindow {
    if (logins.isEmpty) return false;
    final first = logins.first;
    return first.hour < 9 || first.hour >= 17; // 9 AM to 5 PM
  }
}
