import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/mail_service.dart';
import '../../services/auth_service.dart';

class MailScreen extends StatefulWidget {
  const MailScreen({super.key});
  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Mail> _inbox = [], _sent = [];
  bool _loading = true;
  final _user = AuthService().currentUser!;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    final inbox = await MailService().getInbox(_user.roleId);
    final sent = await MailService().getSent(_user.roleId);
    if (mounted) setState(() { _inbox = inbox; _sent = sent; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Internal Mail'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Inbox (${_inbox.where((m) => !m.isRead).length} unread)'),
            Tab(text: 'Sent (${_sent.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: _compose),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabs,
              children: [_mailList(_inbox, isInbox: true), _mailList(_sent, isInbox: false)],
            ),
    );
  }

  Widget _mailList(List<Mail> mails, {required bool isInbox}) {
    if (mails.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(isInbox ? Icons.inbox_rounded : Icons.outbox_rounded, size: 48, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text(isInbox ? 'Your inbox is empty' : 'No sent mails',
          style: const TextStyle(color: AppColors.textMuted)),
      ],
    ));
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: mails.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (ctx, i) => _mailTile(mails[i], isInbox: isInbox),
    );
  }

  Widget _mailTile(Mail mail, {required bool isInbox}) {
    final unread = isInbox && !mail.isRead;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: unread ? AppColors.primaryTint : AppColors.bgSubtle,
        child: Text(
          isInbox ? mail.fromName[0] : (mail.toNames.isNotEmpty ? mail.toNames.first[0] : '?'),
          style: TextStyle(
            color: unread ? AppColors.primary : AppColors.textTertiary,
            fontWeight: FontWeight.w700))),
      title: Text(isInbox ? mail.fromName : 'To: ${mail.toNames.join(", ")}',
        style: TextStyle(fontSize: 13, fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
          color: AppColors.textPrimary)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(mail.subject, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
            color: unread ? AppColors.textSecondary : AppColors.textTertiary)),
        Text(mail.body, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_timeStr(mail.sentAt), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        if (unread) Container(margin: const EdgeInsets.only(top: 4), width: 8, height: 8,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
      ]),
      onTap: () async {
        if (isInbox && !mail.isRead) {
          await MailService().markRead(mail.id);
          _load();
        }
        if (mounted) _showMail(mail, isInbox: isInbox);
      },
    );
  }

  void _showMail(Mail mail, {required bool isInbox}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.75, maxChildSize: 0.95,
        builder: (ctx, sc) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(controller: sc, children: [
            Row(children: [
              Expanded(child: Text(mail.subject, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              CircleAvatar(radius: 20, backgroundColor: AppColors.primaryTint,
                child: Text(mail.fromName[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mail.fromName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('To: ${mail.toNames.join(", ")}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]),
              const Spacer(),
              Text(_timeStr(mail.sentAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ]),
            const Divider(height: 24),
            Text(mail.body, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.7)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () { Navigator.of(ctx).pop(); _composeReply(mail); },
              icon: const Icon(Icons.reply_rounded, size: 18),
              label: const Text('Reply'),
            ),
          ]),
        ),
      ),
    );
  }

  void _compose() {
    final employees = AuthService().employees;
    final subCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    List<String> selectedIds = [];
    List<String> selectedNames = [];
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('New Mail', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            const Text('To:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              ...selectedNames.map((n) => Chip(label: Text(n, style: const TextStyle(fontSize: 11)),
                onDeleted: () {
                  final i = selectedNames.indexOf(n);
                  setSt(() { selectedNames.removeAt(i); selectedIds.removeAt(i); });
                })),
              ActionChip(
                label: const Text('+ Add', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  showDialog(context: ctx, builder: (_) => SimpleDialog(
                    title: const Text('Select Recipients'),
                    children: employees.where((e) => !selectedIds.contains(e.roleId)).map((e) =>
                      SimpleDialogOption(onPressed: () {
                        setSt(() { selectedIds.add(e.roleId); selectedNames.add(e.name); });
                        Navigator.of(ctx).pop();
                      }, child: Text(e.name))).toList(),
                  ));
                }),
            ]),
            const SizedBox(height: 10),
            TextField(controller: subCtrl, decoration: const InputDecoration(labelText: 'Subject', hintText: 'Enter subject...')),
            const SizedBox(height: 10),
            TextField(controller: bodyCtrl, maxLines: 5, decoration: const InputDecoration(labelText: 'Message', hintText: 'Type your message here...')),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (selectedIds.isEmpty || subCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
                  await MailService().compose(fromId: _user.roleId, fromName: _user.name,
                    toIds: selectedIds, toNames: selectedNames, subject: subCtrl.text, body: bodyCtrl.text);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _load();
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send'),
              )),
            const SizedBox(height: 8),
          ]),
        ),
      )),
    );
  }

  void _composeReply(Mail original) {
    final bodyCtrl = TextEditingController(text: '\n\n--- Original ---\n${original.body}');
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Re: ${original.subject}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: bodyCtrl, maxLines: 6, decoration: const InputDecoration(labelText: 'Message')),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await MailService().compose(fromId: _user.roleId, fromName: _user.name,
                    toIds: [original.fromId], toNames: [original.fromName],
                    subject: 'Re: ${original.subject}', body: bodyCtrl.text);
                  if (mounted) Navigator.of(context).pop();
                  _load();
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send Reply'),
              )),
          ]),
        ),
      ));
  }

  String _timeStr(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inHours < 24) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${mo[t.month-1]} ${t.day}';
  }
}
