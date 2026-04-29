import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Stores admin-editable overrides for employee fields.
/// Base data comes from AuthService; overrides are layered on top.
class EmployeeOverrideService {
  static final EmployeeOverrideService _i = EmployeeOverrideService._();
  factory EmployeeOverrideService() => _i;
  EmployeeOverrideService._();

  static const _key = 'employee_overrides';
  // roleId → map of overridden fields
  final Map<String, Map<String, dynamic>> _overrides = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _overrides.clear();
      decoded.forEach((k, v) => _overrides[k] = Map<String, dynamic>.from(v));
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_overrides));
  }

  /// Returns merged employee data (base + overrides).
  Future<EmployeeEditData> getEditData(UserData base) async {
    await _ensureLoaded();
    final o = _overrides[base.roleId] ?? {};
    return EmployeeEditData(
      roleId: base.roleId,
      displayRoleId: o['displayRoleId'] ?? base.roleId,
      name: o['name'] ?? base.name,
      displayName: o['displayName'] ?? base.displayName,
      role: o['role'] ?? base.role,
      department: o['department'] ?? base.department,
      phone: o['phone'] ?? base.phone,
      place: o['place'] ?? base.place,
      address: o['address'] ?? base.address,
      bloodGroup: o['bloodGroup'] ?? base.bloodGroup,
      companyNumber: o['companyNumber'] ?? base.companyNumber,
      companyEmail: o['companyEmail'] ?? base.companyEmail ?? '',
      dateOfJoining: o['dateOfJoining'] ?? base.dateOfJoining,
    );
  }

  /// Saves edited fields for an employee.
  Future<void> saveEdit(String roleId, Map<String, dynamic> fields) async {
    await _ensureLoaded();
    _overrides[roleId] = {...(_overrides[roleId] ?? {}), ...fields};
    await _save();
  }

  /// Returns overridden display value for a field, or null if not overridden.
  Map<String, dynamic>? getOverridesFor(String roleId) =>
      _overrides[roleId];
}

class EmployeeEditData {
  String roleId, displayRoleId, name, displayName, role, department;
  String phone, place, address, bloodGroup, companyNumber, companyEmail;
  String dateOfJoining;

  EmployeeEditData({
    required this.roleId,
    required this.displayRoleId,
    required this.name,
    required this.displayName,
    required this.role,
    required this.department,
    required this.phone,
    required this.place,
    required this.address,
    required this.bloodGroup,
    required this.companyNumber,
    required this.companyEmail,
    required this.dateOfJoining,
  });
}
