import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../services/attendance_service.dart';
import '../../services/notice_service.dart';
import '../../services/mail_service.dart';
import '../mail/mail_screen.dart';
import '../attendance/attendance_screen.dart';
import '../documents/documents_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});
  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final _auth = AuthService();
  List<TaskModel> _myTasks = [];
  List<Notice> _notices = [];
  bool _attendanceDone = false;
  int _presentDays = 0;
  int _unreadMails = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final user = _auth.currentUser!;
    final tasks = await TaskService().getTasksForUser(user.roleId);
    final notices = await NoticeService().getAll();
    final att = await AttendanceService().isAttendanceDoneToday(user.roleId);
    final days = await AttendanceService().getPresentCountThisMonth(user.roleId);
    final mails = await MailService().getUnreadCount(user.roleId);
    if (!mounted) return;
    setState(() {
      _myTasks = tasks; _notices = notices.take(3).toList();
      _attendanceDone = att; _presentDays = days;
      _unreadMails = mails; _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pending = _myTasks.where((t) => t.status == TaskStatus.pending).length;
    final inProg = _myTasks.where((t) => t.status == TaskStatus.inProgress).length;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async { setState(() => _loading = true); await _loadData(); },
        child: CustomScrollView(slivers: [
          SliverAppBar(
            floating: true, snap: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 64,
            title: Image.asset('assets/images/logo.png', height: 36, fit: BoxFit.contain),
            actions: [
              Stack(children: [
                IconButton(
                  icon: const Icon(Icons.mail_outline_rounded, color: AppColors.textSecondary),
                  onPressed: () => _push(context, const MailScreen())),
                if (_unreadMails > 0) Positioned(right: 8, top: 8,
                  child: Container(width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: Center(child: Text('$_unreadMails',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))))),
              ]),
              IconButton(
                icon: const Icon(Icons.folder_outlined, color: AppColors.textSecondary),
                onPressed: () => _push(context, const DocumentsScreen())),
              const SizedBox(width: 4),
            ],
          ),

          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(delegate: SliverChildListDelegate([
                // Greeting
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: CardDecor.primary(borderRadius: 16),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_greeting(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('${user.name} 👋',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${user.role} · ${user.department}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ])),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: user.photoAsset != null
                          ? Image.asset(user.photoAsset!, width: 56, height: 56, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 56, height: 56,
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14)),
                                child: Center(child: Text(user.initials,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)))))
                          : Container(width: 56, height: 56,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14)),
                              child: Center(child: Text(user.initials,
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)))),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                // Attendance status
                GestureDetector(
                  onTap: () => _push(context, const AttendanceScreen()),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _attendanceDone ? AppColors.successTint : AppColors.warningTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_attendanceDone ? AppColors.success : AppColors.warning).withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(_attendanceDone ? Icons.check_circle_rounded : Icons.camera_alt_rounded,
                        color: _attendanceDone ? AppColors.success : AppColors.warning, size: 22),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_attendanceDone ? 'Attendance Marked Today ✓' : 'Attendance Not Marked Yet',
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: _attendanceDone ? AppColors.success : AppColors.warning)),
                        Text('Present this month: $_presentDays days',
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                      ])),
                      if (!_attendanceDone)
                        const Icon(Icons.chevron_right_rounded, color: AppColors.warning),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Task Summary
                const Text('My Tasks', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Row(children: [
                  _taskStat('Pending', pending, AppColors.warningTint, AppColors.warning),
                  const SizedBox(width: 10),
                  _taskStat('In Progress', inProg, AppColors.infoTint, AppColors.info),
                  const SizedBox(width: 10),
                  _taskStat('Done', _myTasks.where((t) => t.status == TaskStatus.done).length, AppColors.successTint, AppColors.success),
                ]),
                const SizedBox(height: 16),

                // Today's tasks
                if (_myTasks.isNotEmpty) ...[
                  const Text("Today's Priority", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  ..._myTasks.where((t) => t.status != TaskStatus.done).take(3).map((task) => _taskCard(task)),
                ],
                const SizedBox(height: 16),

                // Recent Notices
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Notices', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  TextButton(onPressed: () {}, child: const Text('See all')),
                ]),
                const SizedBox(height: 8),
                ..._notices.map((n) => _noticeCard(n)),

                const SizedBox(height: 100),
              ])),
            ),
        ]),
      ),
    );
  }

  void _push(BuildContext ctx, Widget w) => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => w));

  Widget _taskStat(String label, int count, Color bg, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(children: [
          Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _taskCard(TaskModel task) {
    final colors = {
      TaskPriority.high: [AppColors.roseTint, AppColors.rose],
      TaskPriority.medium: [AppColors.warningTint, AppColors.warning],
      TaskPriority.low: [AppColors.successTint, AppColors.success],
    };
    final c = colors[task.priority]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: CardDecor.standard(),
      child: Row(children: [
        Container(width: 6, height: 40, decoration: BoxDecoration(
          color: c[1], borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('Due: ${_fmtDate(task.dueDate)}',
            style: TextStyle(fontSize: 11, color: task.isOverdue ? AppColors.error : AppColors.textMuted)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: c[0], borderRadius: BorderRadius.circular(20)),
          child: Text(task.priorityLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c[1]))),
      ]),
    );
  }

  Widget _noticeCard(Notice n) {
    final typeColors = {
      NoticeType.general: [AppColors.infoTint, AppColors.info],
      NoticeType.urgent: [AppColors.roseTint, AppColors.rose],
      NoticeType.policy: [AppColors.warningTint, AppColors.warning],
      NoticeType.holiday: [AppColors.successTint, AppColors.success],
    };
    final c = typeColors[n.type]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: CardDecor.standard(),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (n.isPinned) const Padding(padding: EdgeInsets.only(right: 6, top: 2),
          child: Icon(Icons.push_pin_rounded, size: 14, color: AppColors.warning)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        ])),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: c[0], borderRadius: BorderRadius.circular(20)),
          child: Text(n.typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c[1]))),
      ]),
    );
  }

  String _greeting() { final h = DateTime.now().hour; return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening'; }
  String _fmtDate(DateTime d) { const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']; return '${m[d.month-1]} ${d.day}'; }
}
