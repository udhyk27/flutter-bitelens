import "dart:io";

import "package:flutter/material.dart";
import "package:share_plus/share_plus.dart";
import "package:bitelens/l10n/app_locale.dart";
import "package:bitelens/models/food_analysis.dart";
import "package:bitelens/widgets/analysis_edit_sheet.dart";

class NutritionParser {
  static String foodName(String result) =>
      FoodAnalysis.parse(result).foodName ?? '음식';
  static String calories(String result) =>
      FoodAnalysis.parse(result).caloriesText ?? '-';
  static String carbs(String result) =>
      FoodAnalysis.parse(result).carbsText ?? '-';
  static String protein(String result) =>
      FoodAnalysis.parse(result).proteinText ?? '-';
  static String fat(String result) => FoodAnalysis.parse(result).fatText ?? '-';
  static String sodium(String result) =>
      FoodAnalysis.parse(result).sodiumText ?? '-';
  static String fiber(String result) =>
      FoodAnalysis.parse(result).fiberText ?? '-';

  static int? parseCaloriesInt(String result) =>
      FoodAnalysis.parse(result).calories;

  static double portion(String result) => FoodAnalysis.parse(result).portion;

  static double? parseGrams(String result, String key) {
    final a = FoodAnalysis.parse(result);
    switch (key) {
      case '탄수화물':
        return a.carbs;
      case '단백질':
        return a.protein;
      case '지방':
        return a.fat;
      case '나트륨':
        return a.sodium;
      case '식이섬유':
        return a.fiber;
    }
    return null;
  }

  static String mealType(String isoDate) =>
      mealForDate(DateTime.tryParse(isoDate) ?? DateTime.now());

  static Color mealColor(String isoDate) => mealColorFor(mealType(isoDate));
}

// ─── 주간 칼로리 차트 ─────────────────────────────────────────────────

