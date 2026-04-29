import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../main.dart' show themeProvider;
import '../../services/auth_service.dart';
import '../../services/audit_service.dart';
import '../attendance/attendance_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser!;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          floating: true, snap: true, pinned: false,
          backgroundColor: Colors.white, surfaceTintColor: Colors.transparent,
          title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Avatar card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: CardDecor.primary(borderRadius: 18),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: user.photoAsset != null
                      ? Image.asset(user.photoAsset!, width: 64, height: 64, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 64, height: 64,
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(18)),
                            child: Center(child: Text(user.initials, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)))))
                      : Container(width: 64, height: 64,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(18)),
                          child: Center(child: Text(user.initials, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)))),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${user.role} · ${user.department}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(100)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(user.isAdmin ? Icons.admin_panel_settings_rounded : Icons.verified_rounded,
                        size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(user.isAdmin ? 'Admin' : user.roleId,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ])),
                ])),
              ]),
            ),
            const SizedBox(height: 20),

            // Personal Details
            _sectionLabel('Personal Details'),
            const SizedBox(height: 8),
            _infoCard([
              _row(Icons.badge_outlined, 'Employee ID', user.roleId),
              _row(Icons.work_outline, 'Role', user.role),
              _row(Icons.business_rounded, 'Department', user.department),
              _row(Icons.calendar_today_outlined, 'Date of Joining', user.dateOfJoining),
            ]),
            const SizedBox(height: 16),

            _sectionLabel('Contact'),
            const SizedBox(height: 8),
            _infoCard([
              _row(Icons.phone_outlined, 'Phone', user.phone),
              _row(Icons.email_outlined, 'Personal Email', user.email),
              if (user.companyEmail != null) _row(Icons.alternate_email_rounded, 'Work Email', user.companyEmail!),
              if (user.companyNumber.isNotEmpty) _row(Icons.phone_android_rounded, 'Company No.', user.companyNumber),
              _row(Icons.location_on_outlined, 'Place', user.place),
              _row(Icons.water_drop_outlined, 'Blood Group', user.bloodGroup),
            ]),
            const SizedBox(height: 16),

            // Quick Actions
            _sectionLabel('Quick Access'),
            const SizedBox(height: 8),
            Container(
              decoration: CardDecor.standard(),
              child: Column(children: [
                _menuTile(Icons.how_to_reg_rounded, 'My Attendance', AppColors.successTint, AppColors.success,
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceScreen()))),
              ]),
            ),
            const SizedBox(height: 16),

            _sectionLabel('Appearance'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: CardDecor.standard(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _ThemePicker(),
              ]),
            ),
            const SizedBox(height: 16),

            _sectionLabel('Settings'),
            const SizedBox(height: 8),
            Container(
              decoration: CardDecor.standard(),
              child: Column(children: [
                _menuTile(Icons.notifications_outlined, 'Notifications', AppColors.warningTint, AppColors.warning, () {}),
                const Divider(height: 1, indent: 62),
                _menuTile(Icons.help_outline_rounded, 'Help & Support', AppColors.infoTint, AppColors.info, () {}),
                const Divider(height: 1, indent: 62),
                _menuTile(Icons.info_outline_rounded, 'About App', AppColors.bgSubtle, AppColors.textTertiary, () {
                  showAboutDialog(context: context, applicationName: 'Cognito Insights',
                    applicationVersion: '1.0.0', applicationLegalese: '© 2026 Cognito Insights Solutions Pvt Ltd');
                }),
              ]),
            ),
            const SizedBox(height: 20),

            // Sign Out
            SizedBox(width: double.infinity, height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final user = AuthService().currentUser!;
                  await AuditService().log(userId: user.roleId, userName: user.name, action: 'logout', detail: 'Manual logout');
                  AuthService().logout();
                  if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
            const SizedBox(height: 8),
            const Center(child: Text('© 2026 Cognito Insights Solutions Pvt Ltd',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
          ])),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String t) => Padding(padding: const EdgeInsets.only(left: 2),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1)));

  Widget _infoCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.all(16), decoration: CardDecor.standard(),
    child: Column(children: rows));

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textMuted),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary))),
      Flexible(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _menuTile(IconData icon, String label, Color bg, Color color, VoidCallback onTap) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Container(width: 36, height: 36,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: color)),
    title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
    onTap: onTap,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme Picker Widget
// ─────────────────────────────────────────────────────────────────────────────
class _ThemePicker extends StatefulWidget {
  @override
  State<_ThemePicker> createState() => _ThemePickerState();
}

class _ThemePickerState extends State<_ThemePicker> {
  static const _themes = [
    (mode: AppThemeMode.light, label: 'Light', colors: [Color(0xFFF1F5F9), Color(0xFF2563EB)]),
    (mode: AppThemeMode.dark, label: 'Dark', colors: [Color(0xFF0B1120), Color(0xFF6C5CE7)]),
    (mode: AppThemeMode.purple, label: 'Nebula', colors: [Color(0xFF0D0221), Color(0xFF8B5CF6)]),
    (mode: AppThemeMode.ocean, label: 'Ocean', colors: [Color(0xFF0A1628), Color(0xFF06B6D4)]),
  ];

  @override
  Widget build(BuildContext context) {
    final current = themeProvider.mode;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      for (final t in _themes)
        GestureDetector(
          onTap: () {
            themeProvider.setTheme(t.mode);
            setState(() {});
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: current == t.mode ? t.colors[1] : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: t.colors,
                  ),
                  boxShadow: current == t.mode ? [
                    BoxShadow(color: t.colors[1].withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2)),
                  ] : null,
                ),
                child: current == t.mode
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(t.label, style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: current == t.mode ? t.colors[1] : AppColors.textMuted,
              )),
            ]),
          ),
        ),
    ]);
  }
}
