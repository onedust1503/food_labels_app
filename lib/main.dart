import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'login.dart';
import 'pages/home/trainee_home_page.dart';
import 'pages/home/coach_home_page.dart';
import 'services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/splash_screen.dart';
import 'package:provider/provider.dart';
import 'providers/network_provider.dart';
import 'components/network_banner.dart';
// ✅ 新增：導入分角色的設定頁面
import 'pages/profile/trainee_setup_page.dart';
import 'pages/profile/coach_setup_page.dart';

import 'tools/food_data_importer.dart';

import 'theme/app_theme.dart';

import 'pages/nutrition/ocr_test_page.dart';

import 'utils/init_exercises_collection.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

// 全域導航鍵
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // 初始化國際化日期格式
  await initializeDateFormatting('zh_TW', null);
  
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


    if (kDebugMode) {
      debugPrint('[init] Firebase initialized successfully');
    }



    // 初始化通知服務
    await NotificationService().initialize();
    if (kDebugMode) {
      debugPrint('[init] Notification Service initialized successfully');
    }

    // 初始化網路監控
    final networkProvider = NetworkProvider();
    await networkProvider.initialize();
    if (kDebugMode) {
      debugPrint('[init] Network Provider initialized successfully');
    }

  } catch (e) {
    if (kDebugMode) {
      debugPrint('[init] Firebase initialization failed: $e');
    }
  }

  //導入食物資料（在開發模式下執行)
  /*
  if (kDebugMode) {
    debugPrint('[init] ========================================');
    debugPrint('[init] 🗑️ 清除舊資料...');
    try {
      await FoodDataImporter().clearSystemFoods();
      debugPrint('[init] ✅ 舊資料清除完成!');
    } catch (e) {
      debugPrint('[init] ❌ 清除失敗: $e');
    }
    
    debugPrint('[init] ========================================');
    debugPrint('[init] 🚀 開始導入新資料...');
    try {
      await FoodDataImporter().importFoodData();
      debugPrint('[init] ✅ 新資料導入完成!');
    } catch (e) {
      debugPrint('[init] ❌ 導入失敗: $e');
    }
    debugPrint('[init] ========================================');
  }
  */

  //  初始化動作庫
  await ExercisesInitializer.initializeIfNeeded();
  
  if (kDebugMode) {
    debugPrint('[init] done');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NetworkProvider>.value(
      value: NetworkProvider(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Flutter Demo',
        theme: AppTheme.lightTheme,
        home: SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/studentHome': (context) => const TraineeHomePage(),
          '/coachHome': (context) => const CoachHomePage(),
          '/home': (context) => const AuthWrapper(), // ✅ 加入 /home 路由
        },
        onGenerateRoute: (settings) {
          if (kDebugMode) {
            debugPrint('嘗試導航到: ${settings.name}');
          }
          
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(builder: (context) => const AuthWrapper());
            case '/login':
              return MaterialPageRoute(builder: (context) => const LoginScreen());
            case '/home':
              return MaterialPageRoute(builder: (context) => const AuthWrapper()); // ✅ /home 導向 AuthWrapper
            case '/studentHome':
              return MaterialPageRoute(builder: (context) => const TraineeHomePage());
            case '/coachHome':
              return MaterialPageRoute(builder: (context) => const CoachHomePage());
            default:
              if (kDebugMode) {
                debugPrint('未知路由: ${settings.name}，返回 AuthWrapper');
              }
              return MaterialPageRoute(builder: (context) => const AuthWrapper());
          }
        },
      ),
    );
  }
}

