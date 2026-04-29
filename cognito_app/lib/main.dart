import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'services/auth_service.dart';
import 'services/ml_service.dart';
import 'widgets/auto_logout_wrapper.dart';
import 'widgets/bottom_nav.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/face_attendance_screen.dart';
import 'features/dashboard/admin_dashboard_screen.dart';
import 'features/dashboard/employee_dashboard_screen.dart';
import 'features/tasks/my_tasks_screen.dart';
import 'features/tasks/admin_tasks_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/notices/notices_screen.dart';
import 'features/employees/employees_screen.dart';
import 'features/audit/audit_screen.dart';
import 'features/profile/profile_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// GLOBAL THEME PROVIDER — accessible everywhere
// ═════════════════════════════════════════════════════════════════════════════
final themeProvider = ThemeProvider();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ffrlwuorwotketzkmdwo.supabase.co',
    anonKey: 'sb_publishable_5sRSWPYwdGAU0wECSJdqhA_y0-AELJ0',
  );

  // Optimize status bar for immersive experience
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Set preferred orientations for mobile
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  if (!kIsWeb) {
    await MLService().initialize();
  }

  // Pre-fetch employee data
  await AuthService().fetchEmployees();

  runApp(const CognitoApp());
}

class CognitoApp extends StatefulWidget {
  const CognitoApp({super.key});
  @override
  State<CognitoApp> createState() => _CognitoAppState();
}

class _CognitoAppState extends State<CognitoApp> {
  @override
  void initState() {
    super.initState();
    themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return HeroControllerScope.none(
      child: MaterialApp(
        title: 'Cognito Insights',
        debugShowCheckedModeBanner: false,
        theme: themeProvider.themeData,
        initialRoute: '/login',
        routes: {
          '/login': (_) => const LoginScreen(),
          '/face-registration': (_) => const FaceLoginScreen(),
          '/face-attendance': (_) => const FaceLoginScreen(),
          '/home': (_) => const AutoLogoutWrapper(child: HomeShell()),
          '/employees': (_) => const EmployeesScreen(),
          '/admin-tasks': (_) => const AdminTasksScreen(),
          '/audit': (_) => const AuditScreen(),
          '/notices': (_) => const NoticesScreen(),
        },
      ),
    );
  }
}


class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final _auth = AuthService();
  final _bucket = PageStorageBucket();

  // Animation controller for smooth tab transitions
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  List<Widget> get _adminScreens => const [
    AdminDashboardScreen(),
    EmployeesScreen(),
    AdminTasksScreen(),
    AuditScreen(),
    ProfileScreen(),
  ];

  List<Widget> get _employeeScreens => const [
    EmployeeDashboardScreen(),
    MyTasksScreen(),
    MessagesScreen(),
    NoticesScreen(),
    ProfileScreen(),
  ];

  void _onTabChanged(int index) {
    if (index == _currentIndex) return;
    _fadeController.reverse().then((_) {
      setState(() => _currentIndex = index);
      _fadeController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _auth.currentUser?.isAdmin ?? false;
    final screens = isAdmin ? _adminScreens : _employeeScreens;

    return Scaffold(
      body: PageStorage(
        bucket: _bucket,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        isAdmin: isAdmin,
        onTap: _onTabChanged,
      ),
    );
  }
}
