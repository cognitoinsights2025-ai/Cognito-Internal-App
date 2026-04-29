import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';
import '../../services/audit_service.dart';
import '../../services/ml_service.dart';
import '../../platform/platform_image.dart';
import '../../services/face_recognition_service.dart';

/// Face verification login screen.
///
/// Flow:
/// 1. Shows employee's registered profile photo (reference).
/// 2. Opens front camera for live preview.
/// 3. On "Verify", captures a frame and compares it with the reference
///    using a brightness-grid histogram similarity algorithm.
/// 4. If similarity ≥ threshold → SUCCESS → marks attendance → home.
/// 5. If similarity < threshold → FAIL → shows "Authentication Failed".
/// 6. Up to 3 attempts allowed; then forced back to login.
///
/// Admin is NEVER shown this screen.
class FaceLoginScreen extends StatefulWidget {
  const FaceLoginScreen({super.key});
  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen>
    with TickerProviderStateMixin {
  // ── Camera ───────────────────────────────────────────────────────
  CameraController? _ctrl;
  bool _cameraReady = false;
  bool _cameraError = false;

  // ── State ────────────────────────────────────────────────────────
  _State _state = _State.preview;
  double? _matchScore; // 0–100
  int _attempts = 0;
  static const _maxAttempts = 3;
  static const _matchThreshold = 65.0; // Cosine similarity threshold mapped to 0-100%

  // ML Service Reference Embeddings
  List<double>? _refEmbedding;

  // ── Animations ───────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _successCtrl;
  late AnimationController _failCtrl;

  late final UserData _user;

  // Reference image bytes (loaded from asset)
  Uint8List? _refBytes;

  @override
  void initState() {
    super.initState();
    _user = AuthService().currentUser!;

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _failCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _initCamera();
    _loadReferenceImage();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    _failCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReferenceImage() async {
    if (_user.photoAsset == null) return;
    try {
      final data = await rootBundle.load(_user.photoAsset!);
      if (mounted) setState(() => _refBytes = data.buffer.asUint8List());

      // If MLService model is loaded, pre-calculate the reference embedding
      if (_refBytes != null && MLService().isModelLoaded) {
        final decoded = img.decodeImage(_refBytes!);
        if (decoded != null) {
          _refEmbedding = await MLService().generateEmbedding(decoded);
          print('✅ Generated reference embedding: ${_refEmbedding != null}');
        }
      }
    } catch (_) {}
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw Exception('No cameras');
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      _ctrl = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await _ctrl!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (_) {
      if (mounted) setState(() { _cameraReady = false; _cameraError = true; });
    }
  }

  // ────────────────────────────────────────────────────────────────
  // ArcFace Server-Side Verification (99.83% accuracy)
  // ────────────────────────────────────────────────────────────────

  Future<void> _verify() async {
    if (_state == _State.processing) return;
    setState(() => _state = _State.processing);

    try {
      // ── Capture camera frame ─────────────────────────────────
      Uint8List? capturedBytes;
      if (_ctrl != null && _ctrl!.value.isInitialized) {
        final xfile = await _ctrl!.takePicture();
        capturedBytes = await xfile.readAsBytes();
      }

      if (capturedBytes == null) {
        _matchScore = 0;
        _attempts++;
        await _onFail(0);
        return;
      }

      // ── Send to ArcFace Python service for verification ─────
      final imageBase64 = base64Encode(capturedBytes);
      final result = await FaceRecognitionService().verifyFace(
        roleId: _user.roleId,
        imageBase64: imageBase64,
      );

      _matchScore = result.confidence;
      _attempts++;

      if (result.serviceError) {
        // Service unavailable — do NOT auto-pass, show error
        print('❌ Face service unavailable: ${result.message}');
        await _onFail(0);
        return;
      }

      if (result.verified) {
        await _onSuccess(capturedBytes);
      } else {
        await _onFail(result.confidence);
      }
    } catch (e) {
      // On error, do NOT auto-pass — fail securely
      print('❌ Face verification error: $e');
      _matchScore = 0;
      _attempts++;
      await _onFail(0);
    }
  }

  Future<void> _onSuccess(Uint8List? photoBytes) async {
    _successCtrl.forward();
    setState(() => _state = _State.success);

    // Mark attendance (supports multiple sessions per day)
    await AttendanceService().markAttendance(
        userId: _user.roleId, userName: _user.name);

    await AuditService().log(
      userId: _user.roleId, userName: _user.name,
      action: 'face_login',
      detail: 'Face verified ✓ — score: ${_matchScore?.toStringAsFixed(1)}%',
    );

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _onFail(double score) async {
    _failCtrl.forward(from: 0);
    setState(() => _state = _State.failed);

    await AuditService().log(
      userId: _user.roleId, userName: _user.name,
      action: 'face_login_failed',
      detail: 'Face mismatch — score: ${score.toStringAsFixed(1)}% < threshold ${_matchThreshold.toStringAsFixed(0)}%'
          ', attempt $_attempts/$_maxAttempts',
    );

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    if (_attempts >= _maxAttempts) {
      // Too many failures — back to login
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Too many failed attempts. Please login again.'),
        backgroundColor: Colors.red,
      ));
      AuthService().logout();
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      // Allow retry
      setState(() { _state = _State.preview; _matchScore = null; });
    }
  }

  Future<void> _skipVerification() async {
    // Allow skip only if no reference photo
    if (_user.photoAsset != null && _refBytes != null) return;
    final attDone = await AttendanceService().isAttendanceDoneToday(_user.roleId);
    if (!attDone) {
      await AttendanceService().markAttendance(
          userId: _user.roleId, userName: _user.name);
    }
    await AuditService().log(
        userId: _user.roleId, userName: _user.name,
        action: 'face_login', detail: 'Skipped — no reference photo set');
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  // ────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────
          _buildHeader(),

          // ── Identity badge ────────────────────────────────────
          _buildIdentityBadge(),

          const SizedBox(height: 12),

          // ── Status label ──────────────────────────────────────
          _buildStatusLabel(),

          const SizedBox(height: 12),

          // ── Main content: side-by-side photos ─────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: isMobile
                  ? _buildMobileLayout()
                  : _buildDesktopLayout(),
            ),
          ),

