import 'dart:io';

import 'package:bitelens/models/food_analysis.dart';
import 'package:bitelens/screens/profile_screen.dart';
import 'package:bitelens/screens/result_screen.dart';
import 'package:bitelens/screens/settings_screen.dart';
import 'package:bitelens/services/database_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  CameraController? controller;
  bool _isInitialized = false;
  bool _cameraPermissionDenied = false;
  bool _isProfileSet = false;
  int _todayCalories = 0;
  double? _tdee;
  double _todayCarbs = 0, _todayProtein = 0, _todayFat = 0;
  double? _carbGoal, _proteinGoal, _fatGoal;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.cameras.isEmpty) {
      // 사용 가능한 카메라가 없는 기기 → 크래시 방지
      _cameraPermissionDenied = true;
    } else {
      _initCamera();
    }

    _checkProfileSet();
    _loadTodayStats();
  }

  void _initCamera() {
    final cam = CameraController(widget.cameras[0], ResolutionPreset.max, enableAudio: false);
    controller = cam;
    cam.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isInitialized = true);
    }).catchError((Object e) {
      if (!mounted) return;
      if (e is CameraException) {
        const deniedCodes = [
          'CameraAccessDenied',
          'CameraAccessDeniedWithoutPrompt',
          'CameraAccessRestricted',
          'AudioAccessDenied',
          'AudioAccessDeniedWithoutPrompt',
        ];
        if (deniedCodes.contains(e.code)) {
          setState(() => _cameraPermissionDenied = true);
          return;
        }
      }
      debugPrint('카메라 초기화 오류: $e');
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _openAppSettings() async {
    final uri = Platform.isIOS
        ? Uri.parse('app-settings:')
        : Uri.parse('package:com.aiid.bitelens.bitelens');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _checkProfileSet() async {
    final prefs = await SharedPreferences.getInstance();
    final height = prefs.getString('height') ?? '';
    final weight = prefs.getString('weight') ?? '';
    final age = prefs.getString('age') ?? '';
    setState(() => _isProfileSet = height.isNotEmpty && weight.isNotEmpty && age.isNotEmpty);
  }

  Future<void> _loadTodayStats() async {
    final prefs = await SharedPreferences.getInstance();
    final tdee = prefs.getDouble('tdee');
    final carbGoal = prefs.getDouble('carb_goal');
    final proteinGoal = prefs.getDouble('protein_goal');
    final fatGoal = prefs.getDouble('fat_goal');
    final history = await DatabaseHelper.instance.getAnalysisHistory();
    final now = DateTime.now();
    int todayCal = 0;
    double carbs = 0, protein = 0, fat = 0;
    for (final r in history) {
      final dt = DateTime.parse(r['created_at'] as String).toLocal();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final a = FoodAnalysis.parse(r['result'] as String);
        todayCal += a.calories ?? 0;
        carbs += a.carbs ?? 0;
        protein += a.protein ?? 0;
        fat += a.fat ?? 0;
      }
    }
    if (!mounted) return;
    setState(() {
      _todayCalories = todayCal;
      _tdee = tdee;
      _todayCarbs = carbs;
      _todayProtein = protein;
      _todayFat = fat;
      _carbGoal = carbGoal;
      _proteinGoal = proteinGoal;
      _fatGoal = fatGoal;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'BITE LENS',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 6),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
              // 프로필 미설정 시 빨간 점
              if (!_isProfileSet)
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),

      drawer: _buildDrawer(),

      body: _cameraPermissionDenied
          ? _CameraPermissionDeniedView(onOpenSettings: _openAppSettings)
          : _isInitialized
          ? Stack(
        children: [
          Positioned.fill(child: CameraPreview(controller!)),
          Positioned(
            top: 0, left: 0, right: 0, height: 160,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0, height: 220,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                ),
              ),
            ),
          ),
          Center(child: _ScanFrame()),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_todayCalories > 0 || _tdee != null)
                      _TodayCalBanner(
                        todayCalories: _todayCalories,
                        tdee: _tdee,
                        carbs: _todayCarbs,
                        protein: _todayProtein,
                        fat: _todayFat,
                        carbGoal: _carbGoal,
                        proteinGoal: _proteinGoal,
                        fatGoal: _fatGoal,
                      ),
                    if (_todayCalories > 0 || _tdee != null) const SizedBox(height: 12),
                    const Text('음식을 프레임에 맞춰주세요',
                        style: TextStyle(color: Colors.white60, fontSize: 13, letterSpacing: 1.2)),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _GalleryButton(onTap: _pickFromGallery),
                        const SizedBox(width: 36),
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: _ShutterButton(onTap: _takePicture),
                        ),
                        const SizedBox(width: 36),
                        const SizedBox(width: 56),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('분석 결과는 참고용입니다',
                        style: TextStyle(color: Colors.white24, fontSize: 11, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          ),
        ],
      )
          : const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1)),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0F0F0F),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 16),
                  const Text('BITE LENS',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4)),
                  const SizedBox(height: 4),
                  const Text('AI 음식 분석기', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),

            // 프로필 미설정 유도 배너
            if (!_isProfileSet)
              ProfileNudgeBanner(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ).then((_) { _checkProfileSet(); _loadTodayStats(); }); // 돌아왔을 때 재확인
                },
              ),

            if (!_isProfileSet) const SizedBox(height: 8),

            _DrawerItem(icon: Icons.home_outlined, label: '홈', onTap: () => Navigator.pop(context)),
            _DrawerItem(
              icon: Icons.history_outlined,
              label: '분석 기록',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
              },
            ),
            _DrawerItem(
              icon: Icons.person_outline,
              label: '내 프로필',
              trailing: !_isProfileSet
                  ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('미설정', style: TextStyle(color: Colors.deepOrange, fontSize: 11)),
              )
                  : null,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ).then((_) { _checkProfileSet(); _loadTodayStats(); });
              },
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: '설정',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(imagePath: image.path)));
    _loadTodayStats();
  }

  Future<void> _takePicture() async {
    final cam = controller;
    if (cam == null || !cam.value.isInitialized || cam.value.isTakingPicture) return;
    try {
      final XFile image = await cam.takePicture();
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(imagePath: image.path)));
      _loadTodayStats();
    } catch (e) {
      debugPrint('촬영 오류: $e');
    }
  }
}

