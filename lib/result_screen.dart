import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;

  const ResultScreen({super.key, required this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  String _result = '';
  bool _isLoading = true;

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();

    // 스캔 애니메이션 설정
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true); // 위아래 반복

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _analyzeFood();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _analyzeFood() async {
    try {

      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: dotenv.env['GEMINI_API_KEY']!,
      );

      final imageBytes = await File(widget.imagePath).readAsBytes();
      final prompt = [
        Content.multi([
          DataPart('image/jpeg', imageBytes),
          TextPart('''
            이 음식 사진을 분석해줘. 다음 형식으로 답해줘:
            
            음식 이름: 
            예상 칼로리: 
            주요 영양소:
            - 탄수화물:
            - 단백질:
            - 지방:
          '''),
        ])
      ];

      final response = await model.generateContent(prompt);

      setState(() {
        _result = response.text ?? '분석 실패';
        _isLoading = false;
      });

      // 분석 완료되면 스캔 애니메이션 정지
      _scanController.stop();

    } catch (e) {
      print('오류 발생: $e');
      setState(() {
        _result = '오류 발생: $e';
        _isLoading = false;
      });
      _scanController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('분석 결과'),
          backgroundColor: Colors.deepOrange,
        ),
        body: Column(
          children: [
            // 찍은 사진 + 스캔 애니메이션
            SizedBox(
              height: 300,
              width: double.infinity,
              child: Stack(
                children: [
                  // 사진
                  Image.file(
                    File(widget.imagePath),
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  // 어두운 오버레이
                  Container(
                    height: 300,
                    color: Colors.black.withOpacity(0.3),
                  ),
                  // 스캔 라인 (로딩 중일 때만)
                  if (_isLoading)
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _scanAnimation.value * 280,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              // 스캔 라인
                              Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.deepOrange.withOpacity(0.8),
                                      Colors.orange,
                                      Colors.deepOrange.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.6),
                                      blurRadius: 8,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                              // 라인 아래 글로우 효과
                              Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.orange.withOpacity(0.15),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  // 코너 마커 (스캔 프레임 느낌)
                  if (_isLoading)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Stack(
                          children: [
                            // 좌상단
                            Positioned(
                              top: 0, left: 0,
                              child: _cornerWidget(),
                            ),
                            // 우상단
                            Positioned(
                              top: 0, right: 0,
                              child: Transform.rotate(
                                angle: 1.5708,
                                child: _cornerWidget(),
                              ),
                            ),
                            // 좌하단
                            Positioned(
                              bottom: 0, left: 0,
                              child: Transform.rotate(
                                angle: -1.5708,
                                child: _cornerWidget(),
                              ),
                            ),
                            // 우하단
                            Positioned(
                              bottom: 0, right: 0,
                              child: Transform.rotate(
                                angle: 3.1416,
                                child: _cornerWidget(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 분석 결과
            Expanded(
              child: _isLoading
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.deepOrange),
                    SizedBox(height: 16),
                    Text('AI가 음식을 분석 중이에요...'),
                  ],
                ),
              )
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _result,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),
              ),
            ),

            // 다시 찍기 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '다시 찍기',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 코너 마커 위젯
  Widget _cornerWidget() {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _CornerPainter(),
      ),
    );
  }
}

// 코너 L자 그리는 커스텀 페인터
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // L자 모양
    canvas.drawLine(const Offset(0, 20), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(20, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}