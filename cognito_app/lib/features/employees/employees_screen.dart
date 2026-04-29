import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../platform/file_picker.dart';
import '../../platform/camera.dart';
import '../../platform/platform_image.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/employee_override_service.dart';
import '../../services/face_recognition_service.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  String _searchQuery = '';
  String _filterDept = 'All';
  static const _depts = ['All', 'IT', 'Non-IT', 'Intern'];

  List<UserData> _allEmployees = [];
  bool _isLoading = true;
  // roleId → overridden display data (role/dept label etc.)
  final Map<String, EmployeeEditData> _editCache = {};

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final emps = await AuthService().fetchEmployees();
    final svc = EmployeeOverrideService();
    
    for (final e in emps) {
      _editCache[e.roleId] = await svc.getEditData(e);
    }
    
    if (mounted) {
      setState(() {
        _allEmployees = emps;
        _isLoading = false;
      });
    }
  }

  List<UserData> get _filtered {
    return _allEmployees.where((e) {
      final display = _editCache[e.roleId];
      final name = display?.name ?? e.name;
      final dept = display?.department ?? e.department;
      final matchSearch = _searchQuery.isEmpty ||
          name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.roleId.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchDept = _filterDept == 'All' || dept == _filterDept;
      return matchSearch && matchDept;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Team (${_allEmployees.length})',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_employees',
        onPressed: _showAddEmployee,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Employee',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or ID...',
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20, color: AppColors.textMuted),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _depts.map((d) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(d),
                    selected: _filterDept == d,
                    selectedColor: AppColors.primaryTint,
                    labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _filterDept == d
                            ? AppColors.primary
                            : AppColors.textTertiary),
                    onSelected: (_) => setState(() => _filterDept = d),
                    checkmarkColor: AppColors.primary,
                  ),
                )).toList(),
              ),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(children: [
            Text('${_filtered.length} employees',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ]),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: _filtered.length,
            itemBuilder: (ctx, i) => _card(_filtered[i]),
          ),
        ),
      ]),
    );
  }

  // ───────────────────────────── Card ─────────────────────────────
  final _deptColors = {
    'IT': [AppColors.infoTint, AppColors.info],
    'Non-IT': [AppColors.purpleTint, AppColors.purple],
    'Intern': [AppColors.amberTint, AppColors.amber],
    'Management': [AppColors.successTint, AppColors.success],
  };

  Widget _card(UserData emp) {
    final ed = _editCache[emp.roleId];
    final displayName = ed?.name ?? emp.name;
    final displayRole = ed?.role ?? emp.role;
    final displayDept = ed?.department ?? emp.department;
    final c = _deptColors[displayDept] ??
        [AppColors.bgSubtle, AppColors.textTertiary];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: CardDecor.standard(),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showProfile(emp),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Avatar with photo
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: emp.photoAsset != null
                  ? Image.asset(emp.photoAsset!,
                      width: 50, height: 50, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initialsAvatar(emp, 50))
                  : _initialsAvatar(emp, 50),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(displayRole,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: c[0],
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(displayDept,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: c[1])),
                  ),
                  const SizedBox(width: 6),
                  Text(ed?.displayRoleId ?? emp.roleId,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
                ]),
              ],
            )),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }

  Widget _initialsAvatar(UserData emp, double size) {
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient, shape: BoxShape.circle),
      child: Center(
        child: Text(emp.initials,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.32)),
      ),
    );
  }

  // ───────────────────────── Profile Sheet ────────────────────────
  void _showProfile(UserData emp) async {
    final ed = _editCache[emp.roleId] ?? await EmployeeOverrideService().getEditData(emp);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.97,
        builder: (ctx, sc) => _ProfileSheet(
          emp: emp,
          editData: ed,
          onEdit: () {
            Navigator.of(ctx).pop();
            _showEditForm(emp, ed);
          },
          scrollController: sc,
        ),
      ),
    );
  }

  // ───────────────────────── Edit Form ────────────────────────────
  void _showEditForm(UserData emp, EmployeeEditData ed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSheet(
        emp: emp,
        editData: ed,
        onSaved: (updated) async {
          // For dynamic employees, update the actual UserData
          if (AuthService().isDynamicEmployee(emp.roleId)) {
            final updatedUser = UserData(
              roleId: emp.roleId,
              name: updated.name,
              displayName: updated.displayName,
              email: emp.email,
              password: emp.password,
              role: updated.role,
              department: updated.department,
              phone: updated.phone,
              place: updated.place,
              address: updated.address,
              bloodGroup: updated.bloodGroup,
              companyNumber: updated.companyNumber,
              companyEmail: updated.companyEmail,
              dateOfJoining: updated.dateOfJoining,
            );
            await AuthService().updateEmployee(emp.roleId, updatedUser);
          }
          // Also save overrides (for display in profile sheet)
          await EmployeeOverrideService().saveEdit(emp.roleId, {
            'displayRoleId': updated.displayRoleId,
            'name': updated.name,
            'displayName': updated.displayName,
            'role': updated.role,
            'department': updated.department,
            'phone': updated.phone,
            'place': updated.place,
            'address': updated.address,
            'bloodGroup': updated.bloodGroup,
            'companyNumber': updated.companyNumber,
            'companyEmail': updated.companyEmail,
            'dateOfJoining': updated.dateOfJoining,
          });
          _editCache[emp.roleId] = updated;
          _refreshEmployees();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${updated.name} updated successfully'),
              backgroundColor: AppColors.success,
            ));
          }
        },
      ),
    );
  }

  void _refreshEmployees() {
    _loadEmployees();
  }

  void _showAddEmployee() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddEmployeeSheet(
        onSaved: (newEmployee) async {
          final error = await AuthService().addEmployee(newEmployee);
          if (error != null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(error),
                backgroundColor: AppColors.error,
              ));
            }
            return;
          }
          _refreshEmployees();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${newEmployee.name} added successfully'),
              backgroundColor: AppColors.success,
            ));
          }
        },
      ),
    );
  }

  void _showDeleteConfirm(UserData emp) {
    final isDynamic = AuthService().isDynamicEmployee(emp.roleId);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Employee', style: TextStyle(fontWeight: FontWeight.w700)),
        content: isDynamic
            ? Text('Are you sure you want to remove ${emp.name} (${emp.roleId})? This action cannot be undone.')
            : Text('${emp.name} is a base employee from the Excel roster and cannot be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (isDynamic)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final error = await AuthService().removeEmployee(emp.roleId);
                if (error != null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(error), backgroundColor: AppColors.error));
                  }
                } else {
                  _refreshEmployees();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${emp.name} removed'),
                      backgroundColor: AppColors.success));
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Add Employee Sheet
// ─────────────────────────────────────────────────────────────────
class _AddEmployeeSheet extends StatefulWidget {
  final void Function(UserData newEmployee) onSaved;
  const _AddEmployeeSheet({required this.onSaved});
  @override
  State<_AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends State<_AddEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  static const _departments = ['IT', 'Non-IT', 'Intern', 'Management'];
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', ''];

