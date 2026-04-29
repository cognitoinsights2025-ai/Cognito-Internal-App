import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central authentication service — connected to Supabase
class AuthService {
  static final AuthService _i = AuthService._();
  factory AuthService() => _i;
  AuthService._();

  final _supabase = Supabase.instance.client;

  UserData? _currentUser;
  
  UserData? get currentUser => _currentUser;
  String? get sessionId => _supabase.auth.currentSession?.accessToken;

  // ---------------------------------------------------------------------------
  // Login / Logout
  // ---------------------------------------------------------------------------

  /// Login using Supabase Auth
  Future<UserData?> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        // Fetch the associated employee profile
        final data = await _supabase
            .from('employees')
            .select()
            .eq('id', response.user!.id)
            .single();

        _currentUser = UserData.fromJson(data);
        await _persistSession(_currentUser!.roleId);
        return _currentUser;
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  /// Automatically fetches the user profile if a session exists
  Future<UserData?> restoreSession() async {
    final session = _supabase.auth.currentSession;
    if (session != null && session.user != null) {
      try {
        final data = await _supabase
            .from('employees')
            .select()
            .eq('id', session.user.id)
            .single();

        _currentUser = UserData.fromJson(data);
        await _persistSession(_currentUser!.roleId);
        return _currentUser;
      } catch (e) {
        print('Restore session error: $e');
        return null;
      }
    }
    return null;
  }

  Future<void> _persistSession(String roleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_role_id', roleId);
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_role_id');
  }

  // ---------------------------------------------------------------------------
  // Employee Data Fetching
  // ---------------------------------------------------------------------------

  List<UserData> _cachedEmployees = [];
  List<UserData> get employees => _cachedEmployees;

  /// Fetch all employees from Supabase and cache them
  Future<List<UserData>> fetchEmployees() async {
    try {
      final data = await _supabase.from('employees').select().order('name');
      _cachedEmployees = data.map((e) => UserData.fromJson(e)).toList();
      return _cachedEmployees;
    } catch (e) {
      print('Error fetching employees: $e');
      return [];
    }
  }

  /// Fetch employee by roleId from cache
  UserData? findByRoleId(String roleId) {
    try {
      return _cachedEmployees.firstWhere((e) => e.roleId == roleId);
    } catch (_) {
      return null;
    }
  }

  /// Fetch employees filtered by department from cache
  List<UserData> getByDepartment(String department) {
    return _cachedEmployees
        .where((e) => e.department.toLowerCase() == department.toLowerCase())
        .toList();
  }

  /// Check if a roleId already exists
  bool roleIdExists(String roleId) {
    return _cachedEmployees.any((e) => e.roleId == roleId);
  }

  /// Check if an email already exists
  bool emailExists(String email) {
    return _cachedEmployees.any((e) => e.email.toLowerCase() == email.toLowerCase());
  }

  // ---------------------------------------------------------------------------
  // CRUD — Add / Update / Delete employees (admin only)
  // ---------------------------------------------------------------------------

  /// Add a new employee
  Future<String?> addEmployee(UserData employee) async {
    try {
      if (await roleIdExists(employee.roleId)) {
        return 'Employee ID "${employee.roleId}" already exists';
      }
      if (await emailExists(employee.email)) {
        return 'Email "${employee.email}" already exists';
      }

      // Note: In Supabase, creating an auth user typically requires the Admin API.
      // Since this is a client app, you would ideally use an edge function to create the user,
      // or you can signUp the user and have them confirm email.
      // For now, we sign up the user if we are the admin (this logs out the current user by default,
      // so using edge functions or service_role in backend is better in production).
      
      // Let's insert into the employees table assuming the trigger or backend handles auth,
      // OR we just push the profile and rely on an edge function.
      // *Warning: Supabase client auth.signUp will log out the admin.*
      // For the prototype, we just insert the DB record.
      final record = employee.toJson();
      // Remove id since it will be mapped to auth.uid() or generated if allowed
      record.remove('id'); 
      
      await _supabase.from('employees').insert(record);
      return null;
    } catch (e) {
      return 'Failed to add employee: $e';
    }
  }

  /// Update an existing employee
  Future<String?> updateEmployee(String roleId, UserData updated) async {
    try {
      await _supabase
          .from('employees')
          .update(updated.toJson())
          .eq('role_id', roleId);
      return null;
    } catch (e) {
      return 'Failed to update: $e';
    }
  }

  /// Remove an employee by roleId
  Future<String?> removeEmployee(String roleId) async {
    try {
      await _supabase.from('employees').delete().eq('role_id', roleId);
      return null;
    } catch (e) {
      return 'Failed to delete: $e';
    }
  }

  /// In the new architecture, all employees are managed via Supabase.
  bool isDynamicEmployee(String roleId) => true; 
}

// ---------------------------------------------------------------------------
// UserData model
// ---------------------------------------------------------------------------
class UserData {
  final String? id;           // auth.uid()
  final String name;          // full name
  final String displayName;   // short display name
  final String email;
  final String password;
  final String roleId;
  final String role;
  final String department;    
  final String phone;
  final String place;
  final String address;
  final String bloodGroup;
  final String companyNumber;
  final String dateOfJoining;
  final String? companyEmail;
  final String? bankAccount;
  final String? ifsc;
  final String? photoAsset;   // URL from Supabase Storage, or local asset fallback
  final bool isAdmin;

  const UserData({
    this.id,
    required this.name,
    required this.displayName,
    required this.email,
    required this.password,
    required this.roleId,
    required this.role,
    required this.department,
    required this.phone,
    required this.place,
    required this.address,
    required this.bloodGroup,
    required this.companyNumber,
    required this.dateOfJoining,
    this.companyEmail,
    this.bankAccount,
    this.ifsc,
    this.photoAsset,
    this.isAdmin = false,
  });

  /// Two-letter initials from the display name
  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
  }

  /// First name for greetings
  String get firstName => displayName.split(' ').first;

  /// Serialize to JSON for DB insert
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'display_name': displayName,
    'email': email,
    'role_id': roleId,
    'role': role,
    'department': department,
    'phone': phone,
    'place': place,
    'address': address,
    'blood_group': bloodGroup,
    'company_number': companyNumber,
    'date_of_joining': dateOfJoining,
    'company_email': companyEmail,
    'bank_account': bankAccount,
    'ifsc': ifsc,
    'photo_url': photoAsset,
    'is_admin': isAdmin,
  };

  /// Deserialize from DB JSON
  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
    id: json['id'],
    name: json['name'] ?? '',
    displayName: json['display_name'] ?? json['name'] ?? '',
    email: json['email'] ?? '',
    password: json['password'] ?? 'Cognito@111', // Not stored in DB
    roleId: json['role_id'] ?? '',
    role: json['role'] ?? '',
    department: json['department'] ?? '',
    phone: json['phone'] ?? '',
    place: json['place'] ?? '',
    address: json['address'] ?? '',
    bloodGroup: json['blood_group'] ?? '',
    companyNumber: json['company_number'] ?? '',
    dateOfJoining: json['date_of_joining'] ?? '',
    companyEmail: json['company_email'],
    bankAccount: json['bank_account'],
    ifsc: json['ifsc'],
    photoAsset: json['photo_url'],
    isAdmin: json['is_admin'] ?? false,
  );
}
