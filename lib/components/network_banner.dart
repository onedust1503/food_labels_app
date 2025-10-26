// lib/components/network_banner.dart
// 🔬 加強版 - 包含詳細診斷日誌

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/network_provider.dart';

class NetworkBanner extends StatefulWidget {
  final Widget child;

  const NetworkBanner({
    super.key,
    required this.child,
  });

  @override
  State<NetworkBanner> createState() => _NetworkBannerState();
}

class _NetworkBannerState extends State<NetworkBanner> {
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('🎨 NetworkBanner.initState() 被調用');
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('🗑️  NetworkBanner.dispose() 被調用');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('🎨 NetworkBanner.build() 被調用');
    }
    
    return Consumer<NetworkProvider>(
      builder: (context, networkProvider, child) {
        if (kDebugMode) {
          print('📺 NetworkBanner.Consumer.builder() 被調用');
          print('   - NetworkProvider hashCode: ${networkProvider.hashCode}');
          print('   - isOnline: ${networkProvider.isOnline}');
          print('   - 應該顯示橫幅: ${!networkProvider.isOnline}');
        }
        
        return Stack(
          children: [
            // 主要內容（首頁）
            widget.child,
            
            // 網路橫幅（浮動在頂部）
            if (!networkProvider.isOnline) ...[
              if (kDebugMode) _buildDebugIndicator(),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Material(
                    color: Colors.red.shade700,
                    elevation: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '網路連接已中斷',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              if (kDebugMode) {
                                print('🔄 重試按鈕被點擊');
                              }
                              await networkProvider.checkConnectivity();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text(
                              '重試',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Debug 模式下在橫幅下方顯示綠色指示器
  Widget _buildDebugIndicator() {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.green,
        padding: const EdgeInsets.all(8),
        child: const Text(
          '🐛 DEBUG: 橫幅應該在上方顯示',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}