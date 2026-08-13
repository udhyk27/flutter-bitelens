import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/food_analysis.dart';

/// 끼니 종류 (수동 태그 선택지)
const List<String> kMealOptions = ['아침', '점심', '간식', '저녁', '야식'];

/// 시간 기반 기본 끼니 추정
String mealForDate(DateTime dt) {
  final hour = dt.toLocal().hour;
  if (hour >= 5 && hour < 10) return '아침';
  if (hour >= 10 && hour < 14) return '점심';
  if (hour >= 14 && hour < 18) return '간식';
  if (hour >= 18 && hour < 22) return '저녁';
  return '야식';
}

Color mealColorFor(String meal) {
  switch (meal) {
    case '아침':
      return Colors.orange.shade300;
    case '점심':
      return Colors.blue.shade300;
    case '간식':
      return Colors.purple.shade300;
    case '저녁':
      return Colors.teal.shade300;
    default:
      return Colors.grey.shade500;
  }
}

/// 편집 결과
class AnalysisEdit {
  final FoodAnalysis analysis;
  final String meal;
  const AnalysisEdit({required this.analysis, required this.meal});
}

/// 분석 결과 수동 보정 + 끼니 태그 편집 시트.
/// 저장을 누르면 [AnalysisEdit]를, 취소/닫기면 null을 반환한다.
Future<AnalysisEdit?> showAnalysisEditSheet(
  BuildContext context, {
  required FoodAnalysis analysis,
  required String meal,
}) {
  return showModalBottomSheet<AnalysisEdit>(
    context: context,
    backgroundColor: const Color(0xFF141414),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AnalysisEditSheet(analysis: analysis, meal: meal),
  );
}

class _AnalysisEditSheet extends StatefulWidget {
  final FoodAnalysis analysis;
  final String meal;
  const _AnalysisEditSheet({required this.analysis, required this.meal});

  @override
  State<_AnalysisEditSheet> createState() => _AnalysisEditSheetState();
}

class _AnalysisEditSheetState extends State<_AnalysisEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _cal;
  late final TextEditingController _carbs;
  late final TextEditingController _protein;
  late final TextEditingController _fat;
  late final TextEditingController _sodium;
  late final TextEditingController _fiber;
  late String _meal;
  late final bool _showExtra;

  @override
  void initState() {
    super.initState();
    final a = widget.analysis;
    _name = TextEditingController(text: a.foodName ?? '');
    _cal = TextEditingController(text: a.calories?.toString() ?? '');
    _carbs = TextEditingController(text: _numStr(a.carbs));
    _protein = TextEditingController(text: _numStr(a.protein));
    _fat = TextEditingController(text: _numStr(a.fat));
    _sodium = TextEditingController(text: _numStr(a.sodium));
    _fiber = TextEditingController(text: _numStr(a.fiber));
    _meal = kMealOptions.contains(widget.meal) ? widget.meal : mealForDate(DateTime.now());
    _showExtra = a.sodium != null || a.fiber != null;
  }

  @override
  void dispose() {
    _name.dispose();
    _cal.dispose();
    _carbs.dispose();
    _protein.dispose();
    _fat.dispose();
    _sodium.dispose();
    _fiber.dispose();
    super.dispose();
  }

  static String _numStr(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  void _save() {
    final a = widget.analysis;
    final name = _name.text.trim();
    final edited = FoodAnalysis.manual(
      foodName: name.isEmpty ? null : name,
      calories: int.tryParse(_cal.text.trim()),
      carbs: double.tryParse(_carbs.text.trim().replaceAll(',', '.')),
      protein: double.tryParse(_protein.text.trim().replaceAll(',', '.')),
      fat: double.tryParse(_fat.text.trim().replaceAll(',', '.')),
      sodium: double.tryParse(_sodium.text.trim().replaceAll(',', '.')),
      fiber: double.tryParse(_fiber.text.trim().replaceAll(',', '.')),
      note: a.note,
    );
    Navigator.pop(context, AnalysisEdit(analysis: edited, meal: _meal));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('기록 수정',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('AI 추정값을 실제 값으로 보정할 수 있어요',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 24),

              _label('음식 이름'),
              _textField(_name, hint: '예: 김치찌개', number: false),
              const SizedBox(height: 20),

              _label('끼니'),
              Wrap(
                spacing: 8,
                children: kMealOptions.map((m) {
                  final sel = m == _meal;
                  final c = mealColorFor(m);
                  return GestureDetector(
                    onTap: () => setState(() => _meal = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? c.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? c : Colors.white.withOpacity(0.08)),
                      ),
                      child: Text(m,
                          style: TextStyle(
                            color: sel ? c : Colors.white54,
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              _label('칼로리 (kcal)'),
              _textField(_cal, hint: '예: 450'),
              const SizedBox(height: 20),

              _label('영양소 (g)'),
              Row(children: [
                Expanded(child: _miniField('탄수화물', _carbs)),
                const SizedBox(width: 10),
                Expanded(child: _miniField('단백질', _protein)),
                const SizedBox(width: 10),
                Expanded(child: _miniField('지방', _fat)),
              ]),

              if (_showExtra) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _miniField('나트륨(mg)', _sodium)),
                  const SizedBox(width: 10),
                  Expanded(child: _miniField('식이섬유(g)', _fiber)),
                ]),
              ],

              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('취소',
                            style: TextStyle(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('저장',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 0.5)),
      );

  Widget _textField(TextEditingController c, {String? hint, bool number = true}) {
    return TextField(
      controller: c,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : null,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepOrange),
        ),
      ),
    );
  }

  Widget _miniField(String label, TextEditingController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10)),
        const SizedBox(height: 5),
        _textField(c, hint: '-'),
      ],
    );
  }
}
