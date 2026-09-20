// FoodAnalysis 모델의 파싱/직렬화/스케일 로직 단위 테스트.
// (순수 Dart 로직이라 Flutter/Firebase 의존성 없이 안정적으로 실행됨)

import 'package:flutter_test/flutter_test.dart';
import 'package:bitelens/models/food_analysis.dart';

void main() {
  group('FoodAnalysis.parse - JSON 포맷', () {
    test('기본 필드를 파싱한다', () {
      final a = FoodAnalysis.parse(
        '{"foodName":"김치찌개","calories":450,'
        '"carbohydrates":30.5,"protein":25,"fat":20,"portion":1.0}',
      );
      expect(a.foodName, '김치찌개');
      expect(a.calories, 450);
      expect(a.carbs, 30.5);
      expect(a.protein, 25);
      expect(a.fat, 20);
      expect(a.hasNutrition, isTrue);
    });

    test('carbs 별칭 키도 인식한다', () {
      final a = FoodAnalysis.parse('{"foodName":"밥","calories":300,"carbs":60}');
      expect(a.carbs, 60);
    });

    test('영양소가 없으면 hasNutrition은 false', () {
      final a = FoodAnalysis.parse('그냥 자유 텍스트일 뿐');
      expect(a.hasNutrition, isFalse);
    });
  });

  group('FoodAnalysis - 직렬화 왕복(roundtrip)', () {
    test('toJsonString → parse 결과가 보존된다', () {
      final original = FoodAnalysis.manual(
        foodName: '샐러드',
        calories: 200,
        carbs: 10,
        protein: 5,
        fat: 12,
      );
      final restored = FoodAnalysis.parse(original.toJsonString());
      expect(restored.foodName, '샐러드');
      expect(restored.calories, 200);
      expect(restored.carbs, 10);
      expect(restored.protein, 5);
      expect(restored.fat, 12);
    });
  });

  group('FoodAnalysis.scale - 먹은 양 배수', () {
    test('숫자 필드가 배수만큼 스케일되고 portion에 기록된다', () {
      final base = FoodAnalysis.manual(
        foodName: '밥',
        calories: 300,
        carbs: 60,
        protein: 6,
        fat: 1,
      );
      final doubled = base.scale(2.0);
      expect(doubled.calories, 600);
      expect(doubled.carbs, 120);
      expect(doubled.protein, 12);
      expect(doubled.portion, 2.0);
      // 음식명은 유지
      expect(doubled.foodName, '밥');
    });

    test('0.5배도 정확히 계산된다', () {
      final base = FoodAnalysis.manual(foodName: '피자', calories: 800);
      final half = base.scale(0.5);
      expect(half.calories, 400);
    });
  });

  group('FoodAnalysis.parse - 레거시 자연어 포맷', () {
    test('음식 이름/칼로리/탄수화물 라인을 추출한다', () {
      final a = FoodAnalysis.parse(
        '음식 이름: 라면\n칼로리: 500 kcal\n탄수화물: 70g',
      );
      expect(a.foodName, '라면');
      expect(a.calories, 500);
      expect(a.carbs, 70);
    });
  });
}
