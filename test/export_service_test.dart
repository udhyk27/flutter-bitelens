import 'package:bitelens/models/food_analysis.dart';
import 'package:bitelens/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExportService.buildHistoryCsv', () {
    test('음식명 수식 입력처럼 보이는 값은 텍스트로 내보낸다', () {
      final analysis = FoodAnalysis.manual(foodName: '=1+1', calories: 250);

      final csv = ExportService.buildHistoryCsv([
        {
          'created_at': DateTime(2026, 11, 12, 12).toIso8601String(),
          'meal': '점심',
          'result': analysis.toJsonString(),
        },
      ]);

      expect(csv, contains("점심,'=1+1,250"));
    });

    test('텍스트 셀의 선행 공백과 위험 접두사를 보호한다', () {
      final analysis = FoodAnalysis.manual(foodName: '  @SUM(1,1)');

      final csv = ExportService.buildHistoryCsv([
        {
          'created_at': DateTime(2026, 11, 12, 12).toIso8601String(),
          'meal': '+SUM(1,1)',
          'result': analysis.toJsonString(),
        },
      ]);

      expect(csv, contains("'+SUM(1,1)"));
      expect(csv, contains("'  @SUM(1,1)"));
    });

    test('일반 텍스트 인용과 숫자 값은 그대로 유지한다', () {
      final analysis = FoodAnalysis.manual(
        foodName: '볶음밥, 계란',
        calories: 400,
        carbs: -2,
      );

      final csv = ExportService.buildHistoryCsv([
        {
          'created_at': DateTime(2026, 11, 12, 12).toIso8601String(),
          'meal': '점심',
          'result': analysis.toJsonString(),
        },
      ]);

      expect(csv, contains('점심,"볶음밥, 계란",400,-2'));
    });
  });
}
