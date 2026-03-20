import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _selectedGender = '남성';
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _selectedActivity = '보통 (주 3~5회 운동)';

  double? _bmi;
  double? _bmr;
  double? _tdee;

  final List<String> _activityOptions = [
    '거의 안 함',
    '가벼운 활동 (주 1~2회)',
    '보통 (주 3~5회 운동)',
    '활동적 (주 6~7회 운동)',
    '매우 활동적',
  ];

  final Map<String, double> _activityMultiplier = {
    '거의 안 함': 1.2,
    '가벼운 활동 (주 1~2회)': 1.375,
    '보통 (주 3~5회 운동)': 1.55,
    '활동적 (주 6~7회 운동)': 1.725,
    '매우 활동적': 1.9,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedGender = prefs.getString('gender') ?? '남성';
      _selectedActivity = prefs.getString('activity') ?? '보통 (주 3~5회 운동)';
      _ageController.text = prefs.getString('age') ?? '';
      _heightController.text = prefs.getString('height') ?? '';
      _weightController.text = prefs.getString('weight') ?? '';
    });
    _calculate();
  }

  Future<void> _saveBodyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gender', _selectedGender);
    await prefs.setString('age', _ageController.text);
    await prefs.setString('height', _heightController.text);
    await prefs.setString('weight', _weightController.text);
    await prefs.setString('activity', _selectedActivity);
    if (_tdee != null) await prefs.setDouble('tdee', _tdee!);
  }

  void _calculate() {
    final age = double.tryParse(_ageController.text);
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);

    if (age == null || height == null || weight == null || height == 0) {
      setState(() { _bmi = null; _bmr = null; _tdee = null; });
      return;
    }

    final bmi = weight / ((height / 100) * (height / 100));
    final bmr = _selectedGender == '남성'
        ? 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age)
        : 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
    final multiplier = _activityMultiplier[_selectedActivity] ?? 1.55;

    setState(() {
      _bmi = bmi;
      _bmr = bmr;
      _tdee = bmr * multiplier;
    });
  }

  String _getBmiLabel(double bmi) {
    if (bmi < 18.5) return '저체중';
    if (bmi < 23.0) return '정상';
    if (bmi < 25.0) return '과체중';
    return '비만';
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.blue.shade300;
    if (bmi < 23.0) return Colors.green.shade400;
    if (bmi < 25.0) return Colors.orange.shade300;
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'MY PROFILE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // 상단 안내
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.deepOrange.withOpacity(0.2)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Colors.deepOrange, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '입력한 정보를 기반으로 칼로리 분석 기준이 설정됩니다',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ─── 신체 정보 입력 ───────────────────────
              _SectionHeader(title: '신체 정보'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [

                    // 성별
                    Row(
                      children: [
                        const Icon(Icons.person_outline, color: Colors.white38, size: 20),
                        const SizedBox(width: 14),
                        const Text('성별',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const Spacer(),
                        _GenderToggle(
                          value: _selectedGender,
                          onChanged: (val) async {
                            setState(() => _selectedGender = val);
                            _calculate();
                            await _saveBodyInfo();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _HairLine(),
                    const SizedBox(height: 16),

                    // 나이 / 키 / 몸무게
                    Row(
                      children: [
                        Expanded(
                          child: _BodyInputField(
                            controller: _ageController,
                            label: '나이',
                            unit: '세',
                            onChanged: (_) async {
                              _calculate();
                              await _saveBodyInfo();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _BodyInputField(
                            controller: _heightController,
                            label: '키',
                            unit: 'cm',
                            onChanged: (_) async {
                              _calculate();
                              await _saveBodyInfo();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _BodyInputField(
                            controller: _weightController,
                            label: '몸무게',
                            unit: 'kg',
                            onChanged: (_) async {
                              _calculate();
                              await _saveBodyInfo();
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _HairLine(),
                    const SizedBox(height: 16),

                    // 활동량
                    Row(
                      children: [
                        const Icon(Icons.directions_run_outlined,
                            color: Colors.white38, size: 20),
                        const SizedBox(width: 14),
                        const Text('활동량',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const Spacer(),
                        DropdownButton<String>(
                          value: _selectedActivity,
                          dropdownColor: const Color(0xFF1A1A1A),
                          underline: const SizedBox(),
                          icon: const Icon(Icons.chevron_right,
                              color: Colors.white24, size: 18),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          items: _activityOptions
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) async {
                            if (val != null) {
                              setState(() => _selectedActivity = val);
                              _calculate();
                              await _saveBodyInfo();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ─── 결과 ─────────────────────────────────
              if (_bmi != null && _bmr != null && _tdee != null) ...[
                _SectionHeader(title: '분석 결과'),
                const SizedBox(height: 12),

                // BMI 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BMI',
                          style: TextStyle(
                              color: Colors.white30,
                              fontSize: 11,
                              letterSpacing: 2)),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _bmi!.toStringAsFixed(1),
                            style: TextStyle(
                              color: _getBmiColor(_bmi!),
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getBmiColor(_bmi!).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getBmiLabel(_bmi!),
                                style: TextStyle(
                                  color: _getBmiColor(_bmi!),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _BmiGaugeBar(bmi: _bmi!),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('저체중', style: TextStyle(color: Colors.white24, fontSize: 10)),
                          Text('정상', style: TextStyle(color: Colors.white24, fontSize: 10)),
                          Text('과체중', style: TextStyle(color: Colors.white24, fontSize: 10)),
                          Text('비만', style: TextStyle(color: Colors.white24, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // BMR / TDEE 카드
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: '기초대사량',
                        sublabel: 'BMR',
                        value: _bmr!.toStringAsFixed(0),
                        unit: 'kcal',
                        icon: Icons.favorite_border,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: '일일 권장칼로리',
                        sublabel: 'TDEE',
                        value: _tdee!.toStringAsFixed(0),
                        unit: 'kcal',
                        icon: Icons.local_fire_department_outlined,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 안내 텍스트
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '* 해리스-베네딕트 공식 기반 추정치입니다. 개인차가 있을 수 있어요.',
                    style: TextStyle(color: Colors.white24, fontSize: 11, height: 1.5),
                  ),
                ),
              ] else ...[
                // 빈 상태
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.calculate_outlined, color: Colors.white12, size: 40),
                      SizedBox(height: 12),
                      Text(
                        '신체 정보를 입력하면\nBMI와 기초대사량이 계산됩니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white24, fontSize: 13, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 위젯 ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white30,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _HairLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 0.5, color: Colors.white.withOpacity(0.06));
  }
}

class _GenderToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _GenderToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: ['남성', '여성'].map((g) {
          final selected = value == g;
          return GestureDetector(
            onTap: () => onChanged(g),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? Colors.deepOrange : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                g,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BodyInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  final ValueChanged<String> onChanged;

  const _BodyInputField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white30, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              border: InputBorder.none,
              hintText: unit,
              hintStyle:
              const TextStyle(color: Colors.white12, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _BmiGaugeBar extends StatelessWidget {
  final double bmi;
  const _BmiGaugeBar({required this.bmi});

  @override
  Widget build(BuildContext context) {
    final clamped = bmi.clamp(15.0, 35.0);
    final fraction = (clamped - 15.0) / 20.0;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return SizedBox(
        height: 8,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF64B5F6),
                    Color(0xFF81C784),
                    Color(0xFFFFB74D),
                    Color(0xFFE57373),
                  ],
                ),
              ),
            ),
            Positioned(
              left: (width * fraction - 4).clamp(0, width - 8),
              top: -1,
              child: Container(
                width: 8,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5), blurRadius: 4)
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(sublabel,
                  style: TextStyle(
                      color: color, fontSize: 11, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(unit,
              style:
              const TextStyle(color: Colors.white24, fontSize: 12)),
          const SizedBox(height: 6),
          Text(label,
              style:
              const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}