// ─── 위젯들 ───────────────────────────────────────────────────────────

class _ScanFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 260, height: 260, child: CustomPaint(painter: _FramePainter()));
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 32.0;
    const r = 12.0;

    canvas.drawLine(Offset(r, 0), Offset(len, 0), paint);
    canvas.drawLine(Offset(0, r), Offset(0, len), paint);
    canvas.drawArc(const Rect.fromLTWH(0, 0, r * 2, r * 2), 3.14, 1.57, false, paint);

    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, len), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2), 4.71, 1.57, false, paint);

    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height - r), paint);
    canvas.drawLine(Offset(r, size.height), Offset(len, size.height), paint);
    canvas.drawArc(Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2), 1.57, 1.57, false, paint);

    canvas.drawLine(Offset(size.width, size.height - len), Offset(size.width, size.height - r), paint);
    canvas.drawLine(Offset(size.width - len, size.height), Offset(size.width - r, size.height), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, size.height - r * 2, r * 2, r * 2), 0, 1.57, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GalleryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GalleryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.5),
          color: Colors.white10,
        ),
        child: const Icon(Icons.photo_library_outlined, color: Colors.white70, size: 24),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ShutterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color: Colors.transparent,
        ),
        child: Center(
          child: Container(
            width: 62, height: 62,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ─── 오늘 칼로리 요약 배너 ────────────────────────────────────────────

class _TodayCalBanner extends StatelessWidget {
  final int todayCalories;
  final double? tdee;
  final double carbs, protein, fat;
  final double? carbGoal, proteinGoal, fatGoal;
  const _TodayCalBanner({
    required this.todayCalories,
    this.tdee,
    this.carbs = 0,
    this.protein = 0,
    this.fat = 0,
    this.carbGoal,
    this.proteinGoal,
    this.fatGoal,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (tdee != null && tdee! > 0) ? (todayCalories / tdee!).clamp(0.0, 1.0) : null;
    final remaining = tdee != null ? (tdee! - todayCalories).round() : null;
    final isOver = remaining != null && remaining < 0;

    final Color barColor = ratio == null
        ? Colors.white38
        : ratio < 0.5
            ? Colors.green.shade400
            : ratio < 0.85
                ? Colors.orange.shade300
                : Colors.red.shade300;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_outlined, color: Colors.deepOrange, size: 13),
              const SizedBox(width: 5),
              const Text('오늘', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.5)),
              const Spacer(),
              if (ratio != null) ...[
                Text(
                  '${(ratio * 100).toInt()}%',
                  style: TextStyle(color: barColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                tdee != null
                    ? '$todayCalories / ${tdee!.toStringAsFixed(0)} kcal'
                    : '$todayCalories kcal',
                style: TextStyle(color: barColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (ratio != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  Container(height: 4, color: Colors.white.withOpacity(0.1)),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isOver
                  ? '${(-remaining)} kcal 초과'
                  : '$remaining kcal 남음',
              style: TextStyle(
                color: isOver ? Colors.red.shade300 : Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
          if (carbGoal != null && proteinGoal != null && fatGoal != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _MacroMini(label: '탄', value: carbs, goal: carbGoal!, color: Colors.blue.shade300)),
                const SizedBox(width: 8),
                Expanded(child: _MacroMini(label: '단', value: protein, goal: proteinGoal!, color: Colors.green.shade400)),
                const SizedBox(width: 8),
                Expanded(child: _MacroMini(label: '지', value: fat, goal: fatGoal!, color: Colors.orange.shade300)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 매크로 미니 진행바 ───────────────────────────────────────────────

class _MacroMini extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final Color color;
  const _MacroMini({required this.label, required this.value, required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final ratio = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${value.round()}/${goal.round()}g',
                style: const TextStyle(color: Colors.white38, fontSize: 9)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            children: [
              Container(height: 3, color: Colors.white.withOpacity(0.1)),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(height: 3, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 카메라 권한 거부 안내 ─────────────────────────────────────────────

class _CameraPermissionDeniedView extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _CameraPermissionDeniedView({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.no_photography_outlined, color: Colors.white30, size: 36),
            ),
            const SizedBox(height: 28),
            const Text(
              '카메라 권한이 필요해요',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              '음식 사진을 분석하려면\n카메라 접근 권한이 필요합니다.\n설정에서 권한을 허용해주세요.',
              style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.7),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: onOpenSettings,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.deepOrange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '설정으로 이동',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '설정 → 개인 정보 보호 → 카메라',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: Colors.white54, size: 22),
      title: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w400)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}