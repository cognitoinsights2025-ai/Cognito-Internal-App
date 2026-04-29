import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/notice_service.dart';
import '../../services/auth_service.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});
  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen>  {
  List<Notice> _notices = [];
  bool _loading = true;
  final _isAdmin = AuthService().currentUser?.isAdmin ?? false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final n = await NoticeService().getAll();
    if (mounted) setState(() { _notices = n; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Notices & Announcements'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: _isAdmin ? FloatingActionButton.extended(
        heroTag: 'fab_notices',
        onPressed: _showCreateNotice,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Post Notice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ) : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: _notices.isEmpty
                  ? const Center(child: Text('No notices yet', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _notices.length,
                      itemBuilder: (ctx, i) => _card(_notices[i]),
                    ),
            ),
    );
  }

  final _typeConfig = {
    NoticeType.general: {'color': AppColors.info, 'bg': AppColors.infoTint, 'icon': Icons.info_outline_rounded},
    NoticeType.urgent: {'color': AppColors.rose, 'bg': AppColors.roseTint, 'icon': Icons.warning_amber_rounded},
    NoticeType.policy: {'color': AppColors.warning, 'bg': AppColors.warningTint, 'icon': Icons.policy_outlined},
    NoticeType.holiday: {'color': AppColors.success, 'bg': AppColors.successTint, 'icon': Icons.beach_access_rounded},
  };

  Widget _card(Notice n) {
    final cfg = _typeConfig[n.type]!;
    final color = cfg['color'] as Color;
    final bg = cfg['bg'] as Color;
    final icon = cfg['icon'] as IconData;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: n.isPinned ? color.withValues(alpha: 0.3) : AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text(n.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            if (n.isPinned) const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.warning),
            if (_isAdmin) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'pin', child: Row(children: [Icon(Icons.push_pin_outlined, size: 16), SizedBox(width: 8), Text('Toggle Pin')])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: AppColors.error), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.error))])),
                ],
                onSelected: (v) async {
                  if (v == 'delete') { await NoticeService().delete(n.id); _load(); }
                  else if (v == 'pin') { await NoticeService().togglePin(n.id); _load(); }
                },
                child: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textMuted),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          Text(n.body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 10),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
              child: Text(n.typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color))),
            const Spacer(),
            Text('Posted by ${n.postedBy} · ${_timeAgo(n.createdAt)}',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ]),
        ]),
      ),
    );
  }

  void _showCreateNotice() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    NoticeType type = NoticeType.general;
    bool pinned = false;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Post New Notice', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: 'Notice Title', labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: bodyCtrl, maxLines: 4, decoration: const InputDecoration(hintText: 'Write the notice here...', labelText: 'Message')),
            const SizedBox(height: 12),
            DropdownButtonFormField<NoticeType>(
              value: type,
              items: NoticeType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name[0].toUpperCase() + t.name.substring(1)))).toList(),
              onChanged: (v) => setSt(() => type = v!),
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Checkbox(value: pinned, onChanged: (v) => setSt(() => pinned = v!), activeColor: AppColors.primary),
              const Text('Pin this notice', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
                  await NoticeService().create(title: titleCtrl.text, body: bodyCtrl.text, type: type, postedBy: 'Admin', isPinned: pinned);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _load();
                },
                child: const Text('Post Notice'),
              )),
            const SizedBox(height: 8),
          ]),
        ),
      )),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
