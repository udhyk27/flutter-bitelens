import 'dart:convert';

/// 음식 분석 결과 모델.
///
/// DB의 `result` 컬럼에는 두 가지 포맷이 저장될 수 있다:
///   1) 신규: Gemini 구조화 출력(JSON 문자열)
///   2) 레거시: 자연어 텍스트("음식 이름: ...\n예상 칼로리: ...")
///
/// [FoodAnalysis.parse]가 두 포맷을 모두 흡수하므로, 화면/집계 코드는
/// 포맷을 신경 쓰지 않고 타입이 정해진 필드만 사용하면 된다.
class FoodAnalysis {
  final String? foodName;
  final int? calories; // kcal
  final double? carbs; // g
  final double? protein; // g
  final double? fat; // g
  final double? sodium; // mg
  final double? fiber; // g
  final String? note;

  // 표시용 문자열 (레거시는 원문 유지, JSON은 포맷 결과)
  final String? caloriesText;
  final String? carbsText;
  final String? proteinText;
  final String? fatText;
  final String? sodiumText;
  final String? fiberText;

  /// 레거시 자연어 원문(있으면 상세 화면에서 그대로 노출). JSON이면 null.
  final String? _rawFallback;

  const FoodAnalysis({
    this.foodName,
    this.calories,
    this.carbs,
    this.protein,
    this.fat,
    this.sodium,
    this.fiber,
    this.note,
    this.caloriesText,
    this.carbsText,
    this.proteinText,
    this.fatText,
    this.sodiumText,
    this.fiberText,
    String? rawFallback,
  }) : _rawFallback = rawFallback;

  /// 칼로리 또는 주요 영양소가 하나라도 있으면 true (히스토리 저장 조건 판단용)
  bool get hasNutrition =>
      calories != null || carbs != null || protein != null || fat != null;

  /// 화면 표시 및 공유용 사람이 읽기 좋은 텍스트.
  /// 레거시 기록은 원문을 그대로, JSON 기록은 필드로 요약을 구성한다.
  String get displayText {
    if (_rawFallback != null) return _rawFallback;

    final b = StringBuffer();
    if (foodName != null && foodName!.isNotEmpty) b.writeln(foodName);
    if (caloriesText != null && caloriesText != '-') {
      b.writeln('칼로리: $caloriesText');
    }
    final macros = <String>[];
    if (carbsText != null && carbsText != '-') macros.add('탄수화물 $carbsText');
    if (proteinText != null && proteinText != '-') macros.add('단백질 $proteinText');
    if (fatText != null && fatText != '-') macros.add('지방 $fatText');
    if (sodiumText != null && sodiumText != '-') macros.add('나트륨 $sodiumText');
    if (fiberText != null && fiberText != '-') macros.add('식이섬유 $fiberText');
    if (macros.isNotEmpty) b.writeln(macros.join(' · '));
    if (note != null && note!.isNotEmpty) {
      b.writeln();
      b.writeln(note);
    }
    final out = b.toString().trim();
    return out.isEmpty ? '분석 결과를 표시할 수 없습니다.' : out;
  }

  // ─── 파싱 진입점 ─────────────────────────────────────────

  static FoodAnalysis parse(String raw) {
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> &&
            (decoded.containsKey('foodName') ||
                decoded.containsKey('calories'))) {
          return FoodAnalysis._fromJson(decoded);
        }
      } catch (_) {
        // JSON 파싱 실패 → 레거시로 폴백
      }
    }
    return FoodAnalysis._fromLegacy(raw);
  }

  // ─── JSON 포맷 ───────────────────────────────────────────

  factory FoodAnalysis._fromJson(Map<String, dynamic> j) {
    double? toD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
    }

    int? toI(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.round();
      final m = RegExp(r'\d+').firstMatch(v.toString());
      return m != null ? int.tryParse(m.group(0)!) : null;
    }

    final cal = toI(j['calories']);
    final carbs = toD(j['carbohydrates'] ?? j['carbs']);
    final protein = toD(j['protein']);
    final fat = toD(j['fat']);
    final sodium = toD(j['sodium']);
    final fiber = toD(j['fiber']);

    final name = (j['foodName'] as Object?)?.toString().trim();
    final note = (j['note'] as Object?)?.toString().trim();

    return FoodAnalysis(
      foodName: (name == null || name.isEmpty) ? null : name,
      calories: cal,
      carbs: carbs,
      protein: protein,
      fat: fat,
      sodium: sodium,
      fiber: fiber,
      note: (note == null || note.isEmpty) ? null : note,
      caloriesText: cal != null ? '$cal kcal' : '-',
      carbsText: _grams(carbs),
      proteinText: _grams(protein),
      fatText: _grams(fat),
      sodiumText: sodium != null ? '${_fmt(sodium)}mg' : null,
      fiberText: fiber != null ? _grams(fiber) : null,
    );
  }

  // ─── 레거시 자연어 포맷 ───────────────────────────────────

  factory FoodAnalysis._fromLegacy(String raw) {
    String? field(String key) {
      for (final line in raw.split('\n')) {
        if (line.contains(key)) {
          final parts = line.split(':');
          if (parts.length > 1) {
            String val = parts[1].trim();
            if (val.contains('(')) {
              val = val.substring(0, val.indexOf('(')).trim();
            }
            return val.isEmpty ? null : val;
          }
        }
      }
      return null;
    }

    double? gramsOf(String? text) {
      if (text == null) return null;
      final m = RegExp(r'([\d.]+)').firstMatch(text);
      return m != null ? double.tryParse(m.group(1)!) : null;
    }

    final calText = field('칼로리') ?? field('예상 칼로리');
    int? calInt;
    if (calText != null) {
      final m = RegExp(r'(\d+)').firstMatch(calText);
      calInt = m != null ? int.tryParse(m.group(1)!) : null;
    }

    final carbsText = field('탄수화물');
    final proteinText = field('단백질');
    final fatText = field('지방');
    final sodiumText = field('나트륨');
    final fiberText = field('식이섬유');

    return FoodAnalysis(
      foodName: field('음식 이름'),
      calories: calInt,
      carbs: gramsOf(carbsText),
      protein: gramsOf(proteinText),
      fat: gramsOf(fatText),
      sodium: gramsOf(sodiumText),
      fiber: gramsOf(fiberText),
      caloriesText: calText,
      carbsText: carbsText,
      proteinText: proteinText,
      fatText: fatText,
      sodiumText: sodiumText,
      fiberText: fiberText,
      rawFallback: raw,
    );
  }

  // ─── 포맷 헬퍼 ───────────────────────────────────────────

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static String _grams(double? v) => v == null ? '-' : '${_fmt(v)}g';
}
