import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/audit_service.dart';

/// Wraps the home shell and auto-logs out after 15 min of inactivity
class AutoLogoutWrapper extends StatefulWidget {
  final Widget child;
  const AutoLogoutWrapper({super.key, required this.child});

  @override
  State<AutoLogoutWrapper> createState() => _AutoLogoutWrapperState();
}

class _AutoLogoutWrapperState extends State<AutoLogoutWrapper> {
  static const _timeoutDuration = Duration(minutes: 15);
  static const _warningDuration = Duration(minutes: 13);

  Timer? _timer;
  Timer? _warningTimer;
  bool _warningShown = false;

  @override
  void initState() {
    super.initState();
    _startTimers();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _warningTimer?.cancel();
    super.dispose();
  }

  void _startTimers() {
    _timer?.cancel();
    _warningTimer?.cancel();
    _warningShown = false;

    _warningTimer = Timer(_warningDuration, _showWarning);
    _timer = Timer(_timeoutDuration, _autoLogout);
  }

  void _resetTimers() {
    _timer?.cancel();
    _warningTimer?.cancel();
    _warningShown = false;
    _startTimers();
  }

  void _showWarning() {
    if (!mounted || _warningShown) return;
    _warningShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.timer_outlined, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Session expires in 2 minutes. Tap to stay logged in.'),
          ],
        ),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'STAY',
          textColor: Colors.amber,
          onPressed: _resetTimers,
        ),
      ),
    );
  }

  Future<void> _autoLogout() async {
    if (!mounted) return;
    final user = AuthService().currentUser;
    if (user != null) {
      await AuditService().log(
        userId: user.roleId,
        userName: user.name,
        action: 'auto_logout',
        detail: 'Session expired after 15 min inactivity',
      );
    }
    AuthService().logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You were logged out due to inactivity.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimers(),
      onPointerMove: (_) => _resetTimers(),
      child: widget.child,
    );
  }
}
