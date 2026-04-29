import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/task_service.dart';
import '../../services/auth_service.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});
  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<TaskModel> _tasks = [];
  bool _loading = true;
  final user = AuthService().currentUser!;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    final t = await TaskService().getTasksForUser(user.roleId);
    if (mounted) setState(() { _tasks = t; _loading = false; });
  }

  List<TaskModel> _filtered(TaskStatus? s) =>
      _tasks.where((t) => s == null || t.status == s).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('My Tasks'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Pending (${_filtered(TaskStatus.pending).length})'),
            Tab(text: 'In Progress (${_filtered(TaskStatus.inProgress).length})'),
            Tab(text: 'Done (${_filtered(TaskStatus.done).length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabs,
              children: [
                _taskList(_filtered(TaskStatus.pending)),
                _taskList(_filtered(TaskStatus.inProgress)),
                _taskList(_filtered(TaskStatus.done)),
              ],
            ),
    );
  }

  Widget _taskList(List<TaskModel> tasks) {
    if (tasks.isEmpty) return const Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.task_alt_rounded, size: 48, color: AppColors.textMuted),
        SizedBox(height: 12),
        Text('No tasks here!', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
      ],
    ));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (ctx, i) => _card(tasks[i]),
    );
  }

  Widget _card(TaskModel task) {
    final priorityColors = {
      TaskPriority.high: AppColors.rose,
      TaskPriority.medium: AppColors.warning,
      TaskPriority.low: AppColors.success,
    };
    final pColor = priorityColors[task.priority]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CardDecor.standard(),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(task),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: pColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(task.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              _badge(task.priorityLabel, pColor.withValues(alpha: 0.1), pColor),
            ]),
            const SizedBox(height: 8),
            Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary, height: 1.4)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('Due: ${_fmtDate(task.dueDate)}',
                style: TextStyle(fontSize: 11, color: task.isOverdue ? AppColors.error : AppColors.textMuted,
                  fontWeight: task.isOverdue ? FontWeight.w600 : FontWeight.w400)),
              const Spacer(),
              _badge(task.statusLabel,
                task.status == TaskStatus.done ? AppColors.successTint : AppColors.infoTint,
                task.status == TaskStatus.done ? AppColors.success : AppColors.info),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showDetail(TaskModel task) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => _TaskDetailSheet(task: task, onUpdate: _load),
    );
  }

  Widget _badge(String t, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)));

  String _fmtDate(DateTime d) { const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']; return '${m[d.month-1]} ${d.day}'; }
}

class _TaskDetailSheet extends StatefulWidget {
  final TaskModel task;
  final VoidCallback onUpdate;
  const _TaskDetailSheet({required this.task, required this.onUpdate});
  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  late TaskStatus _status;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() { super.initState(); _status = widget.task.status; }
  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    await TaskService().updateStatus(widget.task.id, _status,
        note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null);
    widget.onUpdate();
    if (mounted) { Navigator.of(context).pop(); setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(widget.task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
          ]),
          const SizedBox(height: 8),
          Text(widget.task.description, style: const TextStyle(fontSize: 13, color: AppColors.textTertiary, height: 1.5)),
          const SizedBox(height: 16),
          const Text('Update Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          SegmentedButton<TaskStatus>(
            segments: const [
              ButtonSegment(value: TaskStatus.pending, label: Text('Pending'), icon: Icon(Icons.radio_button_unchecked, size: 14)),
              ButtonSegment(value: TaskStatus.inProgress, label: Text('In Progress'), icon: Icon(Icons.pending, size: 14)),
              ButtonSegment(value: TaskStatus.done, label: Text('Done'), icon: Icon(Icons.check_circle, size: 14)),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? AppColors.primaryTint : null)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(hintText: 'Add a progress note (optional)...', prefixIcon: Icon(Icons.note_add_outlined, size: 18)),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
