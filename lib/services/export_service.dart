import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/food_analysis.dart';
import '../widgets/analysis_edit_sheet.dart';

/// 분석 기록을 CSV로 내보내는 유틸.
class ExportService {
  static const List<String> _headers = [
    '날짜',
    '시간',
    '끼니',
    '음식',
    '칼로리(kcal)',
    '탄수화물(g)',
    '단백질(g)',
    '지방(g)',
    '나트륨(mg)',
    '식이섬유(g)',
    '양(배수)',
    '즐겨찾기',
  ];

  /// analysis_history 행 목록 → CSV 문자열(오래된 순, Excel 호환 UTF-8 BOM 포함).
  static String buildHistoryCsv(List<Map<String, dynamic>> rows) {
    final sorted = [...rows]
      ..sort((a, b) => (a['created_at'] as String? ?? '')
          .compareTo(b['created_at'] as String? ?? ''));

    final buf = StringBuffer();
    buf.write('﻿'); // Excel에서 한글 깨짐 방지
    buf.writeln(_headers.map(_escape).join(','));

    for (final r in sorted) {
      final created = DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal();
      final a = FoodAnalysis.parse(r['result'] as String? ?? '');
      final meal = (r['meal'] as String?) ??
          (created != null ? mealForDate(created) : '');
      final fav = ((r['is_favorite'] as int?) ?? 0) == 1 ? 'Y' : '';

      final cols = <String>[
        created != null
            ? '${created.year}-${_p2(created.month)}-${_p2(created.day)}'
            : '',
        created != null ? '${_p2(created.hour)}:${_p2(created.minute)}' : '',
        meal,
        a.foodName ?? '',
        a.calories?.toString() ?? '',
        _num(a.carbs),
        _num(a.protein),
        _num(a.fat),
        _num(a.sodium),
        _num(a.fiber),
        _num(a.portion),
        fav,
      ];
      buf.writeln(cols.map(_escape).join(','));
    }
    return buf.toString();
  }

  /// CSV를 임시 디렉터리에 파일로 저장하고 경로를 반환.
  static Future<File> writeCsvToTemp(String csv, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    return file.writeAsString(csv);
  }

  /// 오늘 날짜 기반 기본 파일명 (bitelens_history_YYYYMMDD.csv)
  static String defaultFileName(DateTime now) =>
      'bitelens_history_${now.year}${_p2(now.month)}${_p2(now.day)}.csv';

  // ─── 헬퍼 ────────────────────────────────────────────────

  static String _p2(int n) => n.toString().padLeft(2, '0');

  static String _num(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  static String _escape(Object? value) {
    final s = value?.toString() ?? '';
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
