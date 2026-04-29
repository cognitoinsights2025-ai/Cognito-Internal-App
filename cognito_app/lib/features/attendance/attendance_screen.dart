import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _user = AuthService().currentUser!;
  final _isAdmin = AuthService().currentUser?.isAdmin ?? false;
  List<AttendanceRecord> _records = [];
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (_isAdmin) {
      final all = await AttendanceService().getAll();
      if (mounted) setState(() { _records = all; _loading = false; });
    } else {
      final mine = await AttendanceService().getRecordsForUser(_user.roleId);
      if (mounted) setState(() { _records = mine; _loading = false; });
    }
  }

  List<AttendanceRecord> get _filtered {
    return _records.where((r) =>
      r.date.year == _selectedDate.year &&
      r.date.month == _selectedDate.month &&
      r.date.day == _selectedDate.day).toList();
  }

  @override
  Widget build(BuildContext context) {
    const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(children: [
              // Month selector
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => setState(() => _selectedDate = DateTime(
                        _selectedDate.year, _selectedDate.month - 1, 1)),
                    ),
                    Text(
                      '${months[_selectedDate.month - 1]} ${_selectedDate.year}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () => setState(() => _selectedDate = DateTime(
                            _selectedDate.year, _selectedDate.month + 1, 1)),
                        ),
                        // Calendar picker button
                        IconButton(
                          icon: const Icon(Icons.calendar_today_rounded, size: 20),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Summary stats
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _isAdmin ? _adminStats() : _employeeStats(),
              ),

              // Records list header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_isAdmin ? 'All Records' : 'My Records',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  Text('${_filtered.length} entries', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ]),
              ),

              // Records
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'No attendance records for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: const TextStyle(color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) => _recordCard(_filtered[i]),
                      ),
              ),
            ]),
    );
  }

  Widget _adminStats() {
    final allEmployees = AuthService().employees;
    final today = _records.where((r) {
      final n = DateTime.now();
      return r.date.year == n.year && r.date.month == n.month && r.date.day == n.day;
    }).length;
    return Row(children: [
      _stat('Total Staff', '${allEmployees.length}', AppColors.primaryTint, AppColors.primary, Icons.people_rounded),
      const SizedBox(width: 10),
      _stat('Present Today', '$today', AppColors.successTint, AppColors.success, Icons.check_circle_rounded),
      const SizedBox(width: 10),
      _stat('Absent Today', '${allEmployees.length - today}', AppColors.roseTint, AppColors.rose, Icons.cancel_rounded),
    ]);
  }

  Widget _employeeStats() {
    final now = DateTime.now();
    final thisMonth = _records.where((r) => r.date.year == now.year && r.date.month == now.month).length;
    final workingDays = _getWorkingDays(now.year, now.month);
    return Row(children: [
      _stat('Present', '$thisMonth', AppColors.successTint, AppColors.success, Icons.check_circle_rounded),
      const SizedBox(width: 10),
      _stat('Absent', '${workingDays - thisMonth}', AppColors.roseTint, AppColors.rose, Icons.cancel_rounded),
      const SizedBox(width: 10),
      _stat('Working Days', '$workingDays', AppColors.primaryTint, AppColors.primary, Icons.calendar_month_rounded),
    ]);
  }

  int _getWorkingDays(int year, int month) {
    final days = DateTime(year, month + 1, 0).day;
    int count = 0;
    for (int d = 1; d <= days; d++) {
      final weekday = DateTime(year, month, d).weekday;
      if (weekday < 6) count++;
    }
    return count;
  }

  Widget _stat(String label, String value, Color bg, Color color, IconData icon) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textTertiary)),
        ]),
      ]),
    ));
  }

  Widget _recordCard(AttendanceRecord r) {
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    
    final hasMultiple = r.logins.length > 1;
    final isLate = r.isOutsideWindow;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: CardDecor.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(
                color: isLate ? AppColors.warningTint : AppColors.successTint, 
                borderRadius: BorderRadius.circular(12)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${r.date.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isLate ? AppColors.warning : AppColors.success)),
                Text(mo[r.date.month - 1], style: TextStyle(fontSize: 9, color: isLate ? AppColors.warning : AppColors.success, fontWeight: FontWeight.w600)),
              ])),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isAdmin ? r.userName : '${wd[r.date.weekday - 1]}, ${mo[r.date.month - 1]} ${r.date.day}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(isLate ? 'Outside 9 AM - 5 PM window' : 'Regular Attendance',
                style: TextStyle(fontSize: 11, color: isLate ? AppColors.warning : AppColors.textTertiary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                const Icon(Icons.login_rounded, size: 12, color: AppColors.success),
                const SizedBox(width: 4),
                Text(r.clockInFormatted, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ]),
              if (hasMultiple) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.logout_rounded, size: 12, color: AppColors.rose),
                  const SizedBox(width: 4),
                  Text(r.clockOutFormatted, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ]),
              ]
            ]),
          ]),
          
          if (hasMultiple) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text('Session Logs (${r.logins.length}):', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: r.logins.map((time) {
                final h = time.hour.toString().padLeft(2, '0');
                final m = time.minute.toString().padLeft(2, '0');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.bgSubtle, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.border)),
                  child: Text('$h:$m', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                );
              }).toList(),
            ),
          ]
        ],
      ),
    );
  }
}
