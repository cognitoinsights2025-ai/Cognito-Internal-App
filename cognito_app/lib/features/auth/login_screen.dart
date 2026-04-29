import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/audit_service.dart';
import '../../services/device_binding_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter your email and password');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final user = await AuthService().login(email, pass);
    if (user != null) {
      if (!user.isAdmin) {
        final authorized = await DeviceBindingService().isDeviceAuthorized(user.roleId);
        if (!authorized) {
          setState(() { 
            _loading = false; 
            _error = 'Unauthorized device. Account is bound to another phone.'; 
          });
          return;
        }
        // Bind the device on successful password verification (if not bound)
        await DeviceBindingService().bindDevice(user.roleId);
      }

      await AuditService().log(
        userId: user.roleId, userName: user.name, action: 'login',
        detail: user.isAdmin ? 'Admin login — no face required' : 'Employee login — face verification pending',
        sessionId: user.roleId,
      );
      setState(() => _loading = false);
      // Admin skips face recognition entirely
      final route = user.isAdmin ? '/home' : '/face-attendance';
      Navigator.of(context).pushReplacementNamed(route);
    } else {
      setState(() { _loading = false; _error = 'Invalid email or password'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSubtle,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  children: [
                    // Logo
                    Image.asset('assets/images/logo.png', height: 90, fit: BoxFit.contain),
                    const SizedBox(height: 6),
                    Text('ENTERPRISE PORTAL',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.primaryMid, letterSpacing: 3)),
                    const SizedBox(height: 36),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: CardDecor.standard(borderRadius: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sign In', style: Theme.of(context).textTheme.displaySmall),
                          const SizedBox(height: 4),
                          Text('Access your Cognito Insights account',
                            style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 24),

                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.errorTint,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!, style: const TextStyle(
                                  fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500))),
                              ]),
                            ),
                            const SizedBox(height: 16),
                          ],

                          _label('Email Address'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'your@email.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppColors.textMuted)),
                            onChanged: (_) { if (_error != null) setState(() => _error = null); },
                          ),
                          const SizedBox(height: 18),

                          _label('Password'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.textMuted),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20, color: AppColors.textMuted),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            onChanged: (_) { if (_error != null) setState(() => _error = null); },
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity, height: 50,
                            child: DecoratedBox(
                              decoration: CardDecor.primary(borderRadius: 12),
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _loading
                                    ? const SizedBox(width: 20, height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Sign In', style: TextStyle(fontSize: 15,
                                        fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    Text('© 2026 Cognito Insights Solutions Pvt Ltd',
                      style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(
    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
}
