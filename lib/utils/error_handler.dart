// lib/utils/error_handler.dart
// 🚨 統一錯誤處理器 - 處理錯誤顯示邏輯

import 'package:flutter/material.dart';
import 'result.dart';

class ErrorHandler {
  /// 顯示錯誤 SnackBar
  static void showError(
    BuildContext context,
    AppException error, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getErrorIcon(error.type),
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error.message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _getErrorColor(error.type),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: duration,
        action: action,
      ),
    );
  }

  /// 顯示成功訊息
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: duration,
      ),
    );
  }

  /// 顯示錯誤對話框
  static void showErrorDialog(
    BuildContext context,
    AppException error, {
    String? title,
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getErrorIcon(error.type),
              color: _getErrorColor(error.type),
            ),
            const SizedBox(width: 12),
            Text(title ?? '發生錯誤'),
          ],
        ),
        content: Text(error.message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('重試'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  /// 處理 Result - 自動顯示錯誤或執行成功回調
  static T? handleResult<T>(
    BuildContext context,
    Result<T> result, {
    String? successMessage,
    void Function(T data)? onSuccess,
    VoidCallback? onError,
    bool showSuccessMessage = false,
  }) {
    if (result.isSuccess) {
      if (showSuccessMessage && successMessage != null) {
        showSuccess(context, successMessage);
      }
      if (onSuccess != null && result.data != null) {
        onSuccess(result.data as T);
      }
      return result.data;
    } else {
      showError(context, result.error ?? AppException.unknown());
      onError?.call();
      return null;
    }
  }

  /// 獲取錯誤圖標
  static IconData _getErrorIcon(AppExceptionType type) {
    switch (type) {
      case AppExceptionType.network:
        return Icons.wifi_off;
      case AppExceptionType.unauthorized:
        return Icons.lock;
      case AppExceptionType.forbidden:
        return Icons.block;
      case AppExceptionType.notFound:
        return Icons.search_off;
      case AppExceptionType.validation:
        return Icons.error_outline;
      case AppExceptionType.firebase:
        return Icons.cloud_off;
      case AppExceptionType.unknown:
        return Icons.error;
    }
  }

  /// 獲取錯誤顏色
  static Color _getErrorColor(AppExceptionType type) {
    switch (type) {
      case AppExceptionType.network:
        return Colors.orange;
      case AppExceptionType.unauthorized:
      case AppExceptionType.forbidden:
        return Colors.red.shade700;
      case AppExceptionType.notFound:
        return Colors.blue.shade700;
      case AppExceptionType.validation:
        return Colors.amber.shade700;
      case AppExceptionType.firebase:
      case AppExceptionType.unknown:
        return Colors.red;
    }
  }
}