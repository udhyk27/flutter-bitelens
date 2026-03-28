import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bitelens/services/database_service.dart';
import 'package:share_plus/share_plus.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await DatabaseHelper.instance.getAnalysisHistory();
    setState(() {
      _history = data;
      _isLoading = false;
    });
  }

  Future<void> _deleteItem(int id) async {
    await DatabaseHelper.instance.deleteAnalysis(id);
    await _loadHistory();
  }

  /// 날짜별 그룹핑 — { '2025.01.15': [...], ... }
  Map<String, List<Map<String, dynamic>>> _groupByDate() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in _history) {
      final dt = DateTime.parse(item['created_at'] as String);
      final key = _dateLabel(dt);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  String _timeLabel(String isoDate) {
    final dt = DateTime.parse(isoDate);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1)),
      );
    }

    final grouped = _groupByDate();
    final dateKeys = grouped.keys.toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'HISTORY',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 6),
        ),
        centerTitle: true,
        actions: [
          if (_history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '총 ${_history.length}개',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _history.isEmpty
          ? _buildEmpty()
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: dateKeys.length,
        itemBuilder: (context, i) {
          final dateKey = dateKeys[i];
          final items = grouped[dateKey]!;
          // 해당 날짜 총 칼로리 합산
          final totalCal = items.fold<int>(0, (sum, item) {
            final cal = NutritionParser.parseCaloriesInt(item['result'] as String);
            return sum + (cal ?? 0);
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 날짜 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
                child: Row(
                  children: [
                    Text(
                      dateKey,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(height: 0.5, width: 20, color: Colors.white12),
                    const Spacer(),
                    if (totalCal > 0)
                      Text(
                        '총 ${totalCal} kcal',
                        style: const TextStyle(color: Colors.deepOrange, fontSize: 11),
                      ),
                  ],
                ),
              ),
              // 카드 목록
              ...items.map((item) => _HistoryCard(
                imagePath: item['image_path'] as String,
                result: item['result'] as String,
                time: _timeLabel(item['created_at'] as String),
                onDelete: () => _showDeleteDialog(item['id'] as int),
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.history, size: 56, color: Colors.white12),
          SizedBox(height: 16),
          Text('분석 기록이 없어요',
              style: TextStyle(color: Colors.white30, fontSize: 15, letterSpacing: 1)),
          SizedBox(height: 8),
          Text('음식을 촬영해서 분석해보세요',
              style: TextStyle(color: Colors.white12, fontSize: 13)),
        ],
      ),
    );
  }

  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('기록 삭제', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('이 기록을 삭제할까요?',
            style: TextStyle(color: Colors.white54, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); _deleteItem(id); },
            child: const Text('삭제', style: TextStyle(color: Colors.deepOrange)),
          ),
        ],
      ),
    );
  }
}

// ─── 영양소 파서 (result_screen에서도 공유 사용) ──────────────────────

class NutritionParser {
  static String? parse(String result, String key) {
    for (final line in result.split('\n')) {
      if (line.contains(key)) {
        final parts = line.split(':');
        if (parts.length > 1) {
          String val = parts[1].trim();
          if (val.contains('(')) val = val.substring(0, val.indexOf('(')).trim();
          return val.isEmpty ? null : val;
        }
      }
    }
    return null;
  }

  static String foodName(String result) => parse(result, '음식 이름') ?? '음식';
  static String calories(String result) => parse(result, '칼로리') ?? parse(result, '예상 칼로리') ?? '-';
  static String carbs(String result) => parse(result, '탄수화물') ?? '-';
  static String protein(String result) => parse(result, '단백질') ?? '-';
  static String fat(String result) => parse(result, '지방') ?? '-';
  static String sodium(String result) => parse(result, '나트륨') ?? '-';
  static String fiber(String result) => parse(result, '식이섬유') ?? '-';

