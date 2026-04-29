import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class TaskService {
  static final TaskService _i = TaskService._();
  factory TaskService() => _i;
  TaskService._();

  static const _key = 'tasks';
  final _uuid = const Uuid();
  final List<TaskModel> _tasks = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _tasks.clear();
      _tasks.addAll(list.map((e) => TaskModel.fromJson(e)));
    } else {
      _seedDefaultTasks();
    }
    _loaded = true;
  }

  void _seedDefaultTasks() {
    final now = DateTime.now();
    _tasks.addAll([
      TaskModel(
        id: _uuid.v4(), title: 'Complete onboarding documentation',
        description: 'Review and sign all HR documents for new employees',
        assignedTo: ['2603IT01', '2603IT02', '2603IT03'],
        assignedBy: 'ADMIN', priority: TaskPriority.high,
        dueDate: now.add(const Duration(days: 2)),
        status: TaskStatus.pending, createdAt: now,
      ),
      TaskModel(
        id: _uuid.v4(), title: 'Set up development environment',
        description: 'Install all required software tools for IT department',
        assignedTo: ['2603IT01'],
        assignedBy: 'ADMIN', priority: TaskPriority.high,
        dueDate: now.add(const Duration(days: 1)),
        status: TaskStatus.inProgress, createdAt: now,
      ),
      TaskModel(
        id: _uuid.v4(), title: 'Social media content calendar — May 2026',
        description: 'Prepare content calendar for all company social platforms',
        assignedTo: ['2604NT03'],
        assignedBy: 'ADMIN', priority: TaskPriority.medium,
        dueDate: now.add(const Duration(days: 5)),
        status: TaskStatus.pending, createdAt: now,
      ),
      TaskModel(
        id: _uuid.v4(), title: 'R&D report — Q1 findings',
        description: 'Compile Q1 research findings and present to leadership',
        assignedTo: ['2602NT02'],
        assignedBy: 'ADMIN', priority: TaskPriority.high,
        dueDate: now.add(const Duration(days: 3)),
        status: TaskStatus.inProgress, createdAt: now,
      ),
      TaskModel(
        id: _uuid.v4(), title: 'Front desk welcome kit',
        description: 'Prepare welcome materials for new employee induction',
        assignedTo: ['2602NT01'],
        assignedBy: 'ADMIN', priority: TaskPriority.low,
        dueDate: now.add(const Duration(days: 7)),
        status: TaskStatus.pending, createdAt: now,
      ),
    ]);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  Future<List<TaskModel>> getAllTasks() async {
    await _ensureLoaded();
    return List.from(_tasks)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<TaskModel>> getTasksForUser(String roleId) async {
    await _ensureLoaded();
    return _tasks.where((t) => t.assignedTo.contains(roleId)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  Future<TaskModel> createTask({
    required String title,
    required String description,
    required List<String> assignedTo,
    required String assignedBy,
    required TaskPriority priority,
    required DateTime dueDate,
  }) async {
    await _ensureLoaded();
    final task = TaskModel(
      id: _uuid.v4(), title: title, description: description,
      assignedTo: assignedTo, assignedBy: assignedBy,
      priority: priority, dueDate: dueDate,
      status: TaskStatus.pending, createdAt: DateTime.now(),
    );
    _tasks.insert(0, task);
    await _save();
    return task;
  }

  Future<void> updateStatus(String taskId, TaskStatus status, {String? note}) async {
    await _ensureLoaded();
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;
    final old = _tasks[idx];
    _tasks[idx] = old.copyWith(
      status: status,
      notes: note != null ? [...old.notes, TaskNote(text: note, createdAt: DateTime.now())] : old.notes,
    );
    await _save();
  }

  Future<void> deleteTask(String taskId) async {
    await _ensureLoaded();
    _tasks.removeWhere((t) => t.id == taskId);
    await _save();
  }

  Map<String, int> getStatusCounts() {
    return {
      'total': _tasks.length,
      'pending': _tasks.where((t) => t.status == TaskStatus.pending).length,
      'inProgress': _tasks.where((t) => t.status == TaskStatus.inProgress).length,
      'done': _tasks.where((t) => t.status == TaskStatus.done).length,
    };
  }
}

enum TaskPriority { low, medium, high }
enum TaskStatus { pending, inProgress, done }

class TaskNote {
  final String text;
  final DateTime createdAt;
  TaskNote({required this.text, required this.createdAt});
  factory TaskNote.fromJson(Map j) => TaskNote(text: j['text'], createdAt: DateTime.parse(j['createdAt']));
  Map<String, dynamic> toJson() => {'text': text, 'createdAt': createdAt.toIso8601String()};
}

class TaskModel {
  final String id, title, description, assignedBy;
  final List<String> assignedTo;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime dueDate, createdAt;
  final List<TaskNote> notes;

  TaskModel({
    required this.id, required this.title, required this.description,
    required this.assignedTo, required this.assignedBy,
    required this.priority, required this.status,
    required this.dueDate, required this.createdAt,
    this.notes = const [],
  });

  TaskModel copyWith({TaskStatus? status, List<TaskNote>? notes}) => TaskModel(
    id: id, title: title, description: description,
    assignedTo: assignedTo, assignedBy: assignedBy,
    priority: priority, status: status ?? this.status,
    dueDate: dueDate, createdAt: createdAt, notes: notes ?? this.notes,
  );

  factory TaskModel.fromJson(Map<String, dynamic> j) => TaskModel(
    id: j['id'], title: j['title'], description: j['description'],
    assignedTo: List<String>.from(j['assignedTo']),
    assignedBy: j['assignedBy'],
    priority: TaskPriority.values[j['priority']],
    status: TaskStatus.values[j['status']],
    dueDate: DateTime.parse(j['dueDate']),
    createdAt: DateTime.parse(j['createdAt']),
    notes: (j['notes'] as List? ?? []).map((n) => TaskNote.fromJson(n)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'assignedTo': assignedTo, 'assignedBy': assignedBy,
    'priority': priority.index, 'status': status.index,
    'dueDate': dueDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'notes': notes.map((n) => n.toJson()).toList(),
  };

  bool get isOverdue => dueDate.isBefore(DateTime.now()) && status != TaskStatus.done;

  String get priorityLabel => priority.name[0].toUpperCase() + priority.name.substring(1);
  String get statusLabel {
    switch (status) {
      case TaskStatus.pending: return 'Pending';
      case TaskStatus.inProgress: return 'In Progress';
      case TaskStatus.done: return 'Done';
    }
  }
}
