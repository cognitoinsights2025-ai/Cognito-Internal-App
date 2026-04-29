import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/audit_service.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});
  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<AuditLog> _logs = [];
  List<AuditLog> _filtered = [];
  bool _loading = true;
  String _filterAction = 'All';
  String _filterUser = 'All';

  final _actions = ['All', 'login', 'logout', 'auto_logout', 'attendance', 'task_update', 'message_sent', 'mail_sent', 'notice_created'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final logs = await AuditService().getAllLogs();
    if (mounted) setState(() { _logs = logs; _applyFilter(); _loading = false; });
  }

  void _applyFilter() {
    _filtered = _logs.where((l) {
      final matchAction = _filterAction == 'All' || l.action == _filterAction;
      final matchUser = _filterUser == 'All' || l.userId == _filterUser;
      return matchAction && matchUser;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final employees = [const UserData(name: 'All', displayName: 'All Users', email: '', password: '', roleId: 'All', role: '', department: '', phone: '', place: '', address: '', bloodGroup: '', companyNumber: '', dateOfJoining: ''), ...AuthService().employees];
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Audit Logs'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: AppColors.primary), onPressed: _load),
        ],
      ),
      body: Column(children: [
        // Filters
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: _filterAction,
              items: _actions.map((a) => DropdownMenuItem(value: a, child: Text(a == 'All' ? 'All Actions' : a, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() { _filterAction = v!; _applyFilter(); }),
              decoration: const InputDecoration(labelText: 'Action', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              isDense: true,
            )),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(
              value: _filterUser,
              items: employees.map((e) => DropdownMenuItem(value: e.roleId, child: Text(e.roleId == 'All' ? 'All Users' : e.name.split(' ').first, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() { _filterUser = v!; _applyFilter(); }),
              decoration: const InputDecoration(labelText: 'User', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              isDense: true,
            )),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Text('${_filtered.length} entries', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const Spacer(),
            if (_logs.isEmpty)
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.warningTint, borderRadius: BorderRadius.circular(20)),
                child: const Text('No logs yet — log in with employees to see activity',
                  style: TextStyle(fontSize: 11, color: AppColors.warning))),
          ]),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _filtered.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(_logs.isEmpty ? 'No logs yet. Activity will appear here once employees start using the app.' : 'No logs match your filter.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
                      ],
                    ))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _logTile(_filtered[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _logTile(AuditLog log) {
    final actionColors = {
      'login': [AppColors.successTint, AppColors.success],
      'logout': [AppColors.bgSubtle, AppColors.textTertiary],
      'auto_logout': [AppColors.warningTint, AppColors.warning],
      'attendance': [AppColors.infoTint, AppColors.info],
      'task_update': [AppColors.purpleTint, AppColors.purple],
      'message_sent': [AppColors.cyanTint, AppColors.cyan],
      'mail_sent': [AppColors.primaryTint, AppColors.primary],
      'notice_created': [AppColors.amberTint, AppColors.amber],
    };
    final c = actionColors[log.action] ?? [AppColors.bgSubtle, AppColors.textTertiary];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Container(width: 36, height: 36,
        decoration: BoxDecoration(color: c[0], borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(log.actionIcon, style: const TextStyle(fontSize: 16)))),
      title: Row(children: [
        Expanded(child: Text(log.userName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        Text(_fmtTime(log.timestamp), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]),
      subtitle: Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: c[0], borderRadius: BorderRadius.circular(20)),
          child: Text(log.action, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c[1]))),
        if (log.detail.isNotEmpty) ...[
          const SizedBox(width: 6),
          Expanded(child: Text(log.detail, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), overflow: TextOverflow.ellipsis)),
        ],
      ]),
    );
  }

  String _fmtTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '${mo[t.month-1]} ${t.day} $h:$m';
  }
}
