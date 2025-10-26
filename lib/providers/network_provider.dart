// lib/providers/network_provider.dart
// 🔬 加強版 - 包含詳細診斷日誌

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class NetworkProvider extends ChangeNotifier {
  static final NetworkProvider _instance = NetworkProvider._internal();
  
  factory NetworkProvider() {
    if (kDebugMode) {
      print('🏭 NetworkProvider: 返回單例實例 (hashCode: ${_instance.hashCode})');
    }
    return _instance;
  }
  
  NetworkProvider._internal() {
    if (kDebugMode) {
      print('🏗️  NetworkProvider: 創建單例實例 (hashCode: $hashCode)');
    }
  }

  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  int _notifyCount = 0;

  bool get isOnline {
    if (kDebugMode) {
      print('📊 NetworkProvider.isOnline 被讀取: $_isOnline');
    }
    return _isOnline;
  }

  Future<void> initialize() async {
    if (kDebugMode) {
      print('🚀 NetworkProvider.initialize() 開始 (hashCode: $hashCode)');
    }
    
    // 初次檢查
    await checkConnectivity();
    
    // 監聽網路變化
    if (kDebugMode) {
      print('👂 NetworkProvider: 開始監聽網路變化...');
    }
    
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
    
    if (kDebugMode) {
      print('✅ NetworkProvider: 初始化完成');
      print('   - hashCode: $hashCode');
      print('   - isOnline: $_isOnline');
      print('   - subscription: ${_subscription != null ? "已設置" : "未設置"}');
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (kDebugMode) {
      print('🔄 NetworkProvider._handleConnectivityChange() 被調用');
      print('   - 收到的結果: $results');
      print('   - 當前狀態: $_isOnline');
    }
    
    final wasOnline = _isOnline;
    
    // 如果任何一個連接不是 none，就認為有網路
    _isOnline = results.any((result) => result != ConnectivityResult.none);
    
    if (kDebugMode) {
      print('   - 新狀態: $_isOnline');
      print('   - 狀態改變: ${wasOnline != _isOnline ? "是" : "否"}');
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

  Future<void> checkConnectivity() async {
    if (kDebugMode) {
      print('🔍 NetworkProvider.checkConnectivity() 開始');
    }
    
    try {
      final results = await Connectivity().checkConnectivity();
      
      if (kDebugMode) {
        print('   - 檢查結果: $results');
      }
      
      _handleConnectivityChange(results);
      
      if (kDebugMode) {
        print('   ✅ 檢查完成: ${_isOnline ? "已連線" : "已斷線"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('   ❌ 檢查失敗: $e');
      }
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('🗑️  NetworkProvider.dispose() 被調用');
    }
    _subscription?.cancel();
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