  /// 칼로리 숫자만 추출 (합산용)
  static int? parseCaloriesInt(String result) {
    final raw = calories(result);
    final match = RegExp(r'(\d+)').firstMatch(raw);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// g 단위 숫자 추출 (그래프용)
  static double? parseGrams(String result, String key) {
    final raw = parse(result, key);
    if (raw == null) return null;
    final match = RegExp(r'([\d.]+)').firstMatch(raw);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }
}

// ─── 히스토리 카드 ────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final String imagePath;
  final String result;
  final String time;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.imagePath,
    required this.result,
    required this.time,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final foodName = NutritionParser.foodName(result);
    final calories = NutritionParser.calories(result);
    final carbs = NutritionParser.carbs(result);
    final protein = NutritionParser.protein(result);
    final fat = NutritionParser.fat(result);

    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            // 썸네일
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 86, height: 86,
                child: File(imagePath).existsSync()
                    ? Image.file(File(imagePath), fit: BoxFit.cover)
                    : Container(
                  color: const Color(0xFF1E1E1E),
                  child: const Icon(Icons.image_not_supported, color: Colors.white12, size: 24),
                ),
              ),
            ),

            // 내용
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(foodName,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Text(time, style: const TextStyle(color: Colors.white24, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 칼로리 뱃지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(calories,
                          style: const TextStyle(color: Colors.deepOrange, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    // 영양소 미니 태그
                    Row(
                      children: [
                        Flexible(child: _NutriBadge(label: '탄', value: carbs, color: Colors.blue.shade300)),
                        const SizedBox(width: 6),
                        Flexible(child: _NutriBadge(label: '단', value: protein, color: Colors.green.shade400)),
                        const SizedBox(width: 6),
                        Flexible(child: _NutriBadge(label: '지', value: fat, color: Colors.orange.shade300)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 삭제 버튼
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.white12, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // 핸들 + 공유
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Spacer(),
                  Container(width: 36, height: 4,
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.ios_share, color: Colors.white54, size: 20),
                        onPressed: () async {
                          try {
                            await Share.shareXFiles([XFile(imagePath)],
                                text: result, subject: 'BiteLens 음식 분석 결과');
                          } catch (e) { debugPrint('공유 오류: $e'); }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이미지
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: File(imagePath).existsSync()
                          ? Image.file(File(imagePath),
                          width: double.infinity, height: 200, fit: BoxFit.cover)
                          : Container(height: 200, color: const Color(0xFF1E1E1E),
                          child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white12))),
                    ),

                    const SizedBox(height: 20),

                    // 영양소 카드
                    _NutritionCard(result: result),

                    const SizedBox(height: 16),

                    // 결과 헤더
                    Row(children: [
                      Container(width: 3, height: 18,
                          decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      const Text('분석 결과',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    ]),
                    const SizedBox(height: 12),

                    // 결과 텍스트
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.07)),
                      ),
                      child: Text(result,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.8)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 영양소 카드 (바텀시트 상세용) ───────────────────────────────────

class _NutritionCard extends StatelessWidget {
  final String result;
  const _NutritionCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final carbs = NutritionParser.parseGrams(result, '탄수화물');
    final protein = NutritionParser.parseGrams(result, '단백질');
    final fat = NutritionParser.parseGrams(result, '지방');
    final total = (carbs ?? 0) + (protein ?? 0) + (fat ?? 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 칼로리 크게
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.local_fire_department_outlined, color: Colors.deepOrange, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  NutritionParser.calories(result),
                  style: const TextStyle(color: Colors.deepOrange, fontSize: 22, fontWeight: FontWeight.w700, height: 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (total > 0) ...[
            const SizedBox(height: 16),
            // 비율 바
            _MacroBar(carbs: carbs ?? 0, protein: protein ?? 0, fat: fat ?? 0, total: total),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 12),

          // 영양소 행
          Row(
            children: [
              Expanded(child: _MacroItem(label: '탄수화물', value: NutritionParser.carbs(result), color: Colors.blue.shade300)),
              Expanded(child: _MacroItem(label: '단백질', value: NutritionParser.protein(result), color: Colors.green.shade400)),
              Expanded(child: _MacroItem(label: '지방', value: NutritionParser.fat(result), color: Colors.orange.shade300)),
            ],
          ),

          // 상세 분석인 경우 나트륨/식이섬유
          if (NutritionParser.sodium(result) != '-' || NutritionParser.fiber(result) != '-') ...[
            const SizedBox(height: 12),
            Container(height: 0.5, color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (NutritionParser.sodium(result) != '-')
                  Expanded(child: _MacroItem(label: '나트륨', value: NutritionParser.sodium(result), color: Colors.yellow.shade600)),
                if (NutritionParser.fiber(result) != '-')
                  Expanded(child: _MacroItem(label: '식이섬유', value: NutritionParser.fiber(result), color: Colors.teal.shade300)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final double carbs, protein, fat, total;
  const _MacroBar({required this.carbs, required this.protein, required this.fat, required this.total});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final carbW = total > 0 ? (carbs / total * w) : 0.0;
      final protW = total > 0 ? (protein / total * w) : 0.0;
      final fatW = total > 0 ? (fat / total * w) : 0.0;
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Container(width: carbW, color: Colors.blue.shade300),
                  Container(width: protW, color: Colors.green.shade400),
                  Container(width: fatW, color: Colors.orange.shade300),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _BarLegend(color: Colors.blue.shade300,
                  label: '탄 ${total > 0 ? (carbs / total * 100).toStringAsFixed(0) : 0}%'),
              const SizedBox(width: 12),
              _BarLegend(color: Colors.green.shade400,
                  label: '단 ${total > 0 ? (protein / total * 100).toStringAsFixed(0) : 0}%'),
              const SizedBox(width: 12),
              _BarLegend(color: Colors.orange.shade300,
                  label: '지 ${total > 0 ? (fat / total * 100).toStringAsFixed(0) : 0}%'),
            ],
          ),
        ],
      );
    });
  }
}

class _BarLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _BarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ],
  );
}

class _MacroItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MacroItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
    ],
  );
}

class _NutriBadge extends StatelessWidget {
  final String label, value;
  final Color color;
  const _NutriBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 70),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Center(child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            value == '-' ? '-' : value,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}