          // ── Action button ─────────────────────────────────────
          _buildActions(),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
    child: Row(children: [
      Image.asset('assets/images/logo.png', height: 32, fit: BoxFit.contain),
      const Spacer(),
      if (_attempts > 0 && _state != _State.success)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Attempt $_attempts/$_maxAttempts',
            style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      const SizedBox(width: 8),
      TextButton(
        onPressed: () { AuthService().logout(); Navigator.of(context).pushReplacementNamed('/login'); },
        child: const Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 12)),
      ),
    ]),
  );

  // ── Identity badge ─────────────────────────────────────────────
  Widget _buildIdentityBadge() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        // Miniature reference photo
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _refBytes != null
              ? PlatformImage(bytes: _refBytes!, width: 48, height: 48, fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(10))
              : _user.photoAsset != null
                  ? Image.asset(_user.photoAsset!, width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initAvatar(48))
                  : _initAvatar(48),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_user.displayName,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${_user.role} · ${_user.department}',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text('ID: ${_user.roleId}',
              style: const TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.w600)),
        ])),
        // Lock icon showing verification required
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryMid.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.face_retouching_natural_rounded,
              color: AppColors.primaryLight, size: 20),
        ),
      ]),
    ),
  );

  // ── Status label ───────────────────────────────────────────────
  Widget _buildStatusLabel() {
    String text;
    Color color;
    IconData icon;
    switch (_state) {
      case _State.preview:
        text = 'Position your face to match your registered photo';
        color = Colors.white70;
        icon = Icons.info_outline_rounded;
      case _State.processing:
        text = 'Analyzing face…';
        color = AppColors.primaryLight;
        icon = Icons.hourglass_top_rounded;
      case _State.success:
        text = 'Identity Verified ✓ — Score: ${_matchScore?.toStringAsFixed(0)}%';
        color = AppColors.success;
        icon = Icons.verified_rounded;
      case _State.failed:
        text = 'Face Mismatch ✗ — Score: ${_matchScore?.toStringAsFixed(0)}% (need ≥${_matchThreshold.toStringAsFixed(0)}%)';
        color = AppColors.error;
        icon = Icons.gpp_bad_rounded;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_state),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Flexible(child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  // ── Mobile layout (stacked) ────────────────────────────────────
  Widget _buildMobileLayout() {
    return Column(children: [
      Expanded(
        child: Row(children: [
          // Reference photo panel
          Expanded(child: _buildRefPanel()),
          const SizedBox(width: 10),
          // Camera panel
          Expanded(child: _buildCameraPanel()),
        ]),
      ),
    ]);
  }

  // ── Desktop layout (side-by-side) ─────────────────────────────
  Widget _buildDesktopLayout() => Row(
    children: [
      Expanded(child: _buildRefPanel()),
      const SizedBox(width: 16),
      Expanded(child: _buildCameraPanel()),
    ],
  );

  // ── Reference photo panel ──────────────────────────────────────
  Widget _buildRefPanel() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: _state == _State.success
            ? AppColors.success.withValues(alpha: 0.5)
            : _state == _State.failed
                ? AppColors.error.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
        width: 1.5,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(fit: StackFit.expand, children: [
      // Reference image
      _refBytes != null
          ? PlatformImage(bytes: _refBytes!, width: double.infinity, height: double.infinity, fit: BoxFit.cover)
          : _user.photoAsset != null
              ? Image.asset(_user.photoAsset!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _noPhotoPlaceholder())
              : _noPhotoPlaceholder(),
      // Label overlay
      Positioned(bottom: 0, left: 0, right: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
            ),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.person_rounded, size: 12, color: Colors.white60),
            SizedBox(width: 4),
            Text('Registered Photo', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
      ),
      // Success/fail overlay
      if (_state == _State.success)
        Container(
          color: AppColors.success.withValues(alpha: 0.20),
          child: const Center(
            child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48)),
        ),
      if (_state == _State.failed)
        Container(
          color: AppColors.error.withValues(alpha: 0.20),
          child: const Center(
            child: Icon(Icons.cancel_rounded, color: AppColors.error, size: 48)),
        ),
    ]),
  );

  // ── Camera panel ──────────────────────────────────────────────
  Widget _buildCameraPanel() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final borderColor = _state == _State.success
            ? AppColors.success
            : _state == _State.failed
                ? AppColors.error
                : AppColors.primaryMid.withValues(
                    alpha: 0.5 + _pulseCtrl.value * 0.4);
        return Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            // Camera preview
            if (!_cameraReady || _cameraError)
              _noCameraView()
            else if (_ctrl != null && _ctrl!.value.isInitialized)
              CameraPreview(_ctrl!)
            else
              const Center(child: CircularProgressIndicator(
                  color: AppColors.primaryLight, strokeWidth: 2)),

            // Face oval guide
            if (_cameraReady && _state == _State.preview)
              CustomPaint(painter: _OvalPainter(_pulseCtrl.value)),

            // Scanning overlay
            if (_state == _State.processing)
              Container(
                color: AppColors.primaryMid.withValues(alpha: 0.15),
                child: const Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        color: AppColors.primaryLight, strokeWidth: 3),
                    SizedBox(height: 12),
                    Text('Comparing…',
                        style: TextStyle(color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                )),
              ),

            // Label
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
                  ),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.videocam_rounded, size: 12, color: Colors.white60),
                  SizedBox(width: 4),
                  Text('Live Camera', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ),
            ),

            // Success: green check
            if (_state == _State.success)
              Container(
                color: AppColors.success.withValues(alpha: 0.2),
                child: const Center(
                  child: Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 48)),
              ),
            // Fail: red X + shake
            if (_state == _State.failed)
              AnimatedBuilder(
                animation: _failCtrl,
                builder: (_, __) {
                  final shake = (_failCtrl.value * 6 * 3.14).sin() * 8;
                  return Transform.translate(
                    offset: Offset(shake, 0),
                    child: Container(
                      color: AppColors.error.withValues(alpha: 0.2),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close_rounded, color: AppColors.error, size: 48),
                            SizedBox(height: 8),
                            Text('Not Matched',
                                style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ]),
        );
      },
    );
  }

  // ── Action buttons ─────────────────────────────────────────────
  Widget _buildActions() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    child: Column(children: [
      if (_state == _State.preview) ...[
        SizedBox(
          width: double.infinity, height: 50,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                  blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: ElevatedButton.icon(
              onPressed: _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.face_retouching_natural_rounded,
                  color: Colors.white, size: 18),
              label: const Text('Verify & Login',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        if (_cameraError || _user.photoAsset == null || kIsWeb)
          TextButton(
            onPressed: _skipVerification,
            child: Text(kIsWeb ? 'Running on Web — Bypass Verification' : 'No camera available — continue',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
      ],
      if (_state == _State.processing)
        Container(
          width: double.infinity, height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryLight)),
              SizedBox(width: 12),
              Text('Verifying identity…',
                  style: TextStyle(color: Colors.white70, fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      if (_state == _State.failed && _attempts < _maxAttempts)
        Column(children: [
          Container(
            width: double.infinity, height: 50,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                'Authentication Failed — Retrying… (${_maxAttempts - _attempts} left)',
                style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
      if (_state == _State.success)
        Container(
          width: double.infinity, height: 50,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
          ),
          child: const Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text('Verified — Entering portal…',
                  style: TextStyle(color: AppColors.success, fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
    ]),
  );

  // ── Helpers ───────────────────────────────────────────────────
  Widget _initAvatar(double size) => Container(
    width: size, height: size,
    decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient, shape: BoxShape.circle),
    child: Center(child: Text(_user.initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
            fontSize: size * 0.35))),
  );

  Widget _noPhotoPlaceholder() => Container(
    color: const Color(0xFF1A1A2E),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.person_rounded, size: 48, color: Colors.white.withValues(alpha: 0.2)),
      const SizedBox(height: 8),
      Text('No photo\nregistered',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
    ])),
  );

  Widget _noCameraView() => Container(
    color: const Color(0xFF1A1A2E),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.no_photography_outlined, size: 36,
          color: AppColors.warning.withValues(alpha: 0.6)),
      const SizedBox(height: 10),
      const Text('Camera unavailable',
          style: TextStyle(color: Colors.white38, fontSize: 12)),
    ])),
  );
}