class HistoryWeeklyChart extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyHistory;
  final double? tdee;
  const HistoryWeeklyChart({required this.weeklyHistory, this.tdee});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final calsByDay = {for (final d in days) d: 0};
    for (final item in weeklyHistory) {
      final dt = DateTime.parse(item['created_at'] as String).toLocal();
      final key = DateTime(dt.year, dt.month, dt.day);
      if (calsByDay.containsKey(key)) {
        calsByDay[key] =
            calsByDay[key]! +
            (NutritionParser.parseCaloriesInt(item['result'] as String) ?? 0);
      }
    }

    final maxCal = calsByDay.values.fold<int>(0, (a, b) => a > b ? a : b);
    final dayNames = [
      '월',
      '화',
      '수',
      '목',
      '금',
      '토',
      '일',
    ].map(context.tr).toList();
    const maxBarH = 56.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: Colors.white24,
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                context.tr('이번 주 섭취 칼로리'),
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
              if (tdee != null) ...[
                const Spacer(),
                Text(
                  '${context.tr('Goal')} ${tdee!.toStringAsFixed(0)} kcal',
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.asMap().entries.map((entry) {
              final i = entry.key;
              final day = entry.value;
              final cal = calsByDay[day] ?? 0;
              final isToday = i == 6;
              final ratio = maxCal > 0 ? cal / maxCal : 0.0;
              final barH = maxBarH * (ratio > 0 ? ratio.clamp(0.05, 1.0) : 0.0);
              final overTdee = tdee != null && cal > tdee!;
              final barColor = isToday
                  ? (overTdee ? Colors.red.shade400 : Colors.deepOrange)
                  : (cal > 0
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.transparent);

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cal > 0)
                      Text(
                        cal >= 1000
                            ? '${(cal / 1000).toStringAsFixed(1)}k'
                            : '$cal',
                        style: TextStyle(
                          color: isToday ? Colors.deepOrange : Colors.white24,
                          fontSize: 8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                      ),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: barH,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayNames[(day.weekday - 1) % 7],
                      style: TextStyle(
                        color: isToday ? Colors.deepOrange : Colors.white24,
                        fontSize: 10,
                        fontWeight: isToday
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── 히스토리 카드 ────────────────────────────────────────────────────

class HistoryCard extends StatelessWidget {
  final int id;
  final String imagePath;
  final String result;
  final String time;
  final String createdAt;
  final String? meal;
  final bool isFavorite;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onFavoriteToggle;

  const HistoryCard({
    required this.id,
    required this.imagePath,
    required this.result,
    required this.time,
    required this.createdAt,
    required this.meal,
    required this.isFavorite,
    required this.onDelete,
    required this.onEdit,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final rawFoodName = NutritionParser.foodName(result);
    final foodName = rawFoodName == '음식'
        ? context.tr(rawFoodName)
        : rawFoodName;
    final calories = NutritionParser.calories(result);
    final carbs = NutritionParser.carbs(result);
    final protein = NutritionParser.protein(result);
    final fat = NutritionParser.fat(result);
    final mealLabel = context.tr(meal ?? NutritionParser.mealType(createdAt));
    final mealColor = mealColorFor(mealLabel);
    final portion = NutritionParser.portion(result);

    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            // 썸네일
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: SizedBox(
                width: 86,
                height: 86,
                child: File(imagePath).existsSync()
                    ? Image.file(File(imagePath), fit: BoxFit.cover)
                    : Container(
                        color: const Color(0xFF1E1E1E),
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.white12,
                          size: 24,
                        ),
                      ),
              ),
            ),

            // 내용
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // 식사 시간대 뱃지
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: mealColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            mealLabel,
                            style: TextStyle(
                              color: mealColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            foodName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          time,
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            calories,
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (portion != 1.0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '×${portion == portion.roundToDouble() ? portion.toInt() : portion}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Flexible(
                          child: NutritionBadge(
                            label: context.tr('탄'),
                            value: carbs,
                            color: Colors.blue.shade300,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: NutritionBadge(
                            label: context.tr('단'),
                            value: protein,
                            color: Colors.green.shade400,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: NutritionBadge(
                            label: context.tr('지'),
                            value: fat,
                            color: Colors.orange.shade300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 즐겨찾기 + 삭제
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: onFavoriteToggle,
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_outline,
                    color: isFavorite ? Colors.amber : Colors.white12,
                    size: 18,
                  ),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white12,
                    size: 18,
                  ),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(width: 4),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Spacer(),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () {
                            Navigator.pop(context); // 상세 시트 닫고 편집 열기
                            onEdit();
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.ios_share,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () async {
                            try {
                              await Share.shareXFiles(
                                [XFile(imagePath)],
                                text: FoodAnalysis.parse(
                                  result,
                                ).localizedDisplayText(context),
                                subject: context.tr('BiteLens 음식 분석 결과'),
                              );
                            } catch (e) {
                              debugPrint('공유 오류: $e');
                            }
                          },
                        ),
                      ],
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: File(imagePath).existsSync()
                          ? Image.file(
                              File(imagePath),
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 200,
                              color: const Color(0xFF1E1E1E),
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white12,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    NutritionCard(result: result),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.deepOrange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          context.tr('분석 결과'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Text(
                        FoodAnalysis.parse(
                          result,
                        ).localizedDisplayText(context),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.8,
                        ),
                      ),
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

class NutritionCard extends StatelessWidget {
  final String result;
  const NutritionCard({required this.result});

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
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(
                Icons.local_fire_department_outlined,
                color: Colors.deepOrange,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  NutritionParser.calories(result),
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (total > 0) ...[
            const SizedBox(height: 16),
            _MacroBar(
              carbs: carbs ?? 0,
              protein: protein ?? 0,
              fat: fat ?? 0,
              total: total,
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _MacroItem(
                  label: context.tr('탄수화물'),
                  value: NutritionParser.carbs(result),
                  color: Colors.blue.shade300,
                ),
              ),
              Expanded(
                child: _MacroItem(
                  label: context.tr('단백질'),
                  value: NutritionParser.protein(result),
                  color: Colors.green.shade400,
                ),
              ),
              Expanded(
                child: _MacroItem(
                  label: context.tr('지방'),
                  value: NutritionParser.fat(result),
                  color: Colors.orange.shade300,
                ),
              ),
            ],
          ),

          if (NutritionParser.sodium(result) != '-' ||
              NutritionParser.fiber(result) != '-') ...[
            const SizedBox(height: 12),
            Container(height: 0.5, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (NutritionParser.sodium(result) != '-')
                  Expanded(
                    child: _MacroItem(
                      label: context.tr('나트륨'),
                      value: NutritionParser.sodium(result),
                      color: Colors.yellow.shade600,
                    ),
                  ),
                if (NutritionParser.fiber(result) != '-')
                  Expanded(
                    child: _MacroItem(
                      label: context.tr('식이섬유'),
                      value: NutritionParser.fiber(result),
                      color: Colors.teal.shade300,
                    ),
                  ),
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
  const _MacroBar({
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
                _BarLegend(
                  color: Colors.blue.shade300,
                  label:
                      '${context.tr('탄')} ${total > 0 ? (carbs / total * 100).toStringAsFixed(0) : 0}%',
                ),
                const SizedBox(width: 12),
                _BarLegend(
                  color: Colors.green.shade400,
                  label:
                      '${context.tr('단')} ${total > 0 ? (protein / total * 100).toStringAsFixed(0) : 0}%',
                ),
                const SizedBox(width: 12),
                _BarLegend(
                  color: Colors.orange.shade300,
                  label:
                      '${context.tr('지')} ${total > 0 ? (fat / total * 100).toStringAsFixed(0) : 0}%',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BarLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _BarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ],
  );
}

class _MacroItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MacroItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.white30,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class NutritionBadge extends StatelessWidget {
  final String label, value;
  final Color color;
  const NutritionBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 70),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