  final _roleIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: 'Cognito@111');
  final _roleCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _compNumCtrl = TextEditingController();
  final _compEmailCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _dojCtrl = TextEditingController();
  String _dept = 'IT';
  String _blood = '';

  // Photo for face recognition
  Uint8List? _photoBytes;
  String? _photoError;

  Future<void> _pickPhoto() async {
    try {
      final picked = await PlatformFilePickerImpl().pickImage();
      if (picked != null) {
        setState(() {
          _photoBytes = picked.bytes;
          _photoError = null;
        });
      }
    } catch (e) {
      setState(() => _photoError = 'Failed to pick image: $e');
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final bytes = await PlatformCameraCaptureImpl().capturePhoto(context);
      if (bytes != null) {
        setState(() {
          _photoBytes = bytes;
          _photoError = null;
        });
      }
    } catch (e) {
      setState(() => _photoError = 'Failed to capture photo: $e');
    }
  }

  @override
  void dispose() {
    for (final c in [_roleIdCtrl, _nameCtrl, _emailCtrl, _passwordCtrl, _roleCtrl,
          _phoneCtrl, _compNumCtrl, _compEmailCtrl, _placeCtrl, _addressCtrl, _dojCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photoBytes == null) {
      setState(() => _photoError = 'Face photo is required for attendance');
      return;
    }
    setState(() { _saving = true; _photoError = null; });

    final name = _nameCtrl.text.trim();
    final roleId = _roleIdCtrl.text.trim();
    final displayName = name.split(' ').take(2).join(' ');

    // Register face photo with the ArcFace service
    final imageBase64 = base64Encode(_photoBytes!);
    final regResult = await FaceRecognitionService().registerFace(
      roleId: roleId,
      name: name,
      imageBase64: imageBase64,
    );

    if (regResult['success'] != true) {
      setState(() {
        _saving = false;
        _photoError = regResult['message'] ?? 'Face registration failed';
      });
      return;
    }

    final employee = UserData(
      roleId: roleId,
      name: name,
      displayName: displayName,
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
      role: _roleCtrl.text.trim(),
      department: _dept,
      phone: _phoneCtrl.text.trim(),
      place: _placeCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      bloodGroup: _blood,
      companyNumber: _compNumCtrl.text.trim(),
      companyEmail: _compEmailCtrl.text.trim(),
      dateOfJoining: _dojCtrl.text.trim(),
      photoAsset: 'assets/images/employees/$name.jpg',
    );

    widget.onSaved(employee);
    setState(() => _saving = false);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final kbHeight = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: kbHeight),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient, shape: BoxShape.circle),
              child: const Center(
                child: Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Add New Employee',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Text('Fill in all required details',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ]),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              color: AppColors.textMuted,
            ),
          ]),
        ),

        // Form
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Photo Upload Section ──────────────────────
                _sectionLabel('Face Photo (Required for Attendance)'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _photoError != null ? AppColors.errorTint : AppColors.bgSubtle,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _photoError != null
                          ? AppColors.error.withValues(alpha: 0.4)
                          : _photoBytes != null
                              ? AppColors.success.withValues(alpha: 0.4)
                              : AppColors.border,
                    ),
                  ),
                  child: Column(children: [
                    if (_photoBytes != null) ...[
                      PlatformImage(
                        bytes: _photoBytes!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      const SizedBox(height: 10),
                      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                        SizedBox(width: 6),
                        Text('Photo captured',
                            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13)),
                      ]),
                      const SizedBox(height: 10),
                    ] else ...[
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            size: 40, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _photoError ?? 'Upload a clear face photo of the employee',
                        style: TextStyle(
                          color: _photoError != null ? AppColors.error : AppColors.textMuted,
                          fontSize: 12, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      OutlinedButton.icon(
                        onPressed: _capturePhoto,
                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                        label: const Text('Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.photo_library_rounded, size: 16),
                        label: const Text('Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),

                _sectionLabel('Credentials'),
                _field(_roleIdCtrl, 'Employee ID *', Icons.badge_outlined,
                    hint: 'e.g. 2605IT04',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (AuthService().roleIdExists(v.trim())) return 'ID already exists';
                      return null;
                    }),
                const SizedBox(height: 12),
                _field(_emailCtrl, 'Login Email *', Icons.email_outlined,
                    hint: 'employee@gmail.com',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      if (AuthService().emailExists(v.trim())) return 'Email already registered';
                      return null;
                    }),
                const SizedBox(height: 12),
                _field(_passwordCtrl, 'Password *', Icons.lock_outline,
                    hint: 'Default: Cognito@111',
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null),

                const SizedBox(height: 20),
                _sectionLabel('Basic Information'),
                _field(_nameCtrl, 'Full Name *', Icons.person_outline_rounded,
                    hint: 'e.g. John Doe',
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                _field(_roleCtrl, 'Role / Designation *', Icons.work_outline,
                    hint: 'e.g. Developer, Intern, Manager',
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                _dropdownRow(),

                const SizedBox(height: 20),
                _sectionLabel('Contact'),
                _field(_phoneCtrl, 'Phone Number', Icons.phone_outlined, hint: '+91 XXXXX XXXXX'),
                const SizedBox(height: 12),
                _field(_compNumCtrl, 'Company Number', Icons.phone_android_rounded),
                const SizedBox(height: 12),
                _field(_compEmailCtrl, 'Work Email', Icons.alternate_email_rounded),
                const SizedBox(height: 12),
                _field(_placeCtrl, 'City / Place', Icons.location_city_rounded),
                const SizedBox(height: 12),
                _field(_addressCtrl, 'Full Address', Icons.home_outlined, maxLines: 2),

                const SizedBox(height: 20),
                _sectionLabel('Other Details'),
                Row(children: [
                  Expanded(child: _field(_dojCtrl, 'Date of Joining', Icons.calendar_today_outlined,
                      hint: 'DD-MM-YYYY')),
                  const SizedBox(width: 12),
                  Expanded(child: _bloodDropdown()),
                ]),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_add_rounded, color: Colors.white),
                    label: const Text('Add Employee',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(label.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: AppColors.textMuted, letterSpacing: 1)),
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon, {
    String? Function(String?)? validator, int maxLines = 1, String? hint,
  }) {
    return TextFormField(
      controller: ctrl, maxLines: maxLines, validator: validator,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true, fillColor: AppColors.bgSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _dropdownRow() => DropdownButtonFormField<String>(
    value: _dept,
    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
    onChanged: (v) => setState(() => _dept = v!),
    decoration: InputDecoration(
      labelText: 'Department',
      prefixIcon: const Icon(Icons.business_rounded, size: 18, color: AppColors.textMuted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true, fillColor: AppColors.bgSubtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );

  Widget _bloodDropdown() => DropdownButtonFormField<String>(
    value: _blood,
    items: _bloodGroups.map((b) => DropdownMenuItem(value: b, child: Text(b.isEmpty ? 'Unknown' : b))).toList(),
    onChanged: (v) => setState(() => _blood = v!),
    decoration: InputDecoration(
      labelText: 'Blood Group',
      prefixIcon: const Icon(Icons.water_drop_outlined, size: 18, color: AppColors.textMuted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true, fillColor: AppColors.bgSubtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// Profile Sheet Widget
// ─────────────────────────────────────────────────────────────────
class _ProfileSheet extends StatelessWidget {
  final UserData emp;
  final EmployeeEditData editData;
  final VoidCallback onEdit;
  final ScrollController scrollController;

  const _ProfileSheet({
    required this.emp,
    required this.editData,
    required this.onEdit,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final deptColors = {
      'IT': [AppColors.infoTint, AppColors.info],
      'Non-IT': [AppColors.purpleTint, AppColors.purple],
      'Intern': [AppColors.amberTint, AppColors.amber],
    };
    final c = deptColors[editData.department] ??
        [AppColors.bgSubtle, AppColors.textTertiary];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Avatar + header
          Center(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(44),
                  child: emp.photoAsset != null
                      ? Image.asset(emp.photoAsset!,
                          width: 88, height: 88, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _bigInitials())
                      : _bigInitials(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(editData.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('${editData.role} · ${editData.department}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textTertiary)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c[0] as Color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(emp.roleId,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c[1] as Color)),
            ),
          ),

          const SizedBox(height: 20),

          // Edit button (Admin only)
          if (AuthService().currentUser?.isAdmin == true)
            OutlinedButton.icon(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Edit Employee Details',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),

          const SizedBox(height: 20),

          _section('Employee Details', [
            _infoRow(Icons.badge_outlined, 'Employee ID', editData.displayRoleId),
            _infoRow(Icons.work_outline, 'Role', editData.role),
            _infoRow(Icons.business_rounded, 'Department', editData.department),
            _infoRow(Icons.calendar_today_outlined, 'Date of Joining',
                editData.dateOfJoining),
          ]),
          const SizedBox(height: 16),
          _section('Contact', [
            _infoRow(Icons.phone_outlined, 'Phone',
                editData.phone),
            _infoRow(Icons.email_outlined, 'Personal Email', emp.email),
            if (editData.companyEmail.isNotEmpty)
              _infoRow(Icons.alternate_email_rounded, 'Work Email',
                  editData.companyEmail),
            if (editData.companyNumber.isNotEmpty)
              _infoRow(Icons.phone_android_rounded, 'Company No.',
                  editData.companyNumber),
            _infoRow(Icons.location_on_outlined, 'Place', editData.place),
            _infoRow(Icons.home_outlined, 'Address', editData.address),
            if (editData.bloodGroup.isNotEmpty)
              _infoRow(Icons.water_drop_outlined, 'Blood Group',
                  editData.bloodGroup),
          ]),
          if (emp.bankAccount != null) ...[
            const SizedBox(height: 16),
            _section('Banking', [
              _infoRow(Icons.account_balance_outlined, 'Account No.',
                  '••••${emp.bankAccount!.substring(emp.bankAccount!.length > 4 ? emp.bankAccount!.length - 4 : 0)}'),
              if (emp.ifsc != null)
                _infoRow(Icons.code_rounded, 'IFSC', emp.ifsc!),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _bigInitials() {
    return Container(
      width: 88, height: 88,
      decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient, shape: BoxShape.circle),
      child: Center(
        child: Text(emp.initials,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) => Container(
    padding: const EdgeInsets.all(16),
    decoration: CardDecor.standard(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1)),
      const Divider(height: 16),
      ...rows,
    ]),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textMuted),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textTertiary))),
      Flexible(
        child: Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
// Edit Sheet Widget
// ─────────────────────────────────────────────────────────────────
class _EditSheet extends StatefulWidget {
  final UserData emp;
  final EmployeeEditData editData;
  final void Function(EmployeeEditData updated) onSaved;

  const _EditSheet({
    required this.emp,
    required this.editData,
    required this.onSaved,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  static const _departments = ['IT', 'Non-IT', 'Intern', 'Management'];
  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', ''
  ];

  late final TextEditingController _empIdCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _roleCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _compNumCtrl;
  late final TextEditingController _compEmailCtrl;
  late final TextEditingController _placeCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _dojCtrl;
  late String _dept;
  late String _blood;

  @override
  void initState() {
    super.initState();
    final ed = widget.editData;
    _empIdCtrl    = TextEditingController(text: ed.displayRoleId);
    _nameCtrl     = TextEditingController(text: ed.name);
    _roleCtrl     = TextEditingController(text: ed.role);
    _phoneCtrl    = TextEditingController(text: ed.phone);
    _compNumCtrl  = TextEditingController(text: ed.companyNumber);
    _compEmailCtrl= TextEditingController(text: ed.companyEmail);
    _placeCtrl    = TextEditingController(text: ed.place);
    _addressCtrl  = TextEditingController(text: ed.address);
    _dojCtrl      = TextEditingController(text: ed.dateOfJoining);
    _dept = _departments.contains(ed.department) ? ed.department : _departments.first;
    _blood = _bloodGroups.contains(ed.bloodGroup) ? ed.bloodGroup : '';
  }

  @override
  void dispose() {
    for (final c in [_empIdCtrl, _nameCtrl, _roleCtrl, _phoneCtrl, _compNumCtrl,
          _compEmailCtrl, _placeCtrl, _addressCtrl, _dojCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final updated = EmployeeEditData(
      roleId: widget.emp.roleId,
      displayRoleId: _empIdCtrl.text.trim().isEmpty ? widget.emp.roleId : _empIdCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      displayName: _nameCtrl.text.trim().split(' ').take(2).join(' '),
      role: _roleCtrl.text.trim(),
      department: _dept,
      phone: _phoneCtrl.text.trim(),
      place: _placeCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      bloodGroup: _blood,
      companyNumber: _compNumCtrl.text.trim(),
      companyEmail: _compEmailCtrl.text.trim(),
      dateOfJoining: _dojCtrl.text.trim(),
    );
    setState(() => _saving = false);
    widget.onSaved(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final kbHeight = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: kbHeight),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: widget.emp.photoAsset != null
                  ? Image.asset(widget.emp.photoAsset!,
                      width: 40, height: 40, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _smallAvatar())
                  : _smallAvatar(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Edit Employee',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                Text(widget.emp.roleId,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ]),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              color: AppColors.textMuted,
            ),
          ]),
        ),

        // Form
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Basic Information'),
                  _field(_empIdCtrl, 'Employee ID', Icons.badge_outlined,
                      hint: 'e.g. 2603IT01'),
                  const SizedBox(height: 12),
                  _field(_nameCtrl, 'Full Name', Icons.person_outline_rounded,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  _field(_roleCtrl, 'Role / Designation', Icons.work_outline,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  _dropdownRow(),

                  const SizedBox(height: 20),
                  _sectionLabel('Contact'),
                  _field(_phoneCtrl, 'Phone Number', Icons.phone_outlined),
                  const SizedBox(height: 12),
                  _field(_compNumCtrl, 'Company Number', Icons.phone_android_rounded),
                  const SizedBox(height: 12),
                  _field(_compEmailCtrl, 'Work Email', Icons.alternate_email_rounded),
                  const SizedBox(height: 12),
                  _field(_placeCtrl, 'City / Place', Icons.location_city_rounded),
                  const SizedBox(height: 12),
                  _field(_addressCtrl, 'Full Address', Icons.home_outlined, maxLines: 2),

                  const SizedBox(height: 20),
                  _sectionLabel('Other Details'),
                  Row(children: [
                    Expanded(
                      child: _field(_dojCtrl, 'Date of Joining', Icons.calendar_today_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _bloodDropdown()),
                  ]),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _smallAvatar() => Container(
    width: 40, height: 40,
    decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient, shape: BoxShape.circle),
    child: Center(
      child: Text(widget.emp.initials,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14)),
    ),
  );

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(label.toUpperCase(),
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 1)),
  );

  Widget _field(
    TextEditingController ctrl, String label, IconData icon, {
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hint,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.bgSubtle,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _dropdownRow() => DropdownButtonFormField<String>(
    value: _dept,
    items: _departments
        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
        .toList(),
    onChanged: (v) => setState(() => _dept = v!),
    decoration: InputDecoration(
      labelText: 'Department',
      prefixIcon: const Icon(Icons.business_rounded,
          size: 18, color: AppColors.textMuted),
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: AppColors.bgSubtle,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );

  Widget _bloodDropdown() => DropdownButtonFormField<String>(
    value: _blood,
    items: _bloodGroups
        .map((b) => DropdownMenuItem(
              value: b,
              child: Text(b.isEmpty ? 'Unknown' : b),
            ))
        .toList(),
    onChanged: (v) => setState(() => _blood = v!),
    decoration: InputDecoration(
      labelText: 'Blood Group',
      prefixIcon: const Icon(Icons.water_drop_outlined,
          size: 18, color: AppColors.textMuted),
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: AppColors.bgSubtle,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
