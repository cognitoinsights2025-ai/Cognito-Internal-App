import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../services/attendance_service.dart';
import '../../services/notice_service.dart';
import '../../services/audit_service.dart';
import '../../services/mail_service.dart';
import '../notices/notices_screen.dart';
import '../mail/mail_screen.dart';
import '../attendance/attendance_screen.dart';
import '../documents/documents_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _taskService = TaskService();
  final _attendanceService = AttendanceService();
  final _noticeService = NoticeService();
  final _auditService = AuditService();
  final _mailService = MailService();
  final _auth = AuthService();

  List<AttendanceRecord> _todayAttendance = [];
  Map<String, int> _taskCounts = {};
  List<AuditLog> _recentLogs = [];
  int _unreadMails = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final att = await _attendanceService.getAllTodayRecords();
    final tasks = await _taskService.getAllTasks();
    final logs = await _auditService.getAllLogs();
    final mails = await _mailService.getUnreadCount('ADMIN');
    if (!mounted) return;
    setState(() {
      _todayAttendance = att;
      _taskCounts = {
        'total': tasks.length,
        'pending': tasks.where((t) => t.status == TaskStatus.pending).length,
        'inProgress': tasks.where((t) => t.status == TaskStatus.inProgress).length,
        'done': tasks.where((t) => t.status == TaskStatus.done).length,
      };
      _recentLogs = logs.take(5).toList();
      _unreadMails = mails;
      _loading = false;
    });
  }

  final _employees = AuthService().employees;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser!;
    final totalEmp = _employees.length;
    final presentToday = _todayAttendance.length;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async { setState(() => _loading = true); await _loadData(); },
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true, snap: true, pinned: false,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 64,
              title: Row(children: [
                Image.asset('assets/images/logo.png', height: 36, fit: BoxFit.contain),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Admin Dashboard',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(user.name, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
              ]),
              actions: [
                Stack(children: [
                  IconButton(
                    icon: const Icon(Icons.mail_outline_rounded, color: AppColors.textSecondary),
                    onPressed: () => _openDrawerItem(context, const MailScreen())),
                  if (_unreadMails > 0) Positioned(right: 8, top: 8,
                    child: Container(width: 16, height: 16,
                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      child: Center(child: Text('$_unreadMails',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))))),
                ]),
                IconButton(
                  icon: const Icon(Icons.folder_outlined, color: AppColors.textSecondary),
                  onPressed: () => _openDrawerItem(context, const DocumentsScreen())),
                const SizedBox(width: 4),
              ],
            ),

            if (_loading)
              const SliverFillRemaining(child: Center(
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
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
                        Text('Today: ${_dateStr()}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ])),
                      Container(width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                        child: Center(child: Text(user.initials,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)))),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Quick Actions
                  _sectionTitle('Quick Actions'),
                  const SizedBox(height: 10),
                  Row(children: [
                    _quickAction(Icons.person_add_rounded, 'Add Employee', AppColors.primaryTint, AppColors.primary,
                      () => Navigator.of(context).pushNamed('/employees')),
                    const SizedBox(width: 10),
                    _quickAction(Icons.add_task_rounded, 'Create Task', AppColors.successTint, AppColors.success,
                      () => Navigator.of(context).pushNamed('/admin-tasks')),
                    const SizedBox(width: 10),
                    _quickAction(Icons.campaign_rounded, 'Post Notice', AppColors.warningTint, AppColors.warning,
                      () => _openDrawerItem(context, const NoticesScreen())),
                    const SizedBox(width: 10),
                    _quickAction(Icons.how_to_reg_rounded, 'Attendance', AppColors.purpleTint, AppColors.purple,
                      () => _openDrawerItem(context, const AttendanceScreen())),
                  ]),
                  const SizedBox(height: 20),

                  // Stat Cards
                  _sectionTitle('Overview'),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2, shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10, mainAxisSpacing: 10,
                    childAspectRatio: 1.6,
                    children: [
                      _statCard('Total Staff', '$totalEmp', Icons.people_rounded,
                        AppColors.primaryTint, AppColors.primary),
                      _statCard('Present Today', '$presentToday', Icons.check_circle_rounded,
                        AppColors.successTint, AppColors.success),
                      _statCard('Tasks Pending', '${_taskCounts['pending'] ?? 0}',
                        Icons.pending_actions_rounded, AppColors.warningTint, AppColors.warning),
                      _statCard('Tasks Done', '${_taskCounts['done'] ?? 0}',
                        Icons.task_alt_rounded, AppColors.purpleTint, AppColors.purple),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Task progress chart
                  _sectionTitle('Task Overview'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: CardDecor.standard(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Task Distribution',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
                      const SizedBox(height: 16),
                      SizedBox(height: 160, child: _buildTaskChart()),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Today's Attendance
                  _sectionTitle('Today\'s Attendance (${_todayAttendance.length}/$totalEmp)'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: CardDecor.standard(),
                    child: Column(children: [
                      if (_todayAttendance.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No attendance recorded today',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        )
                      else
                        ..._todayAttendance.take(5).map((r) => _attendanceRow(r)),
                      if (_todayAttendance.isNotEmpty)
                        TextButton(
                          onPressed: () => _openDrawerItem(context, const AttendanceScreen()),
                          child: const Text('View All'),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Recent Activity
                  _sectionTitle('Recent Activity'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: CardDecor.standard(),
                    child: Column(children: _recentLogs.map((log) => _logRow(log)).toList()
                      ..add(TextButton(
                        onPressed: () => Navigator.of(context).pushNamed('/audit'),
                        child: const Text('View All Logs')))),
                  ),
                  const SizedBox(height: 100),
                ])),
              ),
          ],
        ),
      ),
    );
  }

  void _openDrawerItem(BuildContext ctx, Widget screen) {
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _quickAction(IconData icon, String label, Color bg, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }

  Widget _buildTaskChart() {
    final total = _taskCounts['total'] ?? 1;
    final pending = (_taskCounts['pending'] ?? 0).toDouble();
    final inProg = (_taskCounts['inProgress'] ?? 0).toDouble();
    final done = (_taskCounts['done'] ?? 0).toDouble();
    if (total == 0) return const Center(child: Text('No tasks yet', style: TextStyle(color: AppColors.textMuted)));
    return PieChart(PieChartData(
      sectionsSpace: 2, centerSpaceRadius: 40,
      sections: [
        PieChartSectionData(value: pending, color: AppColors.warning, title: '${pending.toInt()}',
          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), radius: 48),
        PieChartSectionData(value: inProg, color: AppColors.info, title: '${inProg.toInt()}',
          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), radius: 48),
        PieChartSectionData(value: done, color: AppColors.success, title: '${done.toInt()}',
          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), radius: 48),
        if (pending + inProg + done == 0)
          PieChartSectionData(value: 1, color: AppColors.border, title: '', radius: 48),
      ],
      pieTouchData: PieTouchData(enabled: false),
    ));
  }

  Widget _attendanceRow(AttendanceRecord r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: AppColors.primaryTint,
          child: Text(r.userName.substring(0, 1),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13))),
        const SizedBox(width: 12),
        Expanded(child: Text(r.userName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          overflow: TextOverflow.ellipsis)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(20)),
          child: Text(r.clockInFormatted,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success))),
      ]),
    );
  }

  Widget _logRow(AuditLog log) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Text(log.actionIcon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(log.userName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(log.action, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ])),
        Text(_timeAgo(log.timestamp), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary));

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _dateStr() {
    final d = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
