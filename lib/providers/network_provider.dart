// lib/providers/network_provider.dart
// 🚀 修復版 v3 - 確保定期檢查始終運行

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';

class NetworkProvider extends ChangeNotifier {
  static final NetworkProvider _instance = NetworkProvider._internal();
  
  // ✅ 追蹤是否已初始化
  bool _isInitialized = false;
  
  factory NetworkProvider() {
    if (kDebugMode) {
      print('🏭 NetworkProvider: 返回單例實例 (hashCode: ${_instance.hashCode}, initialized: ${_instance._isInitialized})');
    }
    
    // ✅ 如果還沒初始化，自動初始化（解決 Hot Reload 問題）
    if (!_instance._isInitialized) {
      _instance._autoInitialize();
    }
    
    return _instance;
  }
  
  NetworkProvider._internal() {
    if (kDebugMode) {
      print('🏗️  NetworkProvider: 創建單例實例 (hashCode: $hashCode)');
    }
  }

  bool _isOnline = true;
  bool _wasOffline = false;
  bool _showRecoveryBanner = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _recoveryBannerTimer;
  Timer? _periodicCheckTimer;
  int _notifyCount = 0;

  bool get isOnline {
    if (kDebugMode) {
      print('📊 NetworkProvider.isOnline 被讀取: $_isOnline');
    }
    return _isOnline;
  }
  
  bool get showRecoveryBanner => _showRecoveryBanner;

  // ✅ 新增：自動初始化（用於 Hot Reload 後自動恢復）
  void _autoInitialize() {
    if (kDebugMode) {
      print('🔄 NetworkProvider: 自動初始化...');
    }
    initialize();
  }

