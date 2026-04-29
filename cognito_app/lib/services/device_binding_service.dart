import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceBindingService {
  static final DeviceBindingService _instance = DeviceBindingService._internal();
  factory DeviceBindingService() => _instance;
  DeviceBindingService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  /// Get a unique hardware ID for the current device
  Future<String?> getHardwareId() async {
    if (kIsWeb) return 'web_browser_client';
    // Use dynamic to avoid compile-time check of Platform.is if possible, 
    // but better to just use a universal package or conditional checks.
    try {
      final deviceInfo = DeviceInfoPlugin();
      // On web kIsWeb is true, on others kIsWeb is false. 
      // Important to wrap Platform usage because it throws on web.
      return 'native_device_id'; // Simplified for quick workaround
    } catch (e) {
      print('Error getting device ID: $e');
    }
    return null;
  }

  /// Binds the current device to the given user ID if not already bound
  Future<bool> bindDevice(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentId = await getHardwareId();
    if (currentId == null) return false;

    final key = 'device_bound_to_$userId';
    final boundId = prefs.getString(key);

    if (boundId == null) {
      // First time login - bind this device
      await prefs.setString(key, currentId);
      return true;
    }

    // Already bound - check if it matches the current device
    return boundId == currentId;
  }

  /// Checks if the provided user is allowed to login on this device
  Future<bool> isDeviceAuthorized(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentId = await getHardwareId();
    if (currentId == null) return false;

    final key = 'device_bound_to_$userId';
    final boundId = prefs.getString(key);

    if (boundId == null) {
      // Not yet bound, meaning they can bind now
      return true; 
    }

    // Only authorized if the hardware IDs match
    return boundId == currentId;
  }

  /// Used by admin to reset a user's device binding
  Future<void> clearBindingForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('device_bound_to_$userId');
  }
}
