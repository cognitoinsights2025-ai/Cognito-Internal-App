import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class MessageService {
  static final MessageService _i = MessageService._();
  factory MessageService() => _i;
  MessageService._();

  static const _convsKey = 'conversations';
  static const _msgsPrefix = 'messages_';
  final _uuid = const Uuid();

  final List<Conversation> _conversations = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_convsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _conversations.clear();
      _conversations.addAll(list.map((e) => Conversation.fromJson(e)));
    } else {
      _seedDefaults();
    }
    _loaded = true;
  }

  void _seedDefaults() {
    final now = DateTime.now();
    _conversations.addAll([
      Conversation(
        id: 'grp_all_staff', name: 'All Staff 🏢',
        participantIds: ['ADMIN', '2603IT01', '2603IT02', '2603IT03',
                         '2602NT01', '2602NT02', '2604NT03',
                         '2604IN01', '2604IN02', '2604IN03', '2604IN04', '2604IN05', '2604IN06'],
        isGroup: true, lastMessage: 'Welcome to Cognito Insights! 🎉',
        lastMessageTime: now.subtract(const Duration(hours: 1)),
        messages: [
          ChatMessage(id: _uuid.v4(), senderId: 'ADMIN', senderName: 'Admin',
            text: 'Welcome everyone to Cognito Insights! 🎉 Looking forward to working with you all.',
            timestamp: now.subtract(const Duration(hours: 1))),
        ],
      ),
      Conversation(
        id: 'grp_it', name: 'IT Team 💻',
        participantIds: ['ADMIN', '2603IT01', '2603IT02', '2603IT03'],
        isGroup: true, lastMessage: 'Dev environment setup done',
        lastMessageTime: now.subtract(const Duration(hours: 3)),
        messages: [
          ChatMessage(id: _uuid.v4(), senderId: 'ADMIN', senderName: 'Admin',
            text: 'Team, please set up your dev environments by tomorrow.',
            timestamp: now.subtract(const Duration(hours: 4))),
          ChatMessage(id: _uuid.v4(), senderId: '2603IT01', senderName: 'Satya',
            text: 'Dev environment setup done ✅',
            timestamp: now.subtract(const Duration(hours: 3))),
        ],
      ),
    ]);
  }

  Future<void> _saveConversations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_convsKey,
        jsonEncode(_conversations.map((c) => c.toJson()).toList()));
  }

  Future<List<Conversation>> getConversationsForUser(String userId) async {
    await _ensureLoaded();
    return _conversations
        .where((c) => c.participantIds.contains(userId))
        .toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
  }

  Future<Conversation?> getConversation(String convId) async {
    await _ensureLoaded();
    try {
      return _conversations.firstWhere((c) => c.id == convId);
    } catch (_) {
      return null;
    }
  }

  Future<Conversation> getOrCreateDirect(
      String userId1, String name1, String userId2, String name2) async {
    await _ensureLoaded();
    final existing = _conversations.where((c) =>
        !c.isGroup &&
        c.participantIds.contains(userId1) &&
        c.participantIds.contains(userId2)).toList();
    if (existing.isNotEmpty) return existing.first;

    final conv = Conversation(
      id: _uuid.v4(),
      name: name2,
      participantIds: [userId1, userId2],
      isGroup: false,
      lastMessage: '',
      lastMessageTime: DateTime.now(),
      messages: [],
    );
    _conversations.add(conv);
    await _saveConversations();
    return conv;
  }

  Future<ChatMessage> sendMessage({
    required String convId,
    required String senderId,
    required String senderName,
    required String text,
    String? fileName,
    String? fileType,
    String? fileBase64,
    String? fileSizeLabel,
  }) async {
    await _ensureLoaded();
    final idx = _conversations.indexWhere((c) => c.id == convId);
    if (idx == -1) throw Exception('Conversation not found');
    final msg = ChatMessage(
      id: _uuid.v4(), senderId: senderId,
      senderName: senderName, text: text,
      timestamp: DateTime.now(),
      fileName: fileName,
      fileType: fileType,
      fileBase64: fileBase64,
      fileSizeLabel: fileSizeLabel,
    );
    _conversations[idx].messages.add(msg);

    // Build last message preview
    String lastMsgPreview = text;
    if (fileName != null && text.isEmpty) {
      lastMsgPreview = '📎 $fileName';
    } else if (fileName != null) {
      lastMsgPreview = '📎 $text';
    }

    _conversations[idx] = _conversations[idx].copyWith(
      lastMessage: lastMsgPreview, lastMessageTime: msg.timestamp,
    );
    await _saveConversations();
    return msg;
  }
}

class Conversation {
  final String id, name, lastMessage;
  final List<String> participantIds;
  final List<ChatMessage> messages;
  final bool isGroup;
  final DateTime lastMessageTime;

  Conversation({
    required this.id, required this.name,
    required this.participantIds, required this.messages,
    required this.isGroup, required this.lastMessage,
    required this.lastMessageTime,
  });

  Conversation copyWith({String? lastMessage, DateTime? lastMessageTime}) =>
      Conversation(
        id: id, name: name,
        participantIds: participantIds, messages: messages,
        isGroup: isGroup,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      );

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'], name: j['name'],
        participantIds: List<String>.from(j['participantIds']),
        isGroup: j['isGroup'],
        lastMessage: j['lastMessage'] ?? '',
        lastMessageTime: DateTime.parse(j['lastMessageTime']),
        messages: (j['messages'] as List? ?? [])
            .map((m) => ChatMessage.fromJson(m)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name,
        'participantIds': participantIds, 'isGroup': isGroup,
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}

class ChatMessage {
  final String id, senderId, senderName, text;
  final DateTime timestamp;
  bool isRead;

  // File attachment fields (optional)
  final String? fileName;
  final String? fileType;     // 'image', 'pdf', 'document', 'zip', 'other'
  final String? fileBase64;   // base64-encoded file data
  final String? fileSizeLabel; // e.g. "2.4 MB"

  bool get hasAttachment => fileName != null && fileName!.isNotEmpty;
  bool get isImage => fileType == 'image';

  ChatMessage({
    required this.id, required this.senderId,
    required this.senderName, required this.text,
    required this.timestamp, this.isRead = false,
    this.fileName, this.fileType, this.fileBase64, this.fileSizeLabel,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'], senderId: j['senderId'],
        senderName: j['senderName'], text: j['text'],
        timestamp: DateTime.parse(j['timestamp']),
        isRead: j['isRead'] ?? false,
        fileName: j['fileName'],
        fileType: j['fileType'],
        fileBase64: j['fileBase64'],
        fileSizeLabel: j['fileSizeLabel'],
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'senderId': senderId, 'senderName': senderName,
        'text': text, 'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'fileName': fileName,
        'fileType': fileType,
        'fileBase64': fileBase64,
        'fileSizeLabel': fileSizeLabel,
      };
}
