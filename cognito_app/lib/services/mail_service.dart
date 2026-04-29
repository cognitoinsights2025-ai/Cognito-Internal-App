import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class MailService {
  static final MailService _i = MailService._();
  factory MailService() => _i;
  MailService._();

  static const _key = 'mails';
  final _uuid = const Uuid();
  final List<Mail> _mails = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _mails.clear();
      _mails.addAll(list.map((e) => Mail.fromJson(e)));
    } else {
      _seedDefaults();
    }
    _loaded = true;
  }

  void _seedDefaults() {
    final now = DateTime.now();
    _mails.addAll([
      Mail(
        id: _uuid.v4(), fromId: 'ADMIN', fromName: 'Admin',
        toIds: ['2603IT01'], toNames: ['Satya'],
        subject: 'Welcome to Cognito Insights — IT Team Lead',
        body: 'Dear Satya,\n\nWelcome to Cognito Insights Solutions Pvt Ltd! We are thrilled to have you as our Tech Lead.\n\nPlease complete your onboarding documentation by this week and set up your development environment as per the guidelines shared.\n\nBest regards,\nAdmin — Cognito Insights',
        sentAt: now.subtract(const Duration(hours: 2)), isRead: false,
      ),
      Mail(
        id: _uuid.v4(), fromId: 'ADMIN', fromName: 'Admin',
        toIds: ['2603IT01', '2603IT02', '2603IT03'], toNames: ['Satya', 'Bharathi', 'Teja'],
        subject: 'IT Department — Project Kickoff Meeting',
        body: 'Dear IT Team,\n\nWe will be having our first project kickoff meeting on April 30, 2026 at 10:00 AM in the conference room.\n\nPlease come prepared with your initial plan and any questions you may have.\n\nRegards,\nAdmin',
        sentAt: now.subtract(const Duration(hours: 5)), isRead: false,
      ),
      Mail(
        id: _uuid.v4(), fromId: 'ADMIN', fromName: 'Admin',
        toIds: ['2604NT03'], toNames: ['Keerthi'],
        subject: 'Social Media Strategy — Action Required',
        body: 'Dear Keerthi,\n\nPlease prepare the social media content calendar for May 2026 and submit it by April 28, 2026.\n\nFocus on LinkedIn, Instagram, and Twitter. Include post ideas, captions, and scheduling.\n\nThanks,\nAdmin',
        sentAt: now.subtract(const Duration(days: 1)), isRead: true,
      ),
    ]);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_mails.map((m) => m.toJson()).toList()));
  }

  Future<List<Mail>> getInbox(String userId) async {
    await _ensureLoaded();
    return _mails
        .where((m) => m.toIds.contains(userId))
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
  }

  Future<List<Mail>> getSent(String userId) async {
    await _ensureLoaded();
    return _mails
        .where((m) => m.fromId == userId)
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
  }

  Future<Mail> compose({
    required String fromId, required String fromName,
    required List<String> toIds, required List<String> toNames,
    required String subject, required String body,
  }) async {
    await _ensureLoaded();
    final mail = Mail(
      id: _uuid.v4(), fromId: fromId, fromName: fromName,
      toIds: toIds, toNames: toNames,
      subject: subject, body: body,
      sentAt: DateTime.now(), isRead: false,
    );
    _mails.insert(0, mail);
    await _save();
    return mail;
  }

  Future<void> markRead(String mailId) async {
    await _ensureLoaded();
    final idx = _mails.indexWhere((m) => m.id == mailId);
    if (idx != -1) {
      _mails[idx] = _mails[idx].copyWith(isRead: true);
      await _save();
    }
  }

  Future<int> getUnreadCount(String userId) async {
    await _ensureLoaded();
    return _mails.where((m) => m.toIds.contains(userId) && !m.isRead).length;
  }
}

class Mail {
  final String id, fromId, fromName, subject, body;
  final List<String> toIds, toNames;
  final DateTime sentAt;
  final bool isRead;

  Mail({
    required this.id, required this.fromId, required this.fromName,
    required this.toIds, required this.toNames,
    required this.subject, required this.body,
    required this.sentAt, this.isRead = false,
  });

  Mail copyWith({bool? isRead}) => Mail(
    id: id, fromId: fromId, fromName: fromName,
    toIds: toIds, toNames: toNames,
    subject: subject, body: body, sentAt: sentAt,
    isRead: isRead ?? this.isRead,
  );

  factory Mail.fromJson(Map<String, dynamic> j) => Mail(
    id: j['id'], fromId: j['fromId'], fromName: j['fromName'],
    toIds: List<String>.from(j['toIds']),
    toNames: List<String>.from(j['toNames']),
    subject: j['subject'], body: j['body'],
    sentAt: DateTime.parse(j['sentAt']), isRead: j['isRead'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'fromId': fromId, 'fromName': fromName,
    'toIds': toIds, 'toNames': toNames,
    'subject': subject, 'body': body,
    'sentAt': sentAt.toIso8601String(), 'isRead': isRead,
  };
}
