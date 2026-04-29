import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';
import '../../platform/file_picker.dart';
import '../../platform/camera.dart';
import '../../platform/platform_image.dart';
import '../../widgets/in_app_viewer.dart';

// ─────────────────────────────────────────────────────────────────
// Messages Screen — Conversation List
// ─────────────────────────────────────────────────────────────────
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Conversation> _convs = [];
  bool _loading = true;
  final _user = AuthService().currentUser!;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final c = await MessageService().getConversationsForUser(_user.roleId);
    if (mounted) setState(() { _convs = c; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.edit_square, color: AppColors.primary), onPressed: _newMessage),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _convs.isEmpty
              ? const Center(child: Text('No conversations yet', style: TextStyle(color: AppColors.textMuted)))
              : RefreshIndicator(
                  color: AppColors.primary, onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _convs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
                    itemBuilder: (ctx, i) => _convTile(_convs[i]),
                  ),
                ),
    );
  }

  Widget _convTile(Conversation conv) {
    final last = conv.messages.isNotEmpty ? conv.messages.last : null;
    String? subtitle;
    if (last != null) {
      final sender = last.senderId == _user.roleId ? 'You' : last.senderName;
      if (last.hasAttachment && last.text.isEmpty) {
        subtitle = '$sender: 📎 ${last.fileName}';
      } else {
        subtitle = '$sender: ${last.text}';
      }
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: conv.isGroup ? AppColors.primaryTint : AppColors.infoTint,
        child: Text(
          conv.isGroup ? conv.name.substring(0, 1) : conv.name.split(' ').first[0],
          style: TextStyle(
            color: conv.isGroup ? AppColors.primary : AppColors.info,
            fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      title: Text(conv.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
      subtitle: subtitle != null ? Text(subtitle,
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)) : null,
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_timeStr(conv.lastMessageTime), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        if (conv.isGroup) Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
          child: const Text('Group', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.primary))),
      ]),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(conv: conv, userId: _user.roleId, userName: _user.name))).then((_) => _load()),
    );
  }

  void _newMessage() {
    final employees = AuthService().employees.where((e) => e.roleId != _user.roleId).toList();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('New Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...employees.map((e) => ListTile(
            leading: CircleAvatar(radius: 20, backgroundColor: AppColors.primaryTint,
              child: Text(e.initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12))),
            title: Text(e.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('${e.role} · ${e.department}', style: const TextStyle(fontSize: 11)),
            onTap: () async {
              Navigator.of(context).pop();
              final conv = await MessageService().getOrCreateDirect(_user.roleId, _user.name, e.roleId, e.name);
              if (mounted) {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatScreen(conv: conv, userId: _user.roleId, userName: _user.name)));
                _load();
              }
            },
          )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  String _timeStr(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ─────────────────────────────────────────────────────────────────
// Chat Screen — Individual Conversation with File Sharing
// ─────────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  final Conversation conv;
  final String userId, userName;
  const ChatScreen({super.key, required this.conv, required this.userId, required this.userName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  late Conversation _conv;
  bool _sending = false;

  @override
  void initState() { super.initState(); _conv = widget.conv; _scrollToBottom(); }
  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  // ── Send text message ─────────────────────────────────────────
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    await MessageService().sendMessage(
      convId: _conv.id, senderId: widget.userId,
      senderName: widget.userName, text: text);
    final updated = await MessageService().getConversation(_conv.id);
    if (mounted && updated != null) {
      setState(() { _conv = updated; _sending = false; });
      _scrollToBottom();
    }
  }

  // ── Send file attachment ──────────────────────────────────────
  Future<void> _sendFile(String fileName, Uint8List fileBytes) async {
    setState(() => _sending = true);
    final fileType = _getFileType(fileName);
    final sizeLabel = _formatFileSize(fileBytes.length);
    final base64Data = base64Encode(fileBytes);

    await MessageService().sendMessage(
      convId: _conv.id,
      senderId: widget.userId,
      senderName: widget.userName,
      text: '',
      fileName: fileName,
      fileType: fileType,
      fileBase64: base64Data,
      fileSizeLabel: sizeLabel,
    );

    final updated = await MessageService().getConversation(_conv.id);
    if (mounted && updated != null) {
      setState(() { _conv = updated; _sending = false; });
      _scrollToBottom();
    }
  }

  // ── Attachment picker bottom sheet ────────────────────────────
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Share File',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Choose what you want to send',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _attachOption(
                icon: Icons.image_rounded,
                label: 'Image',
                color: const Color(0xFF4CAF50),
                bgColor: const Color(0xFFE8F5E9),
                onTap: () { Navigator.pop(context); _pickWebFile('image'); },
              ),
              _attachOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: const Color(0xFF2196F3),
                bgColor: const Color(0xFFE3F2FD),
                onTap: () { Navigator.pop(context); _openCamera(); },
              ),
              _attachOption(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF',
                color: const Color(0xFFF44336),
                bgColor: const Color(0xFFFFEBEE),
                onTap: () { Navigator.pop(context); _pickWebFile('pdf'); },
              ),
              _attachOption(
                icon: Icons.description_rounded,
                label: 'Document',
                color: const Color(0xFF3F51B5),
                bgColor: const Color(0xFFE8EAF6),
                onTap: () { Navigator.pop(context); _pickWebFile('document'); },
              ),
            ]),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _attachOption(
                icon: Icons.folder_zip_rounded,
                label: 'ZIP',
                color: const Color(0xFFFF9800),
                bgColor: const Color(0xFFFFF3E0),
                onTap: () { Navigator.pop(context); _pickWebFile('zip'); },
              ),
              _attachOption(
                icon: Icons.insert_drive_file_rounded,
                label: 'Any File',
                color: const Color(0xFF607D8B),
                bgColor: const Color(0xFFECEFF1),
                onTap: () { Navigator.pop(context); _pickWebFile('any'); },
              ),
              const SizedBox(width: 72), // spacer
              const SizedBox(width: 72), // spacer
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _attachOption({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  // ── File picking — cross-platform ──
  final _filePicker = PlatformFilePickerImpl();
  Future<void> _pickWebFile(String type) async {
    try {
      PickedFileData? picked;
      switch (type) {
        case 'image':
          picked = await _filePicker.pickImage();
          break;
        case 'pdf':
          picked = await _filePicker.pickPdf();
          break;
        case 'document':
          picked = await _filePicker.pickDocument();
          break;
        case 'zip':
          picked = await _filePicker.pickArchive();
          break;
        case 'any':
        default:
          picked = await _filePicker.pickAnyFile();
          break;
      }
      if (picked != null) {
        await _sendFile(picked.name, picked.bytes);
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _openCamera() async {
    try {
      final camera = PlatformCameraCaptureImpl();
      final bytes = await camera.capturePhoto(context);
      if (bytes != null) {
        final fileName = 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _sendFile(fileName, bytes);
      }
    } catch (e) {
      _showError('Failed to capture photo: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  // ── File type helpers ─────────────────────────────────────────
  String _getFileType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'].contains(ext)) return 'image';
    if (ext == 'pdf') return 'pdf';
    if (['doc', 'docx', 'txt', 'rtf', 'odt'].contains(ext)) return 'document';
    if (['xls', 'xlsx', 'csv'].contains(ext)) return 'spreadsheet';
    if (['ppt', 'pptx'].contains(ext)) return 'presentation';
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) return 'zip';
    return 'other';
  }

  IconData _getFileIcon(String? fileType) {
    switch (fileType) {
      case 'image': return Icons.image_rounded;
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'document': return Icons.description_rounded;
      case 'spreadsheet': return Icons.table_chart_rounded;
      case 'presentation': return Icons.slideshow_rounded;
      case 'zip': return Icons.folder_zip_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String? fileType) {
    switch (fileType) {
      case 'image': return const Color(0xFF4CAF50);
      case 'pdf': return const Color(0xFFF44336);
      case 'document': return const Color(0xFF3F51B5);
      case 'spreadsheet': return const Color(0xFF4CAF50);
      case 'presentation': return const Color(0xFFFF9800);
      case 'zip': return const Color(0xFFFF9800);
      default: return const Color(0xFF607D8B);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_conv.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          if (_conv.isGroup) Text('${_conv.participantIds.length} members',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: _conv.messages.length,
            itemBuilder: (_, i) => _bubble(_conv.messages[i]),
          ),
        ),
        // ── Input bar with attachment button ──────────────────
        Container(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(children: [
            // Attachment button
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _sending ? null : _showAttachmentOptions,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.bgSubtle,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.attach_file_rounded, color: AppColors.textMuted, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                filled: true,
                fillColor: AppColors.bgSubtle,
              ),
              onSubmitted: (_) => _send(),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(width: 44, height: 44,
                decoration: CardDecor.primary(borderRadius: 22),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Message bubble with attachment support ────────────────────
  Widget _bubble(ChatMessage msg) {
    final isMe = msg.senderId == widget.userId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(radius: 14, backgroundColor: AppColors.primaryTint,
              child: Text(msg.senderName[0], style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700))),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: EdgeInsets.all(msg.hasAttachment && msg.isImage ? 4 : 12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16)),
                boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!isMe && _conv.isGroup) Padding(
                  padding: EdgeInsets.only(
                    left: msg.hasAttachment && msg.isImage ? 8 : 0,
                    bottom: 4,
                  ),
                  child: Text(msg.senderName,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryMid)),
                ),

                // ── Attachment rendering ──────────────────────
                if (msg.hasAttachment) ...[
                  if (msg.isImage && msg.fileBase64 != null) ...[
                    // Inline image — use native HTML img for web compatibility
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => InAppViewer(
                            fileName: msg.fileName ?? 'image.jpg',
                            bytes: base64Decode(msg.fileBase64!),
                            fileType: msg.fileType ?? 'image/jpeg',
                          )));
                      },
                      child: PlatformImage(
                        bytes: base64Decode(msg.fileBase64!),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    if (msg.text.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Text(msg.text,
                          style: TextStyle(fontSize: 13, color: isMe ? Colors.white : AppColors.textPrimary, height: 1.4)),
                      ),
                    ],
                  ] else ...[
                    // File card (PDF, document, zip, etc.)
                    GestureDetector(
                      onTap: () {
                        if (msg.fileBase64 != null) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => InAppViewer(
                              fileName: msg.fileName ?? 'file',
                              bytes: base64Decode(msg.fileBase64!),
                              fileType: msg.fileType ?? 'unknown',
                            )));
                        }
                      },
                      child: _fileCard(msg, isMe),
                    ),
                    if (msg.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(msg.text,
                        style: TextStyle(fontSize: 13, color: isMe ? Colors.white : AppColors.textPrimary, height: 1.4)),
                    ],
                  ],
                ] else ...[
                  // Plain text message
                  Text(msg.text,
                    style: TextStyle(fontSize: 13, color: isMe ? Colors.white : AppColors.textPrimary, height: 1.4)),
                ],

                // Timestamp
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    left: msg.hasAttachment && msg.isImage ? 8 : 0,
                  ),
                  child: Text(_timeStr(msg.timestamp),
                    style: TextStyle(fontSize: 10, color: isMe ? Colors.white54 : AppColors.textMuted)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── File card widget ──────────────────────────────────────────
  Widget _fileCard(ChatMessage msg, bool isMe) {
    final fileColor = _getFileColor(msg.fileType);
    final icon = _getFileIcon(msg.fileType);
    final ext = msg.fileName?.split('.').last.toUpperCase() ?? 'FILE';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.15) : AppColors.bgSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? Colors.white.withValues(alpha: 0.2) : AppColors.border,
        ),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: fileColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: fileColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              msg.fileName ?? 'File',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: isMe ? Colors.white : AppColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${ext} · ${msg.fileSizeLabel ?? ""}',
              style: TextStyle(
                fontSize: 10, color: isMe ? Colors.white60 : AppColors.textMuted),
            ),
          ]),
        ),
        Icon(Icons.download_rounded, size: 20,
          color: isMe ? Colors.white70 : AppColors.textMuted),
      ]),
    );
  }

  String _timeStr(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
