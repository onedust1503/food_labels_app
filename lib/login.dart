import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // *** 新增：用於 kDebugMode ***
import 'package:flutter/services.dart'; //觸覺回饋
import 'package:firebase_auth/firebase_auth.dart'; // Firebase 認證
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 資料庫
import 'register.dart';

// 使用 StatefulWidget，管理輸入框的狀態
class LoginScreen extends StatefulWidget {
    const LoginScreen({super.key});

    @override
    State<LoginScreen> createState() => _LoginScreenState();
}                                                                                                                                                                                                                                                                                                                                                                                                         

class _LoginScreenState extends State<LoginScreen> 
    with TickerProviderStateMixin {  // 混入 TickerProviderStateMixin 以支援動畫
    
    // Firebase 實例
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    
    // 創建控制器管理輸入框內容
    final TextEditingController emailController = TextEditingController();                              
    final TextEditingController passwordController = TextEditingController();

    // 動畫控制器
    late AnimationController _buttonAnimationController;
    late AnimationController _shakeAnimationController;
    late Animation<double> _buttonScaleAnimation;
    late Animation<double> _shakeAnimation;

    // 控制密碼是否顯示
    bool isPasswordVisible = false;
    // 新增載入狀態
    bool isLoading = false;

    // 即時驗證狀態
    bool emailIsValid = false;     // Email 是否有效
    bool passwordIsValid = false;   // 密碼是否有效
    bool emailTouched = false;      // Email 輸入框是否被觸碰過
    bool passwordTouched = false;   // 密碼輸入框是否被觸碰過

    // 新增錯誤訊息
    String emailError = '';
    String passwordError = '';

    // 模擬網路狀態（之後換成 connectivity_plus）
    bool isConnected = true;

    // *** 移除身分選擇相關變數 ***
    // int selectedRoleIndex = 0;
    // final List<String> roleOptions = ['學員', '教練'];
    // String get selectedRole => roleOptions[selectedRoleIndex];

    @override
    void initState() {
        super.initState();
        //  初始化動畫控制器
        _initializeAnimations();
        
        //  監聽輸入框變化，進行即時驗證
        emailController.addListener(_onEmailChanged);
        passwordController.addListener(_onPasswordChanged);
        
        // *** 修改：移除自動檢查當前用戶（由 AuthWrapper 處理） ***
        // 不再需要檢查當前用戶，因為 AuthWrapper 會處理
    }

    // 從 Firestore 獲取用戶角色 - 改進版本，有更好的錯誤處理
    Future<String> _getUserRole(String uid) async {
        try {
            DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
            if (userDoc.exists) {
                Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
                String role = userData['role'] ?? '';
                
                // 確保角色值是有效的
                if (role == 'coach' || role == 'trainee') {
                    return role;
                } else {
                    print('無效的角色值: $role');
                    return '';
                }
            } else {
                print('用戶文檔不存在');
                return '';
            }
        } catch (e) {
            print('獲取用戶角色失敗: $e');
            return '';
        }
    }

    // *** 修改：移除導航方法，由 AuthWrapper 統一處理 ***
    // 不再需要手動導航方法，AuthWrapper 會自動根據用戶狀態導航到正確頁面

    // *** 移除：創建用戶資料方法，登入頁面不需要創建新用戶 ***
    // 登入頁面只負責驗證現有用戶，新用戶創建由註冊頁面處理

    // *** 移除：將 UI 選擇轉換為資料庫角色值的方法 ***
    // String _convertSelectedRoleToDbRole() {
    //     return selectedRole == '教練' ? 'coach' : 'trainee';
    // }

    //  初始化所有動畫效果
    void _initializeAnimations() {
        // 按鈕動畫控制器：控制按鈕的縮放效果
        _buttonAnimationController = AnimationController(
            duration: const Duration(milliseconds: 150), // 動畫持續時間
            vsync: this, // 提供動畫同步
        );
        
        // 震動動畫控制器：控制錯誤時的震動效果
        _shakeAnimationController = AnimationController(
            duration: const Duration(milliseconds: 500),
            vsync: this,
        );

        // 按鈕縮放動畫：定義按鈕被點擊時的縮放範圍
        _buttonScaleAnimation = Tween<double>(
            begin: 1.0,  // 原始大小
            end: 0.95,   // 縮小到 95%
        ).animate(CurvedAnimation(
            parent: _buttonAnimationController,
            curve: Curves.easeInOut, // 緩動曲線，讓動畫更自然
        ));

        // 震動動畫：定義錯誤時的左右震動效果
        _shakeAnimation = Tween<double>(
            begin: -10.0, // 向左偏移
            end: 10.0,    // 向右偏移
        ).animate(CurvedAnimation(
            parent: _shakeAnimationController,
            curve: Curves.elasticIn, // 彈性曲線，產生震動效果
        ));
    }

    // *** 移除身分切換相關方法 ***
    // void _onRoleChanged(int newIndex) { ... }
    // Widget _buildRoleSelector() { ... }

    //  Email 輸入變化監聽器 - 每次用戶輸入都會觸發
    void _onEmailChanged() {
        setState(() {
            emailTouched = true; // 標記為已觸碰
            String email = emailController.text.trim();
            
            // 即時驗證 Email 格式
            if (email.isEmpty) {
                emailIsValid = false;
                emailError = '';
            } else if (!isValidEmail(email)) {
                emailIsValid = false;
                emailError = '請輸入有效的Email格式';
            } else {
                emailIsValid = true;
                emailError = '';
            }
        });
    }

    //  密碼輸入變化監聽器
    void _onPasswordChanged() {
        setState(() {
            passwordTouched = true; // 標記為已觸碰
            String password = passwordController.text;
            
            // 即時驗證密碼強度
            if (password.isEmpty) {
                passwordIsValid = false;
                passwordError = '';
            } else if (!isValidPassword(password)) {
                passwordIsValid = false;
                passwordError = '密碼長度至少為6位';
            } else {
                passwordIsValid = true;
                passwordError = '';
            }
        });
    }

    //  Email 驗證函數 - 檢查 Email 格式是否正確
    bool isValidEmail(String email) {
         return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
    }

    //  密碼驗證函數 - 檢查密碼是否符合要求
    bool isValidPassword(String password) {
        return password.length >= 6;
    }

    //  密碼強度計算 - 返回 0-4 的強度等級
    int getPasswordStrength(String password) {
        int strength = 0;
        if (password.length >= 6) strength++; // 長度夠
        if (password.contains(RegExp(r'[A-Z]'))) strength++; // 包含大寫
        if (password.contains(RegExp(r'[a-z]'))) strength++; // 包含小寫
        if (password.contains(RegExp(r'[0-9]'))) strength++; // 包含數字
        if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++; // 包含特殊字符
        return strength > 4 ? 4 : strength;
    }

    //  密碼強度顏色 - 根據強度返回對應顏色
    Color getPasswordStrengthColor(int strength) {
        switch (strength) {
            case 0: return Colors.grey;
            case 1: return Colors.red;
            case 2: return Colors.orange;
            case 3: return Colors.yellow;
            case 4: return Colors.green;
            default: return Colors.grey;
        }
    }

    //  建立密碼強度指示器
    Widget _buildPasswordStrengthIndicator() {
        if (!passwordTouched || passwordController.text.isEmpty) {
            return const SizedBox.shrink(); // 如果沒輸入就不顯示
        }

        int strength = getPasswordStrength(passwordController.text);
        Color strengthColor = getPasswordStrengthColor(strength);
        
        List<String> strengthTexts = ['', '弱', '普通', '強', '很強'];
        
        return Container(
            margin: const EdgeInsets.only(top: 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // 強度條
                    Row(
                        children: List.generate(4, (index) {
                            return Expanded(
                                child: Container(
                                    height: 4,
                                    margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                                    decoration: BoxDecoration(
                                        color: index < strength ? strengthColor : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(2),
                                    ),
                                ),
                            );
                        }),
                    ),
                    const SizedBox(height: 4),
                    // 強度文字
                    Text(
                        strength > 0 ? '密碼強度：${strengthTexts[strength]}' : '',
                        style: TextStyle(
                            fontSize: 12,
                            color: strengthColor,
                            fontWeight: FontWeight.w500,
                        ),
                    ),
                ],
            ),
        );
    }

    //  震動回饋 - 提供觸覺反饋
    void _triggerHapticFeedback() {
        HapticFeedback.mediumImpact(); // 中等強度震動
    }

    //  播放錯誤震動動畫
    void _playErrorShakeAnimation() {
        _triggerHapticFeedback(); // 震動手機
        _shakeAnimationController.forward().then((_) {
            _shakeAnimationController.reverse(); // 震動後復原
        });
    }

    //  按鈕按下動畫 - 模擬按鈕被按下的效果
    void _playButtonPressAnimation() {
        _buttonAnimationController.forward().then((_) {
            _buttonAnimationController.reverse(); // 按下後彈回
        });
    }

    //  表單驗證 - 檢查所有輸入是否有效
    bool validateForm() {
        setState(() {
            emailTouched = true;
            passwordTouched = true;
            
            String email = emailController.text.trim();
            String password = passwordController.text;

            // 驗證Email
            if (email.isEmpty) {
                emailError = '請輸入Email';
                emailIsValid = false;
            } else if (!isValidEmail(email)) {
                emailError = '請輸入有效的Email';
                emailIsValid = false;
            } else {
                emailError = '';
                emailIsValid = true;
            }

            // 驗證密碼
            if (password.isEmpty) {
                passwordError = '請輸入密碼';
                passwordIsValid = false;
            } else if (!isValidPassword(password)) {
                passwordError = '密碼長度至少為6位';
                passwordIsValid = false;
            } else {
                passwordError = '';
                passwordIsValid = true;
            }
        });
        
        return emailIsValid && passwordIsValid;
    }

    // 檢查網路連接狀態
    Future<bool> _checkInternetConnection() async {
        // 實際專案中，這裡應該使用 connectivity_plus 套件
        // 現在先模擬網路檢查
        await Future.delayed(const Duration(milliseconds: 500));
        return isConnected; // 模擬網路狀態
    }

    // 處理 Firebase 認證錯誤
    void _handleFirebaseAuthError(FirebaseAuthException e) {
        String errorMessage;
        
        switch (e.code) {
            case 'user-not-found':
                errorMessage = '找不到此用戶，請檢查您的電子郵件';
                break;
            case 'wrong-password':
                errorMessage = '密碼錯誤，請重新輸入';
                break;
            case 'invalid-email':
                errorMessage = '電子郵件格式不正確';
                break;
            case 'user-disabled':
                errorMessage = '此帳戶已被停用，請聯繫管理員';
                break;
            case 'too-many-requests':
                errorMessage = '登入嘗試次數過多，請稍後再試';
                break;
            case 'network-request-failed':
                errorMessage = '網路連接失敗，請檢查您的網路設定';
                break;
            case 'invalid-credential':
                errorMessage = '登入憑證無效，請檢查電子郵件和密碼';
                break;
            default:
                errorMessage = '登入失敗：${e.message ?? '未知錯誤'}';
        }
        
        _handleLoginError(errorMessage);
    }

    // *** 修改：登入方法改進，移除角色選擇邏輯 ***
    //  執行登入邏輯 - 使用 Firebase 認證 (改進版本)
    void login() async {
        //  播放按鈕動畫
        _playButtonPressAnimation();
        
        //  驗證表單
        if (!validateForm()) {
            _playErrorShakeAnimation(); // 驗證失敗時震動
            return;
        }

        setState(() {
            isLoading = true; // 開始載入狀態
        });

        try {
            //  檢查網路連接
            bool hasInternet = await _checkInternetConnection();
            if (!hasInternet) {
                throw Exception('無網路連接，請檢查您的網路設定');
            }

            //  使用 Firebase Auth 進行登入
            UserCredential userCredential = await _auth.signInWithEmailAndPassword(
                email: emailController.text.trim(),
                password: passwordController.text,
            );

            if (userCredential.user != null) {
                // 獲取用戶角色信息
                String userRole = await _getUserRole(userCredential.user!.uid);
                
                // *** 修改：簡化邏輯，只檢查角色是否存在 ***
                if (userRole.isEmpty) {
                    // 如果沒有角色資料，這表示帳號沒有完成註冊流程
                    _handleLoginError('此帳號沒有完整的註冊資料，請重新註冊');
                    return;
                } else {
                    // 更新最後登入時間
                    await _firestore.collection('users').doc(userCredential.user!.uid).update({
                        'lastLoginAt': FieldValue.serverTimestamp(),
                    });
                    print('用戶登入成功，角色: $userRole');
                }

                //  登入成功：先顯示成功訊息
                _showSuccessMessage();

                // *** 修改：添加手動導航作為備用方案 ***
                await Future.delayed(const Duration(milliseconds: 1500));
                if (mounted) {
                    ScaffoldMessenger.of(context).removeCurrentSnackBar();
                    
                    // 手動導航到對應頁面（備用方案）
                    String routeName;
                    switch (userRole) {
                        case 'coach':
                            routeName = '/coachHome';
                            break;
                        case 'trainee':
                            routeName = '/studentHome';
                            break;
                        default:
                            routeName = '/login';
                    }
                    
                    if (kDebugMode) {
                        print('手動導航到: $routeName');
                    }
                    
                    // 使用 pushNamedAndRemoveUntil 確保清除所有之前的路由
                    Navigator.of(context).pushNamedAndRemoveUntil(
                        routeName,
                        (route) => false, // 清除所有路由
                    );
                }
            }
        } on FirebaseAuthException catch (e) {
            //  Firebase 認證失敗處理
            _handleFirebaseAuthError(e);
        } catch (error) {
            //  其他登入失敗處理
            _handleLoginError(error.toString());
        } finally {
            if (mounted) {
                setState(() {
                    isLoading = false; // 結束載入狀態
                });
            }
        }
    }

    //  顯示成功訊息
    void _showSuccessMessage() {
        _triggerHapticFeedback(); // 成功震動回饋
        
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Row(
                        children: const [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('登入成功！', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating, // 浮動式顯示
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 1),
                ),
            );
        }
    }

    //  處理登入錯誤
    void _handleLoginError(String errorMessage) {
        _playErrorShakeAnimation(); // 播放錯誤震動
        
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Row(
                        children: [
                            const Icon(Icons.error, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    errorMessage,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                            ),
                        ],
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 3),
                    action: SnackBarAction(
                        label: '重試',
                        textColor: Colors.white,
                        onPressed: login, // 點擊重試按鈕重新登入
                    ),
                ),
            );
        }
    }

    // 忘記密碼功能 - 使用 Firebase 密碼重設
    void forgotPassword() {
        _triggerHapticFeedback();
        
        // 如果用戶已經輸入了 email，直接使用
        String email = emailController.text.trim();
        
        showDialog(
            context: context,
            builder: (BuildContext context) {
                TextEditingController resetEmailController = TextEditingController(text: email);
                
                return AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                    ),
                    title: Row(
                        children: const [
                            Icon(Icons.help_outline, color: Color(0xFF173C56)),
                            SizedBox(width: 8),
                            Text('重設密碼'),
                        ],
                    ),
                    content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            const Text('請輸入您的電子郵件，我們將發送重設密碼連結給您。'),
                            const SizedBox(height: 16),
                            TextField(
                                controller: resetEmailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                    labelText: '電子郵件',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.email),
                                ),
                            ),
                        ],
                    ),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消', style: TextStyle(color: Colors.grey)),
                        ),
                        ElevatedButton(
                            onPressed: () async {
                                String resetEmail = resetEmailController.text.trim();
                                if (resetEmail.isEmpty || !isValidEmail(resetEmail)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('請輸入有效的電子郵件'),
                                            backgroundColor: Colors.red,
                                        ),
                                    );
                                    return;
                                }
                                
                                try {
                                    await _auth.sendPasswordResetEmail(email: resetEmail);
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text('重設密碼郵件已發送至 $resetEmail'),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                            ),
                                        ),
                                    );
                                } on FirebaseAuthException catch (e) {
                                    String errorMsg = e.code == 'user-not-found' 
                                        ? '找不到此電子郵件的用戶' 
                                        : '發送失敗：${e.message}';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(errorMsg),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                            ),
                                        ),
                                    );
                                }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF173C56),
                                foregroundColor: Colors.white,
                            ),
                            child: const Text('發送'),
                        ),
                    ],
                );
            },
        );
    }

    // 註冊功能 - 導向註冊頁面
    void register() {
        _triggerHapticFeedback(); // 震動回饋
        
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegisterScreen()),
        );
    }

    // *** 刪除：移除 registerWithFirebase() 方法 ***
    // 此方法已移動至 RegisterScreen，登入頁面不再需要註冊邏輯

    // 社群帳號登入功能
    void socialLogin(String platform) {
        _triggerHapticFeedback(); // 觸覺回饋
        
        showDialog(
            context: context,
            builder: (BuildContext context) {
                return AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                    ),
                    title: Row(
                        children: [
                            Icon(
                                _getSocialIcon(platform), 
                                color: _getSocialColor(platform),
                            ),
                            const SizedBox(width: 8),
                            Text('$platform 登入'),
                        ],
                    ),
                    content: Text('使用 $platform 帳號登入功能開發中\n\n此功能將在未來版本中推出，敬請期待！'),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('確定', style: TextStyle(color: Color(0xFF173C56))),
                        ),
                    ],
                );
            },
        );
    }

    // 取得社群平台圖標
    IconData _getSocialIcon(String platform) {
        switch (platform) {
            case 'Google': return Icons.g_mobiledata;
            case 'Apple': return Icons.apple;
            case 'Facebook': return Icons.facebook;
            default: return Icons.account_circle;
        }
    }

    // 取得社群平台顏色
    Color _getSocialColor(String platform) {
        switch (platform) {
            case 'Google': return Colors.red;
            case 'Apple': return Colors.black;
            case 'Facebook': return Colors.blue;
            default: return Colors.grey;
        }
    }

    // 取得 Email 驗證圖標 - 根據驗證狀態返回不同圖標
    Widget _getEmailValidationIcon() {
        if (!emailTouched) return const SizedBox.shrink(); // 未觸碰時不顯示
        
        return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300), // 切換動畫時長
            child: emailIsValid 
                ? const Icon(Icons.check_circle, color: Colors.green, key: Key('valid'))
                : const Icon(Icons.error, color: Colors.red, key: Key('invalid')),
        );
    }

    // 取得密碼驗證圖標
    Widget _getPasswordValidationIcon() {
        if (!passwordTouched) return const SizedBox.shrink();
        
        return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: passwordIsValid 
                ? const Icon(Icons.check_circle, color: Colors.green, key: Key('valid'))
                : const Icon(Icons.error, color: Colors.red, key: Key('invalid')),
        );
    }

    // 取得輸入框顏色 (根據驗證狀態返回不同顏色)
    Color _getInputBorderColor(bool isTouched, bool isValid) {
        if (!isTouched) {
            return Colors.grey; // 未觸碰時為灰色
        }
        return isValid ? Colors.green : Colors.red; // 有效為綠色，無效為紅色
    }

    // 取得輸入框陰影效果 - 只在觸碰後根據驗證狀態顯示
    List<BoxShadow> _getInputBoxShadow(bool isTouched, bool isValid) {
        if (!isTouched) {
            return []; // 未觸碰：無陰影
        }
        
        if (isValid) {
            return [
                BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                ),
            ];
        } else {
            return [
                BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                ),
            ];
        }
    }

    // 登出功能（在需要的地方調用）
    Future<void> signOut() async {
        try {
            await _auth.signOut();
            Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
            );
        } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('登出失敗：$e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                    ),
                ),
            );
        }
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            backgroundColor: const Color(0xFFE8F4FD),
            appBar: AppBar(
                title: const Text('Login'),
                backgroundColor: const Color(0xFF173C56),
                elevation: 0,
            ),
            body: SafeArea(  // 避免內容被狀態欄遮擋
                child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                        return Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0), // 應用震動偏移
                            child: child,
                        );
                    },
                    child: SingleChildScrollView(

                        child: Column(  // 垂直排列的容器
                            children: <Widget>[

                                // 頂部間距
                                SizedBox(height: 20), // 純粹用來佔空間的Widget

                                // 頭像
                                Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: [Colors.blue, Colors.purple],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                            BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 10,
                                                offset: Offset(0, 5),
                                            ),
                                        ],
                                    ),
                                    alignment: Alignment.center,
                                    child: ClipOval(
                                        child: Image.asset(
                                            'assets/anim/Login_Food.gif',
                                            width: 110,
                                            height: 110,
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.none,
                                        ),
                                    ),
                                ),

                                const SizedBox(height: 30),

                                // *** 修改：確保容器完全居中，修復偏移問題 ***
                                Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center, // *** 新增：確保居中對齊 ***
                                        children: [
                                            Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                                            const SizedBox(width: 8),
                                            Text( // *** 修改：移除 Expanded，使用固定文字 ***
                                                '系統將自動識別您的身分',
                                                style: TextStyle(
                                                    color: Colors.blue[700],
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                ),
                                            ),
                                        ],
                                    ),
                                ),

                                // 表單容器
                                Container(
                                    width: double.infinity,  // 確保容器佔滿寬度
                                    margin: const EdgeInsets.symmetric(horizontal: 0), // *** 新增：確保沒有額外邊距 ***
                                    padding: const EdgeInsets.all(30),
                                    decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(40),
                                            topRight: Radius.circular(40),
                                        ),
                                        boxShadow: [
                                            BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 20,
                                                offset: Offset(0, 10),
                                            ),
                                        ],
                                    ),
                                    child:Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            // Email 輸入框
                                            Text(
                                                'Email',
                                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                            SizedBox(height: 8,),

                                            //Email輸入框動畫效果
                                            AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            width: double.infinity, // *** 新增：確保佔滿寬度 ***
                                            decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                boxShadow: _getInputBoxShadow(emailTouched, emailIsValid),
                                            ),
                                            child: TextField(
                                                controller: emailController,
                                                keyboardType: TextInputType.emailAddress,
                                                decoration: InputDecoration(
                                                    hintText: '請輸入您的Email',
                                                    hintStyle: TextStyle(color: Colors.grey[400]),
                                                    prefixIcon: AnimatedContainer(
                                                        duration: const Duration(milliseconds: 300),
                                                        child: Icon(
                                                        Icons.email_outlined,
                                                        color: Colors.grey,
                                                        ),
                                                    ),
                                                    suffixIcon: _getEmailValidationIcon(), // 驗證圖標
                                                    border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(20),
                                                        borderSide: BorderSide(
                                                            color: _getInputBorderColor(emailTouched, emailIsValid),
                                                            width: 2,
                                                            ), //邊框
                                                    ),
                                                    errorBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(20),
                                                        borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                                    ),
                                                    filled: true,
                                                    focusedBorder: OutlineInputBorder( //點擊時的邊框
                                                        borderRadius: BorderRadius.circular(20),
                                                        borderSide: BorderSide(
                                                            color: !emailTouched 
                                                                ? const Color(0xFF173C56)
                                                                : _getInputBorderColor(emailTouched, emailIsValid),
                                                            width: 2,
                                                        ),
                                                    ),
                                                    fillColor: const Color(0xFFF1F2F4),
                                                    // 錯誤提示
                                                    errorText: emailTouched && emailError.isNotEmpty ? emailError : null,
                                                ),
                                            ),
                                            ),
                                        
                                            
                                            // 密碼輸入框
                                            Text(
                                                '密碼',
                                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                            SizedBox(height: 8,),

                                            // 密碼輸入框動畫效果
                                            AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            width: double.infinity, // *** 新增：確保佔滿寬度 ***
                                            decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                boxShadow: _getInputBoxShadow(passwordTouched, passwordIsValid),
                                            ),
                                            child: TextField(
                                                controller: passwordController,
                                                obscureText: !isPasswordVisible,
                                                decoration: InputDecoration(
                                                    hintText: '請輸入您的密碼',
                                                    hintStyle: TextStyle(color: Colors.grey[400]),
                                                    prefixIcon: AnimatedContainer(
                                                        duration: const Duration(milliseconds: 300),
                                                        child: Icon(
                                                        Icons.lock_outline,
                                                        color: Colors.grey,
                                                        ),
                                                    ),
                                                    suffixIcon: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                            _getPasswordValidationIcon(), // 驗證圖標
                                                            IconButton(
                                                                icon: Icon(
                                                                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                                                    color: const Color.fromARGB(255, 65, 62, 62),
                                                                ),
                                                                onPressed: () {
                                                                    _triggerHapticFeedback(); // 觸覺回饋
                                                                    setState(() {
                                                                        isPasswordVisible = !isPasswordVisible; // 切換密碼顯示狀態
                                                                    });
                                                                },
                                                            ),
                                                        ],
                                                    ),
                                                    border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(20),
                                                        borderSide: BorderSide(
                                                            color: _getInputBorderColor(passwordTouched, passwordIsValid),
                                                            width: 2,
                                                        ), //邊框
                                                    ),
                                                
                                                    focusedBorder: OutlineInputBorder( //點擊時的邊框
                                                        borderRadius: BorderRadius.circular(20),
                                                        borderSide: BorderSide(
                                                                color: !passwordTouched 
                                                                    ? const Color(0xFF173C56)
                                                                    : _getInputBorderColor(passwordTouched, passwordIsValid),
                                                                width: 2,
                                                        ),
                                                    ),
                                                    errorBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(20),
                                                        borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                                    ),
                                                    filled: true,
                                                    fillColor: const Color(0xFFF1F2F4),
                                                    // 錯誤提示
                                                    errorText: passwordTouched && passwordError.isNotEmpty ? passwordError : null,
                                                ),
                                            ),
                                            ),

                                            // 密碼強度指示器
                                            _buildPasswordStrengthIndicator(),

                                            // 忘記密碼按鈕
                                            SizedBox(height: 10),
                                            Align(
                                                alignment: Alignment.centerRight,
                                                child: TextButton(
                                                    onPressed: forgotPassword,
                                                    style: TextButton.styleFrom(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        splashFactory: InkRipple.splashFactory, // 水波紋效果
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap, // 減少點擊區域
                                                    ),
                                                    child: const Text(
                                                        '忘記密碼？',
                                                        style: TextStyle(
                                                            color:  Color(0xFF2C5F7C),
                                                            fontSize: 14,
                                                        ),
                                                    ),
                                                ),
                                            ),

                                            SizedBox(height: 20),

                                            //登入按鈕
                                            AnimatedBuilder(
                                            animation: _buttonScaleAnimation,
                                            builder: (context, child) {
                                                return Transform.scale(
                                                    scale: _buttonScaleAnimation.value, // 縮放動畫
                                                    child: SizedBox(
                                                        width: double.infinity,
                                                        height: 50,
                                                        child: ElevatedButton(
                                                            onPressed: isLoading ? null : login, // 載入中禁用按鈕
                                                            style: ElevatedButton.styleFrom(
                                                                minimumSize: const Size.fromHeight(54),
                                                                backgroundColor: isLoading 
                                                                    ? Colors.grey[400] // 載入中變灰色
                                                                    : const Color(0xFF173C56),
                                                                foregroundColor: Colors.white,
                                                                shape: RoundedRectangleBorder(
                                                                    borderRadius: BorderRadius.circular(28),
                                                                ),
                                                                elevation: isLoading ? 0 : 2, // 載入中去除陰影
                                                                // 按鈕漸層效果
                                                                shadowColor: const Color(0xFF173C56),
                                                            ),
                                                            child: isLoading
                                                                ? Row(
                                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                                    children: [
                                                                        SizedBox(
                                                                            width: 20,
                                                                            height: 20,
                                                                            child: CircularProgressIndicator(
                                                                                strokeWidth: 2,
                                                                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 10),
                                                                        const Text('登入中...'),
                                                                    ],
                                                                )
                                                                : Row(
                                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                                    children: [
                                                                        // 成功圖標 (條件顯示)
                                                                        AnimatedSwitcher(
                                                                            duration: const Duration(milliseconds: 300),
                                                                            child: emailIsValid && passwordIsValid
                                                                                ? const Icon(Icons.login, size: 20)
                                                                                : const SizedBox.shrink(),
                                                                        ),
                                                                        if (emailIsValid && passwordIsValid) const SizedBox(width: 8),
                                                                        const Text(
                                                                            '登入',
                                                                            style: TextStyle(
                                                                                color: Colors.white,
                                                                                fontSize: 20,
                                                                                fontWeight: FontWeight.w800,
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
                                                        ),
                                                    ),
                                                );
                                            },
                                        ),

                                            SizedBox(height: 15),

                                            // 註冊按鈕
                                            SizedBox(
                                                width: double.infinity,
                                                height: 50,
                                                child: OutlinedButton(
                                                    onPressed: register,
                                                    style: OutlinedButton.styleFrom(
                                                        minimumSize: const Size.fromHeight(54), // 按鈕高度
                                                        side: BorderSide(color: const Color(0xFF173C56), width: 1.5),
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(28),
                                                        ),
                                                        //懸停效果
                                                        foregroundColor: const Color(0xFF2C5F7C),
                                                        overlayColor: const Color(0xFF173C56),

                                                    ),
                                                    child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: const [
                                                            Icon(Icons.person_add, size: 20, color: Color(0xFF2C5F7C)),
                                                            SizedBox(width: 8),
                                                            Text(
                                                                '註冊帳號',
                                                                style: TextStyle(
                                                                    color:  Color(0xFF2C5F7C),
                                                                    fontSize: 20,
                                                                    fontWeight: FontWeight.w800,
                                                                ),
                                                            ),
                                                        ],
                                                    ),
                                                ),
                                            ),

                                            SizedBox(height: 20),

                                            //分隔線
                                            Row(
                                                children: [
                                                    Expanded(child: Divider(color: Colors.black12)),
                                                    Padding(
                                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                                        child: Text(
                                                            '或以下方式登入',
                                                            style: TextStyle(
                                                                color: Colors.black54,
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w600,
                                                            ),
                                                        ),
                                                    ),
                                                    Expanded(child: Divider(color: Colors.black12)),
                                                ],
                                            ),

                                            SizedBox(height: 20),

                                            // 社群帳號登入按鈕
                                            Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                    //google登入
                                                    _buildSocialButton(
                                                        onPressed: () => socialLogin('Google'),
                                                        child: Image.asset(
                                                            'assets/icons/google_icon.png',
                                                            width: 24,
                                                            height: 24,
                                                            filterQuality: FilterQuality.none,
                                                        ),
                                                    ),

                                                    //apple登入
                                                    _buildSocialButton(
                                                        onPressed: () => socialLogin('Apple'),
                                                        child: Image.asset(
                                                            'assets/icons/apple_icon.png',
                                                            width: 24,
                                                            height: 24,
                                                            filterQuality: FilterQuality.none,
                                                        ),
                                                    ),

                                                    //facebook登入
                                                    _buildSocialButton(
                                                        onPressed: () => socialLogin('Facebook'),
                                                        child: Image.asset(
                                                            'assets/icons/facebook_icon.png',
                                                            width: 24,
                                                            height: 24,
                                                            filterQuality: FilterQuality.none,
                                                        ),
                                                    ),
                                                ],
                                            ),                                            
                                        ],
                                    ),
                                ),
                        ],
                    ),
                ),
            ),
            )
        );
    }

    //社群登入按鈕
    Widget _buildSocialButton({required VoidCallback onPressed, required Widget child}) {
        return Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                    ),
                ],
            ),
            child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(14),
                child: Center(child: child),
            ),
        );
    }

    // 清理資源，防止記憶體洩漏
    @override
    void dispose() {
        _buttonAnimationController.dispose();
        _shakeAnimationController.dispose();
        emailController.dispose();
        passwordController.dispose();
        super.dispose();
    }
}