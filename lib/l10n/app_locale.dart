import 'package:flutter/material.dart';

/// Current app UI locale; changing the language rebuilds MaterialApp immediately.
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('ko'));

Locale localeForLanguage(String? languageCode) => switch (languageCode) {
      'en' => const Locale('en'),
      'ja' => const Locale('ja'),
      _ => const Locale('ko'),
    };

String languageCodeForName(String languageName) => switch (languageName) {
      'English' => 'en',
      '日本語' => 'ja',
      _ => 'ko',
    };

/// Translations for the settings flow. New screens can use the same helper as
/// they are localized in follow-up passes.
extension AppStrings on BuildContext {
  String tr(String korean) {
    final languageCode = Localizations.localeOf(this).languageCode;
    return (languageCode == 'en' ? _english : languageCode == 'ja' ? _japanese : _korean)[korean] ?? korean;
  }
}

const _english = <String, String>{
  '분석 설정': 'Analysis settings',
  '분석 기록 저장': 'Save analysis history',
  '분석 결과를 기기에 저장합니다': 'Save results on this device',
  '상세분석': 'Detailed analysis',
  '응답이 느려질 수 있습니다': 'Responses may take longer',
  '언어': 'Language',
  '앱 언어': 'App language',
  '응답 언어': 'Analysis response language',
  '데이터': 'Data',
  '데이터 내보내기 (CSV)': 'Export data (CSV)',
  '분석 기록을 CSV 파일로 공유': 'Share analysis history as a CSV file',
  '분석 기록 전체 삭제': 'Delete all analysis history',
  '앱 데이터 전체 삭제': 'Delete all app data',
  '프로필, 체중 기록, 분석 기록, 설정을 모두 삭제': 'Delete profile, weight and analysis history, and settings',
  '앱 정보': 'About',
  '개인정보 처리방침': 'Privacy policy',
  '링크를 준비 중이에요': 'Link is not available yet',
  '이용약관': 'Terms of service',
  '오픈소스 라이선스': 'Open-source licenses',
  '내보낼 기록이 없어요': 'There is no history to export',
  'BiteLens 분석 기록': 'BiteLens analysis history',
  '내보내기 중 오류가 발생했습니다.': 'An error occurred while exporting.',
  '기록 전체 삭제': 'Delete all history',
  '모든 분석 기록이 삭제됩니다.\n이 작업은 되돌릴 수 없어요.': 'All analysis history will be deleted.\nThis action cannot be undone.',
  '취소': 'Cancel',
  '삭제': 'Delete',
  '앱 데이터 전체 삭제': 'Delete all app data',
  '분석 사진과 기록, 체중 기록, 프로필, 앱 설정이 모두 삭제됩니다.\n이 작업은 되돌릴 수 없어요.': 'Analysis photos and history, weight history, profile, and app settings will be deleted.\nThis action cannot be undone.',
  '모든 앱 데이터를 삭제했어요.': 'All app data has been deleted.',
  '모두 삭제': 'Delete all',
  'Version': 'Version',
};

const _japanese = <String, String>{
  '분석 설정': '分析設定',
  '분석 기록 저장': '分析履歴を保存',
  '분석 결과를 기기에 저장합니다': '分析結果をこの端末に保存します',
  '상세분석': '詳細分析',
  '응답이 느려질 수 있습니다': '回答に時間がかかる場合があります',
  '언어': '言語',
  '앱 언어': 'アプリの言語',
  '응답 언어': '分析結果の言語',
  '데이터': 'データ',
  '데이터 내보내기 (CSV)': 'データをエクスポート (CSV)',
  '분석 기록을 CSV 파일로 공유': '分析履歴をCSVファイルで共有',
  '분석 기록 전체 삭제': '分析履歴をすべて削除',
  '앱 데이터 전체 삭제': 'アプリデータをすべて削除',
  '프로필, 체중 기록, 분석 기록, 설정을 모두 삭제': 'プロフィール、体重・分析履歴、設定をすべて削除',
  '앱 정보': 'アプリ情報',
  '개인정보 처리방침': 'プライバシーポリシー',
  '링크를 준비 중이에요': 'リンクを準備中です',
  '이용약관': '利用規約',
  '오픈소스 라이선스': 'オープンソースライセンス',
  '내보낼 기록이 없어요': 'エクスポートする履歴がありません',
  'BiteLens 분석 기록': 'BiteLens 分析履歴',
  '내보내기 중 오류가 발생했습니다.': 'エクスポート中にエラーが発生しました。',
  '기록 전체 삭제': '履歴をすべて削除',
  '모든 분석 기록이 삭제됩니다.\n이 작업은 되돌릴 수 없어요.': 'すべての分析履歴が削除されます。\nこの操作は取り消せません。',
  '취소': 'キャンセル',
  '삭제': '削除',
  '앱 데이터 전체 삭제': 'アプリデータをすべて削除',
  '분석 사진과 기록, 체중 기록, 프로필, 앱 설정이 모두 삭제됩니다.\n이 작업은 되돌릴 수 없어요.': '分析写真と履歴、体重履歴、プロフィール、アプリ設定がすべて削除されます。\nこの操作は取り消せません。',
  '모든 앱 데이터를 삭제했어요.': 'すべてのアプリデータを削除しました。',
  '모두 삭제': 'すべて削除',
  'Version': 'バージョン',
};