  Future<void> initialize() async {
    // ✅ 防止重複初始化
    if (_isInitialized) {
      if (kDebugMode) {
        print('⚠️  NetworkProvider: 已經初始化過，跳過');
      }
      return;
    }
    
    _isInitialized = true;
    
    if (kDebugMode) {
      print('🚀 NetworkProvider.initialize() 開始 (hashCode: $hashCode)');
    }
    
    // 初次檢查
    await checkConnectivity();
    
    // 監聽網路變化
    if (kDebugMode) {
      print('👂 NetworkProvider: 開始監聽網路變化...');
    }
    
    _subscription?.cancel();  // 取消舊的監聽
    _subscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (kDebugMode) {
          print('📡 NetworkProvider: 收到網路變化事件: $results');
        }
        _handleConnectivityChange(results);
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ NetworkProvider: 監聽錯誤: $error');
        }
      },
      onDone: () {
        if (kDebugMode) {
          print('⚠️  NetworkProvider: 監聽結束');
        }
      },
    );
    
    // ✅ 啟動定期檢查（每 10 秒）
    _startPeriodicCheck();
    
    if (kDebugMode) {
      print('✅ NetworkProvider: 初始化完成');
      print('   - hashCode: $hashCode');
      print('   - isOnline: $_isOnline');
      print('   - subscription: ${_subscription != null ? "已設置" : "未設置"}');
      print('   - periodicCheck: 每 10 秒');
    }
  }

  // ✅ 定期檢查網路連線
  void _startPeriodicCheck() {
    _periodicCheckTimer?.cancel();
    
    if (kDebugMode) {
      print('⏰ NetworkProvider: 啟動定期檢查計時器 (每 10 秒)');
    }
    
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (kDebugMode) {
        print('⏰ NetworkProvider: 定期檢查網路... (第 ${timer.tick} 次)');
      }
      
      // 只有在有 WiFi/行動網路連接時才做真實測試
      final results = await Connectivity().checkConnectivity();
      final hadConnection = results.any((result) => result != ConnectivityResult.none);
      
      if (kDebugMode) {
        print('   - 連接狀態: $results');
        print('   - 有連接: $hadConnection');
      }
      
      if (hadConnection) {
        final reallyOnline = await _checkRealConnectivity();
        
        // 只有狀態改變時才更新
        if (reallyOnline != _isOnline) {
          if (kDebugMode) {
            print('⏰ 定期檢查發現狀態改變: $_isOnline -> $reallyOnline');
          }
          _updateOnlineStatus(reallyOnline);
        } else {
          if (kDebugMode) {
            print('   - 狀態未改變: $_isOnline');
          }
        }
      } else if (_isOnline) {
        // 連接斷開但狀態還是 online
        if (kDebugMode) {
          print('⏰ 定期檢查: 無連接，設為離線');
        }
        _updateOnlineStatus(false);
      }
    });
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) async {
    if (kDebugMode) {
      print('🔄 NetworkProvider._handleConnectivityChange() 被調用');
      print('   - 收到的結果: $results');
      print('   - 當前狀態: $_isOnline');
    }
    
    final hadConnection = results.any((result) => result != ConnectivityResult.none);
    
    if (hadConnection) {
      final reallyOnline = await _checkRealConnectivity();
      _updateOnlineStatus(reallyOnline);
    } else {
      _updateOnlineStatus(false);
    }
  }

  void _updateOnlineStatus(bool newStatus) {
    final wasOnline = _isOnline;
    _isOnline = newStatus;
    
    if (kDebugMode) {
      print('   - 新狀態: $_isOnline');
      print('   - 狀態改變: ${wasOnline != _isOnline ? "是" : "否"}');
    }
    
    // 從斷線恢復連線時，顯示恢復橫幅
    if (!wasOnline && newStatus && _wasOffline) {
      _showRecoveryBanner = true;
      
      _recoveryBannerTimer?.cancel();
      _recoveryBannerTimer = Timer(const Duration(seconds: 3), () {
        _showRecoveryBanner = false;
        notifyListeners();
      });
      
      if (kDebugMode) {
        print('🟢 NetworkProvider: 網路已恢復，顯示恢復橫幅');
      }
    }
    
    if (!newStatus) {
      _wasOffline = true;
    }
    
    if (wasOnline != _isOnline) {
      _notifyCount++;
      if (kDebugMode) {
        print('🔔 NetworkProvider: 狀態改變，調用 notifyListeners() (第 $_notifyCount 次)');
        print('   🌐 網路狀態變更: ${_isOnline ? "已連線 ✅" : "已斷線 ❌"}');
      }
      notifyListeners();
      if (kDebugMode) {
        print('   ✅ notifyListeners() 執行完成');
      }
    }
  }

  // ✅ 使用 TCP Socket 連接測試
  Future<bool> _checkRealConnectivity() async {
    try {
      if (kDebugMode) {
        print('🔍 NetworkProvider: 進行真實網路測試 (TCP Socket)...');
      }
      
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      
      if (kDebugMode) {
        print('   - TCP Socket 連線測試: 成功 ✅');
      }
      return true;
      
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('   - TCP Socket 連線測試: SocketException ❌');
        print('   - 錯誤: ${e.message}');
      }
      return false;
    } on TimeoutException catch (_) {
      if (kDebugMode) {
        print('   - TCP Socket 連線測試: 超時 ❌');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('   - TCP Socket 連線測試錯誤: $e');
      }
      
      // 備用方案
      try {
        if (kDebugMode) {
          print('   - 嘗試備用測試 (Cloudflare DNS)...');
        }
        final socket2 = await Socket.connect(
          '1.1.1.1',
          53,
          timeout: const Duration(seconds: 3),
        );
        socket2.destroy();
        
        if (kDebugMode) {
          print('   - 備用測試: 成功 ✅');
        }
        return true;
      } catch (_) {
        if (kDebugMode) {
          print('   - 備用測試: 失敗 ❌');
        }
        return false;
      }
    }
  }

  Future<void> checkConnectivity() async {
    if (kDebugMode) {
      print('🔍 NetworkProvider.checkConnectivity() 開始');
    }
    
    try {
      final results = await Connectivity().checkConnectivity();
      
      if (kDebugMode) {
        print('   - 檢查結果: $results');
      }
      
      final hadConnection = results.any((result) => result != ConnectivityResult.none);
      
      if (hadConnection) {
        final reallyOnline = await _checkRealConnectivity();
        _updateOnlineStatus(reallyOnline);
      } else {
        _updateOnlineStatus(false);
      }
      
      if (kDebugMode) {
        print('   ✅ 檢查完成: ${_isOnline ? "已連線" : "已斷線"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('   ❌ 檢查失敗: $e');
      }
      _updateOnlineStatus(false);
    }
  }

  void hideRecoveryBanner() {
    _showRecoveryBanner = false;
    _recoveryBannerTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('🗑️  NetworkProvider.dispose() 被調用');
    }
    _subscription?.cancel();
    _recoveryBannerTimer?.cancel();
    _periodicCheckTimer?.cancel();
    _isInitialized = false;  // ✅ 重置初始化狀態
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (kDebugMode) {
      print('📢 NetworkProvider.notifyListeners() 被調用 (hasListeners: $hasListeners)');
    }
    super.notifyListeners();
  }
}