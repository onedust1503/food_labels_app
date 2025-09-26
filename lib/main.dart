import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // *** 新增：用於 kDebugMode ***
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'login.dart';
import 'pages/home/trainee_home_page.dart';
import 'pages/home/coach_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // *** 修復：使用 debugPrint 替代 print ***
  if (kDebugMode) {
    debugPrint('[init] start');
  }

  // 導覽列樣式設定
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  try {
    // 初始化 Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // *** 修復：使用 debugPrint 替代 print ***
    if (kDebugMode) {
      debugPrint('[init] Firebase initialized successfully');
    }
  } catch (e) {
    // *** 修復：使用 debugPrint 替代 print ***
    if (kDebugMode) {
      debugPrint('[init] Firebase initialization failed: $e');
    }
  }
  
  // *** 修復：使用 debugPrint 替代 print ***
  if (kDebugMode) {
    debugPrint('[init] done');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/studentHome': (context) => const TraineeHomePage(), // 確保路由名稱一致
        '/coachHome': (context) => const CoachHomePage(),
      },
      // *** 新增：路由生成器處理未定義的路由 ***
      onGenerateRoute: (settings) {
        if (kDebugMode) {
          debugPrint('嘗試導航到: ${settings.name}');
        }
        
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (context) => const AuthWrapper());
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginScreen());
          case '/studentHome':
            return MaterialPageRoute(builder: (context) => const TraineeHomePage());
          case '/coachHome':
            return MaterialPageRoute(builder: (context) => const CoachHomePage());
          default:
            // 未知路由，返回 AuthWrapper 重新檢查狀態
            if (kDebugMode) {
              debugPrint('未知路由: ${settings.name}，返回 AuthWrapper');
            }
            return MaterialPageRoute(builder: (context) => const AuthWrapper());
        }
      },
    );
  }
}

// *** 修復：改進認證包裝器，確保正確處理登出狀態 ***
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // 從 Firestore 獲取用戶角色
  Future<String> _getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String role = userData['role'] ?? '';
        
        if (role == 'coach' || role == 'trainee') {
          return role;
        }
      }
      return '';
    } catch (e) {
      // *** 修復：使用 debugPrint 替代 print ***
      if (kDebugMode) {
        debugPrint('獲取用戶角色失敗: $e');
      }
      return '';
    }
  }

  // 根據角色返回對應頁面
  Widget _getHomePageByRole(String role) {
    switch (role) {
      case 'coach':
        return const CoachHomePage();
      case 'trainee':
        return const TraineeHomePage();
      default:
        return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (kDebugMode) {
          debugPrint('[AuthWrapper] ConnectionState: ${snapshot.connectionState}');
          debugPrint('[AuthWrapper] HasData: ${snapshot.hasData}');
          debugPrint('[AuthWrapper] User: ${snapshot.data?.email}');
        }
        
        // 載入中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        
        // *** 修改：更嚴格的登出狀態檢查 ***
        if (snapshot.hasData && snapshot.data != null && !snapshot.hasError) {
          if (kDebugMode) {
            debugPrint('[AuthWrapper] 用戶已登入: ${snapshot.data!.email}');
          }
          
          // 用戶已登入，獲取角色資訊
          return FutureBuilder<String>(
            future: _getUserRole(snapshot.data!.uid),
            builder: (context, roleSnapshot) {
              if (kDebugMode) {
                debugPrint('[AuthWrapper] 角色獲取狀態: ${roleSnapshot.connectionState}');
                debugPrint('[AuthWrapper] 角色資料: ${roleSnapshot.data}');
              }
              
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }
              
              if (roleSnapshot.hasData && roleSnapshot.data!.isNotEmpty) {
                // 有角色資料，導向對應頁面
                String role = roleSnapshot.data!;
                if (kDebugMode) {
                  debugPrint('[AuthWrapper] 導向角色頁面: $role');
                }
                
                // *** 修復：添加一個短暫延遲確保狀態正確更新 ***
                return FutureBuilder(
                  future: Future.delayed(const Duration(milliseconds: 100)),
                  builder: (context, delaySnapshot) {
                    if (delaySnapshot.connectionState == ConnectionState.done) {
                      return _getHomePageByRole(role);
                    }
                    return const LoadingScreen();
                  },
                );
              } else {
                // 沒有角色資料，回到登入頁面重新設定
                if (kDebugMode) {
                  debugPrint('[AuthWrapper] 沒有角色資料，回到登入頁面');
                }
                return const LoginScreen();
              }
            },
          );
        } else {
          // *** 修改：用戶未登入或登出 ***
          if (kDebugMode) {
            debugPrint('[AuthWrapper] 用戶未登入或已登出');
          }
          return const LoginScreen();
        }
      },
    );
  }
}

// 載入畫面組件
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFE8F4FD),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF173C56)),
            ),
            SizedBox(height: 20),
            Text(
              '載入中...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF173C56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 保留原本的 MyHomePage
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}