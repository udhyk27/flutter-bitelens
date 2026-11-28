import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bitelens/models/food_analysis.dart';
import 'package:bitelens/services/database_service.dart';
import 'package:bitelens/widgets/analysis_edit_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitelens/l10n/app_locale.dart';
import 'package:bitelens/widgets/history_components.dart';

enum _DateFilter {
  all('전체'),
  today('오늘'),
  week('7일'),
  month('30일');

  const _DateFilter(this.label);
  final String label;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const int _pageSize = 20;

  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _weeklyData = [];
  // 날짜('yyyy-MM-dd')별 칼로리 합계 — 페이지네이션과 무관한 그날 전체 합
  Map<String, int> _dailyTotals = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _showFavoritesOnly = false;
  // 새 필터/검색이 시작되면 이전 DB 요청 결과는 화면에 적용하지 않는다.
  int _loadGeneration = 0;
  double? _tdee;
  late ScrollController _scrollController;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  _DateFilter _dateFilter = _DateFilter.all;
  Timer? _debounce;

  bool get _isFiltering =>
      _searchQuery.isNotEmpty || _dateFilter != _DateFilter.all;

  DateTime? get _since {
    final now = DateTime.now();
    switch (_dateFilter) {
      case _DateFilter.today:
        return DateTime(now.year, now.month, now.day);
      case _DateFilter.week:
        return now.subtract(const Duration(days: 7));
      case _DateFilter.month:
        return now.subtract(const Duration(days: 30));
      case _DateFilter.all:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || value == _searchQuery) return;
      setState(() => _searchQuery = value);
      _loadInitial();
    });
  }

  void _setDateFilter(_DateFilter f) {
    if (f == _dateFilter) return;
    setState(() => _dateFilter = f);
    _loadInitial();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final tdee = prefs.getDouble('tdee');
      final data = await DatabaseHelper.instance.getAnalysisHistoryPaged(
        limit: _pageSize,
        offset: 0,
        favoritesOnly: _showFavoritesOnly,
        query: _searchQuery,
        since: _since,
      );
      final weekly = await DatabaseHelper.instance.getWeeklyHistory();
      final dailyTotals = await DatabaseHelper.instance.getDailyCalorieTotals(
        favoritesOnly: _showFavoritesOnly,
        query: _searchQuery,
        since: _since,
      );

      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _tdee = tdee;
        _history = List<Map<String, dynamic>>.from(
          data.map((e) => Map<String, dynamic>.from(e)),
        );
        _weeklyData = weekly;
        _dailyTotals = dailyTotals;
        _isLoading = false;
        _hasMore = data.length == _pageSize;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      debugPrint('기록 불러오기 오류: $e');
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final generation = _loadGeneration;
    setState(() => _isLoadingMore = true);

    try {
      final data = await DatabaseHelper.instance.getAnalysisHistoryPaged(
        limit: _pageSize,
        offset: _history.length,
        favoritesOnly: _showFavoritesOnly,
        query: _searchQuery,
        since: _since,
      );

      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _history.addAll(data.map((e) => Map<String, dynamic>.from(e)));
        _hasMore = data.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      debugPrint('기록 추가 불러오기 오류: $e');
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
    }
  }

  Future<void> _deleteItem(int id) async {
    await DatabaseHelper.instance.deleteAnalysis(id);
    if (!mounted) return;
    // OFFSET 페이지네이션에서는 중간 행을 제거한 뒤 기존 목록을 유지하면
    // 다음 페이지 로드 시 중복/누락이 생길 수 있다. 필터 상태 그대로 재조회한다.
    await _loadInitial();
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final id = item['id'] as int;
    final result = item['result'] as String;
    final createdAt = item['created_at'] as String;
    final analysis = FoodAnalysis.parse(result);
    final meal =
        (item['meal'] as String?) ?? NutritionParser.mealType(createdAt);

    final res = await showAnalysisEditSheet(
      context,
      analysis: analysis,
      meal: meal,
    );
    if (res == null || !mounted) return;

    final newResult = res.analysis.toJsonString();
    await DatabaseHelper.instance.updateAnalysis(
      id,
      result: newResult,
      meal: res.meal,
    );

    if (!mounted) return;
    final idx = _history.indexWhere((e) => e['id'] == id);
    if (idx != -1) {
      final updated = Map<String, dynamic>.from(_history[idx]);
      updated['result'] = newResult;
      updated['meal'] = res.meal;
      setState(() => _history[idx] = updated);
    }
    final weekly = await DatabaseHelper.instance.getWeeklyHistory();
    final dailyTotals = await DatabaseHelper.instance.getDailyCalorieTotals(
      favoritesOnly: _showFavoritesOnly,
      query: _searchQuery,
      since: _since,
    );
    if (mounted) {
      setState(() {
        _weeklyData = weekly;
        _dailyTotals = dailyTotals;
      });
    }
  }

  Future<void> _toggleFavorite(int id, bool current) async {
    await DatabaseHelper.instance.toggleFavorite(id, !current);
    if (!mounted) return;
    // 즐겨찾기 필터·일일 합계·페이지 offset을 한 번에 일관되게 갱신한다.
    await _loadInitial();
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in _history) {
      final dt = DateTime.parse(item['created_at'] as String).toLocal();
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
    if (diff == 0) return context.tr('오늘');
    if (diff == 1) return context.tr('어제');
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  String _timeLabel(String isoDate) {
    final dt = DateTime.parse(isoDate).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate();
    final dateKeys = grouped.keys.toList();
    final showChart = _weeklyData.isNotEmpty && !_isFiltering;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('HISTORY'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
          ),
        ),
        centerTitle: true,
        actions: [
          // 즐겨찾기 필터 토글
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.star : Icons.star_outline,
              color: _showFavoritesOnly ? Colors.amber : Colors.white38,
              size: 22,
            ),
            onPressed: () async {
              setState(() => _showFavoritesOnly = !_showFavoritesOnly);
              await _loadInitial();
            },
          ),
          if (_history.isNotEmpty && !_showFavoritesOnly)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${context.tr('Total')} ${_history.length}${_hasMore ? '+' : ''}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 1,
                    ),
                  )
                : RefreshIndicator(
                    color: Colors.deepOrange,
                    backgroundColor: const Color(0xFF1A1A1A),
                    onRefresh: _loadInitial,
                    child: _history.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                            itemCount:
                                dateKeys.length +
                                (showChart ? 1 : 0) +
                                (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              // 주간 차트 (맨 위)
                              if (i == 0 && showChart) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: HistoryWeeklyChart(
                                    weeklyHistory: _weeklyData,
                                    tdee: _tdee,
                                  ),
                                );
                              }
                              final adjustedIndex = showChart ? i - 1 : i;

                              // 로딩 인디케이터 (맨 아래)
                              if (adjustedIndex == dateKeys.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white24,
                                      strokeWidth: 1.5,
                                    ),
                                  ),
                                );
                              }

                              final dateKey = dateKeys[adjustedIndex];
                              final items = grouped[dateKey]!;
                              // 그날 전체 합(DB 집계). 집계에 없는 경우(레거시 등)만
                              // 로드된 항목 합산으로 폴백.
                              final rawDate =
                                  items.first['created_at'] as String;
                              final dayKey = rawDate.length >= 10
                                  ? rawDate.substring(0, 10)
                                  : rawDate;
                              final totalCal =
                                  _dailyTotals[dayKey] ??
                                  items.fold<int>(0, (sum, item) {
                                    return sum +
                                        (NutritionParser.parseCaloriesInt(
                                              item['result'] as String,
                                            ) ??
                                            0);
                                  });

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      16,
                                      4,
                                      10,
                                    ),
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
                                        Container(
                                          height: 0.5,
                                          width: 20,
                                          color: Colors.white12,
                                        ),
                                        const Spacer(),
                                        if (totalCal > 0)
                                          Text(
                                            '${context.tr('Total')} $totalCal kcal',
                                            style: const TextStyle(
                                              color: Colors.deepOrange,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  ...items.map(
                                    (item) => HistoryCard(
                                      id: item['id'] as int,
                                      imagePath: item['image_path'] as String,
                                      result: item['result'] as String,
                                      time: _timeLabel(
                                        item['created_at'] as String,
                                      ),
                                      createdAt: item['created_at'] as String,
                                      meal: item['meal'] as String?,
                                      isFavorite:
                                          (item['is_favorite'] as int? ?? 0) ==
                                          1,
                                      onDelete: () =>
                                          _showDeleteDialog(item['id'] as int),
                                      onEdit: () => _editItem(item),
                                      onFavoriteToggle: () => _toggleFavorite(
                                        item['id'] as int,
                                        (item['is_favorite'] as int? ?? 0) == 1,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        children: [
          // 검색창
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, color: Colors.white38, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: Colors.deepOrange,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: context.tr('음식 이름 검색'),
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _debounce?.cancel();
                      setState(() => _searchQuery = '');
                      _loadInitial();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.close, color: Colors.white38, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 날짜 필터 칩
          Row(
            children: _DateFilter.values.map((f) {
              final sel = f == _dateFilter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _setDateFilter(f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? Colors.deepOrange
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? Colors.deepOrange
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      context.tr(f.label),
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isFiltering
                ? Icons.search_off
                : (_showFavoritesOnly ? Icons.star_outline : Icons.history),
            size: 56,
            color: Colors.white12,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(
              _isFiltering
                  ? '조건에 맞는 기록이 없어요'
                  : (_showFavoritesOnly ? '즐겨찾기한 기록이 없어요' : '분석 기록이 없어요'),
            ),
            style: const TextStyle(
              color: Colors.white30,
              fontSize: 15,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              _isFiltering
                  ? '검색어나 기간을 바꿔보세요'
                  : (_showFavoritesOnly
                        ? '별표를 눌러 기록을 저장해보세요'
                        : '음식을 촬영해서 분석해보세요'),
            ),
            style: const TextStyle(color: Colors.white12, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('기록 삭제'),
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          context.tr('이 기록을 삭제할까요?'),
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.tr('취소'),
              style: const TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(id);
            },
            child: Text(
              context.tr('삭제'),
              style: const TextStyle(color: Colors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }
}