// ─────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────
enum _State { preview, processing, success, failed }

// ─────────────────────────────────────────────────────────────────
// Face oval overlay painter
// ─────────────────────────────────────────────────────────────────
class _OvalPainter extends CustomPainter {
  final double pulse;
  _OvalPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.46;
    final rx = size.width * 0.4 + pulse * 3;
    final ry = size.height * 0.42 + pulse * 4;

    // Dark overlay outside oval
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.5));

    // Animated border
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      Paint()
        ..color = const Color(0xFF2563EB).withValues(alpha: 0.5 + pulse * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Corner brackets
    final bp = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final fX in [-1.0, 1.0]) {
      for (final fY in [-1.0, 1.0]) {
        final bx = cx + fX * rx;
        final by = cy + fY * ry * 0.55;
        canvas.drawLine(Offset(bx, by), Offset(bx - fX * 12, by), bp);
        canvas.drawLine(Offset(bx, by), Offset(bx, by - fY * 12), bp);
      }
    }
  }

  @override
  bool shouldRepaint(_OvalPainter old) => old.pulse != pulse;
}

// Extension for sin
extension on double {
  double sin() => _sin(this);
  static double _sin(double x) {
    // Simple sin approximation for shake animation
    return (x - x * x * x / 6.0 + x * x * x * x * x / 120.0)
        .clamp(-1.0, 1.0);
  }
}
