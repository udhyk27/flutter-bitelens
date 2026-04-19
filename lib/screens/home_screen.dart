import 'package:bitelens/screens/profile_screen.dart';
import 'package:bitelens/screens/result_screen.dart';
import 'package:bitelens/screens/settings_screen.dart';
import 'package:bitelens/services/database_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late CameraController controller;
  bool _isInitialized = false;
  bool _isProfileSet = false;
  int _todayCalories = 0;
  double? _tdee;

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

    controller = CameraController(widget.cameras[0], ResolutionPreset.max, enableAudio: false);
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isInitialized = true);
    }).catchError((Object e) {});

    _checkProfileSet();
    _loadTodayStats();
  }

  @override
  void dispose() {
    controller.dispose();
    _pulseController.dispose();
    super.dispose();
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
    final history = await DatabaseHelper.instance.getAnalysisHistory();
    final now = DateTime.now();
    final todayCal = history.fold<int>(0, (sum, r) {
      final dt = DateTime.parse(r['created_at'] as String).toLocal();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return sum + (NutritionParser.parseCaloriesInt(r['result'] as String) ?? 0);
      }
      return sum;
    });
    if (!mounted) return;
    setState(() {
      _todayCalories = todayCal;
      _tdee = tdee;
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

      body: _isInitialized
          ? Stack(
        children: [
          Positioned.fill(child: CameraPreview(controller)),
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
                      _TodayCalBanner(todayCalories: _todayCalories, tdee: _tdee),
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
                  ).then((_) => _checkProfileSet()); // 돌아왔을 때 재확인
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
                ).then((_) => _checkProfileSet());
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
    if (!controller.value.isInitialized || controller.value.isTakingPicture) return;
    try {
      final XFile image = await controller.takePicture();
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
  const _TodayCalBanner({required this.todayCalories, this.tdee});

  @override
  Widget build(BuildContext context) {
    final ratio = (tdee != null && tdee! > 0) ? (todayCalories / tdee!).clamp(0.0, 1.0) : null;
    final Color barColor = ratio == null
        ? Colors.white38
        : ratio < 0.5
            ? Colors.green.shade400
            : ratio < 0.85
                ? Colors.orange.shade300
                : Colors.red.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  Container(height: 3, color: Colors.white.withOpacity(0.1)),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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