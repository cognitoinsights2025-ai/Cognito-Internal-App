import 'package:flutter/material.dart';
import '../core/theme.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isAdmin;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = isAdmin ? _adminItems : _employeeItems;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isActive = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: isActive ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: isActive
                                ? BoxDecoration(
                                    color: AppColors.primaryTint,
                                    borderRadius: BorderRadius.circular(20),
                                  )
                                : null,
                            child: Icon(
                              isActive ? item.activeIcon : item.icon,
                              size: 22,
                              color: isActive ? AppColors.primary : AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? AppColors.primary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  static const _adminItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(Icons.people_outline, Icons.people_rounded, 'Team'),
    _NavItem(Icons.task_outlined, Icons.task_rounded, 'Tasks'),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Audit'),
    _NavItem(Icons.person_outline, Icons.person_rounded, 'Profile'),
  ];

  static const _employeeItems = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.task_outlined, Icons.task_rounded, 'Tasks'),
    _NavItem(Icons.chat_bubble_outline, Icons.chat_bubble_rounded, 'Messages'),
    _NavItem(Icons.campaign_outlined, Icons.campaign_rounded, 'Notices'),
    _NavItem(Icons.person_outline, Icons.person_rounded, 'Profile'),
  ];
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
