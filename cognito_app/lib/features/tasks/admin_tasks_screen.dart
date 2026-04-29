import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/task_service.dart';
import '../../services/auth_service.dart';

class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({super.key});
  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<TaskModel> _tasks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 4, vsync: this); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    final t = await TaskService().getAllTasks();
    if (mounted) setState(() { _tasks = t; _loading = false; });
  }

  List<TaskModel> _filtered(TaskStatus? s) =>
    s == null ? _tasks : _tasks.where((t) => t.status == s).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Task Management'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          isScrollable: true,
          tabs: [
            Tab(text: 'All (${_tasks.length})'),
            Tab(text: 'Pending (${_filtered(TaskStatus.pending).length})'),
            Tab(text: 'In Progress (${_filtered(TaskStatus.inProgress).length})'),
            Tab(text: 'Done (${_filtered(TaskStatus.done).length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_admin_tasks',
        onPressed: _showCreateTask,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: const Text('Assign Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabs,
              children: [
                _taskList(_filtered(null)),
                _taskList(_filtered(TaskStatus.pending)),
                _taskList(_filtered(TaskStatus.inProgress)),
                _taskList(_filtered(TaskStatus.done)),
              ],
            ),
    );
  }

  Widget _taskList(List<TaskModel> tasks) {
    if (tasks.isEmpty) return const Center(child: Text('No tasks here', style: TextStyle(color: AppColors.textMuted)));
    return RefreshIndicator(
      color: AppColors.primary, onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: tasks.length,
        itemBuilder: (ctx, i) => _card(tasks[i]),
      ),
    );
  }

  Widget _card(TaskModel task) {
    final priorityColors = {
      TaskPriority.high: AppColors.rose,
      TaskPriority.medium: AppColors.warning,
      TaskPriority.low: AppColors.success,
    };
    final statusColors = {
      TaskStatus.pending: [AppColors.warningTint, AppColors.warning],
      TaskStatus.inProgress: [AppColors.infoTint, AppColors.info],
      TaskStatus.done: [AppColors.successTint, AppColors.success],
    };
    final pColor = priorityColors[task.priority]!;
    final sColors = statusColors[task.status]!;
    final employees = AuthService().employees;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: CardDecor.standard(),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(task),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: pColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(task.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              _badge(task.statusLabel, sColors[0], sColors[1]),
            ]),
            const SizedBox(height: 6),
            Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary, height: 1.4)),
            const SizedBox(height: 10),
            // Assignees
            Row(children: [
              ...task.assignedTo.take(3).map((id) {
                final emp = employees.where((e) => e.roleId == id).firstOrNull;
                return Container(margin: const EdgeInsets.only(right: 4), width: 26, height: 26,
                  decoration: BoxDecoration(color: AppColors.primaryTint, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5)),
                  child: Center(child: Text(emp?.initials.substring(0, 1) ?? '?',
                    style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700))));
              }),
              if (task.assignedTo.length > 3) Padding(padding: const EdgeInsets.only(left: 2),
                child: Text('+${task.assignedTo.length - 3}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
              const Spacer(),
              Icon(Icons.calendar_today_outlined, size: 11, color: task.isOverdue ? AppColors.error : AppColors.textMuted),
              const SizedBox(width: 3),
              Text(_fmtDate(task.dueDate), style: TextStyle(fontSize: 11,
                color: task.isOverdue ? AppColors.error : AppColors.textMuted,
                fontWeight: task.isOverdue ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _badge(String t, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)));

  void _showDetail(TaskModel task) {
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.65, maxChildSize: 0.9,
        builder: (ctx, sc) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(controller: sc, children: [
            Row(children: [
              Expanded(child: Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
            ]),
            const SizedBox(height: 8),
            Text(task.description, style: const TextStyle(fontSize: 13, color: AppColors.textTertiary, height: 1.5)),
            const Divider(height: 24),
            _row('Priority', task.priorityLabel),
            _row('Status', task.statusLabel),
            _row('Due Date', _fmtDate(task.dueDate)),
            _row('Assigned To', '${task.assignedTo.length} employee(s)'),
            if (task.notes.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Progress Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...task.notes.map((n) => Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Container(padding: const EdgeInsets.all(12), decoration: CardDecor.tinted(AppColors.bgSubtle),
                  child: Text(n.text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4))))),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await TaskService().deleteTask(task.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
                _load();
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete Task'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: BorderSide(color: AppColors.error.withValues(alpha: 0.4))),
            ),
          ]),
        ),
      ));
  }

  Widget _row(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
    ]));

  void _showCreateTask() {
    final employees = AuthService().employees;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    TaskPriority priority = TaskPriority.medium;
    List<String> selectedIds = [];
    DateTime dueDate = DateTime.now().add(const Duration(days: 3));
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Assign New Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Task Title', hintText: 'Enter task title...')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe the task...')),
            const SizedBox(height: 12),
            DropdownButtonFormField<TaskPriority>(
              value: priority,
              items: TaskPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name[0].toUpperCase() + p.name.substring(1)))).toList(),
              onChanged: (v) => setSt(() => priority = v!),
              decoration: const InputDecoration(labelText: 'Priority'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due Date', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              subtitle: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}',
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
              onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: dueDate,
                  firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setSt(() => dueDate = d);
              },
            ),
            const SizedBox(height: 8),
            const Text('Assign To:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6,
              children: employees.map((e) {
                final sel = selectedIds.contains(e.roleId);
                return FilterChip(
                  label: Text(e.name.split(' ').first, style: TextStyle(fontSize: 12, color: sel ? AppColors.primary : AppColors.textSecondary)),
                  selected: sel,
                  onSelected: (_) => setSt(() => sel ? selectedIds.remove(e.roleId) : selectedIds.add(e.roleId)),
                  selectedColor: AppColors.primaryTint,
                  checkmarkColor: AppColors.primary,
                );
              }).toList()),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty || selectedIds.isEmpty) return;
                  await TaskService().createTask(
                    title: titleCtrl.text, description: descCtrl.text,
                    assignedTo: selectedIds, assignedBy: 'ADMIN',
                    priority: priority, dueDate: dueDate);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _load();
                },
                child: const Text('Create & Assign Task'),
              )),
            const SizedBox(height: 8),
          ]),
        ),
      )));
  }

  String _fmtDate(DateTime d) { const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']; return '${m[d.month-1]} ${d.day}'; }
}