// ✅ 修改：支援分角色的 AuthWrapper
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // 從 Firestore 獲取用戶資料
  Future<Map<String, dynamic>> _getUserData(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('獲取用戶資料失敗: $e');
      }
      return {};
    }
  }

  // 根據角色返回對應頁面
  Widget _getHomePageByRole(String role) {
    Widget homePage;
    
    switch (role) {
      case 'coach':
        homePage = const CoachHomePage();
        break;
      case 'trainee':
        homePage = const TraineeHomePage();
        break;
      default:
        return const LoginScreen();
    }
    
    // 為首頁加上網路狀態橫幅
    return NetworkBanner(
      child: homePage,
    );
  }

  // ✅ 新增：根據角色返回對應的設定頁面
  Widget _getSetupPageByRole(String role) {
    if (kDebugMode) {
      debugPrint('[AuthWrapper] 導向設定頁面，角色: $role');
    }

    switch (role) {
      case 'coach':
        return const CoachSetupPage();
      case 'trainee':
        return const TraineeSetupPage();
      default:
        if (kDebugMode) {
          debugPrint('[AuthWrapper] 未知角色: $role，返回登入頁面');
        }
        return const LoginScreen();
    }
  }

  // ✅ 新增：檢查是否需要完成設定（根據角色檢查不同欄位）
  bool _needsProfileSetup(Map<String, dynamic> userData, String role) {
    // 1. 檢查 profileSetupCompleted 欄位
    final profileSetupCompleted = userData['profileSetupCompleted'] ?? false;
    
    if (kDebugMode) {
      debugPrint('[AuthWrapper] profileSetupCompleted: $profileSetupCompleted');
    }
    
    // 如果明確標記為未完成
    if (!profileSetupCompleted) {
      return true;
    }

    // 2. 檢查必要欄位是否存在（防止資料不完整）
    final hasDisplayName = userData['displayName'] != null && 
                          (userData['displayName'] as String).isNotEmpty;

    if (kDebugMode) {
      debugPrint('[AuthWrapper] hasDisplayName: $hasDisplayName');
    }

    // 根據角色檢查不同的必要欄位
    if (role == 'trainee') {
      // 學生必須有：姓名、身高、體重、目標
      final hasHeight = userData['height'] != null;
      final hasWeight = userData['weight'] != null;
      final hasGoal = userData['goal'] != null;

      if (kDebugMode) {
        debugPrint('[AuthWrapper] 學生欄位檢查:');
        debugPrint('  - height: $hasHeight');
        debugPrint('  - weight: $hasWeight');
        debugPrint('  - goal: $hasGoal');
      }

      return !hasDisplayName || !hasHeight || !hasWeight || !hasGoal;
      
    } else if (role == 'coach') {
      // 教練必須有：姓名、專長
      final hasSpecialties = userData['specialties'] != null && 
                            (userData['specialties'] as List).isNotEmpty;

      if (kDebugMode) {
        debugPrint('[AuthWrapper] 教練欄位檢查:');
        debugPrint('  - specialties: $hasSpecialties');
      }

      return !hasDisplayName || !hasSpecialties;
    }
 
    // 未知角色，需要設定
    return true;
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
        
        // 用戶未登入
        if (!snapshot.hasData || snapshot.data == null || snapshot.hasError) {
          if (kDebugMode) {
            debugPrint('[AuthWrapper] 用戶未登入或已登出');
          }
          return const LoginScreen();
        }

        // 用戶已登入 - 獲取用戶資料
        if (kDebugMode) {
          debugPrint('[AuthWrapper] 用戶已登入: ${snapshot.data!.email}');
        }
        
        return FutureBuilder<Map<String, dynamic>>(
          future: _getUserData(snapshot.data!.uid),
          builder: (context, userSnapshot) {
            if (kDebugMode) {
              debugPrint('[AuthWrapper] 資料獲取狀態: ${userSnapshot.connectionState}');
            }
            
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }
            
            if (userSnapshot.hasData && userSnapshot.data!.isNotEmpty) {
              final userData = userSnapshot.data!;
              final role = userData['role'] ?? '';
              
              if (kDebugMode) {
                debugPrint('[AuthWrapper] 角色: $role');
                debugPrint('[AuthWrapper] 用戶資料: $userData');
              }
              
              // ✅ 使用新的檢查邏輯
              final needsSetup = _needsProfileSetup(userData, role);
              
              if (kDebugMode) {
                debugPrint('[AuthWrapper] 需要設定: $needsSetup');
              }
              
              // ✅ 如果需要設定，根據角色導向對應設定頁面
              if (needsSetup) {
                return _getSetupPageByRole(role);
              }
              
              // 已完成設定，根據角色導向主頁
              if (role == 'coach' || role == 'trainee') {
                if (kDebugMode) {
                  debugPrint('[AuthWrapper] 導向角色頁面: $role');
                }
                
                // 添加短暫延遲確保狀態正確更新
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
                // 沒有有效角色，回到登入頁面
                if (kDebugMode) {
                  debugPrint('[AuthWrapper] 沒有有效角色，回到登入頁面');
                }
                return const LoginScreen();
              }
            } else {
              // 沒有用戶資料，返回登入頁面
              if (kDebugMode) {
                debugPrint('[AuthWrapper] 沒有用戶資料，返回登入頁面');
              }
              return const LoginScreen();
            }
          },
        );
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