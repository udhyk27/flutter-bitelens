import 'package:bitelens/screens/home_screen.dart';
import 'package:bitelens/screens/onboarding_screen.dart';
import 'package:bitelens/services/api_service.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/svg_constant.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await Firebase.initializeApp();
  _cameras = await availableCameras();
  Api().getRemoteConfig();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiteLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      home: const AnimatedSplash(),
    );
  }
}

class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({super.key});

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash> {
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await Future.delayed(const Duration(milliseconds: 2500));

      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => onboardingDone
              ? HomeScreen(cameras: _cameras)
              : OnboardingScreen(cameras: _cameras),
        ),
      );
    } catch (e, stack) {
      debugPrint("초기화 에러: $e");
      debugPrint("스택: $stack");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String htmlContent = """
    <!DOCTYPE html>
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          body, html {
            margin: 0; padding: 0;
            width: 100%; height: 100%;
            display: flex; justify-content: center; align-items: center;
            overflow: hidden; background-color: black;
          }
          svg {
            width: 80vw;
            height: 80vh;
            object-fit: contain;
          }
        </style>
      </head>
      <body>
        ${SvgConstant.svgLogo}
      </body>
    </html>
    """;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: InAppWebView(
          initialData: InAppWebViewInitialData(
            data: htmlContent,
            mimeType: "text/html",
            encoding: "utf-8",
          ),
          initialSettings: InAppWebViewSettings(
            transparentBackground: true,
            supportZoom: false,
          ),
        ),
      ),
    );
  }
}