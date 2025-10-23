import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../utils/circular_reveal_transition.dart'; // 匯入自訂轉場工具
import 'transition_page.dart'; // 匯入中介轉場頁面

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToNextPage() {
    // 在動畫播放完畢後，稍微延遲一小段時間
    // 這給了 UI 執行緒足夠的空檔去準備並流暢地播放轉場動畫
    Future.delayed(const Duration(milliseconds: 50), () {
      // 檢查頁面是否還在畫面上，這是一個好的習慣，可以避免不必要的錯誤
      if (!mounted) return;

      // 取得螢幕中心點，讓「圓形展開」動畫從中心開始
      final screenCenter = Offset(
        MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height / 2,
      );

      // 使用我們自訂的轉場動畫，導航到極度輕量的 TransitionPage
      // 這樣可以確保轉場動畫本身不會被卡住
      Navigator.of(context).pushReplacement(
        CircularRevealTransitionRoute(
          page: const TransitionPage(),
          centerOffset: screenCenter,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/anim/splash_animation.json', // 請再次確認你的動畫檔案名稱
          controller: _controller,
          onLoaded: (composition) {
            _controller
              ..duration = composition.duration
              ..forward().whenComplete(_navigateToNextPage); // 動畫播完後，呼叫導航函式
          },
        ),
      ),
    );
  }
}

