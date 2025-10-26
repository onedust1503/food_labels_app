// lib/utils/result.dart
// 📦 Result 封裝類別 - 統一處理成功/失敗結果

/// Result<T> - 封裝操作結果
/// 
/// 使用範例:
/// ```dart
/// Future<Result<User>> getUser() async {
///   try {
///     final user = await fetchUser();
///     return Result.success(user);
///   } catch (e) {
///     return Result.failure(AppException.fromError(e));
///   }
/// }
/// ```
class Result<T> {
  final T? data;
  final AppException? error;
  final bool isSuccess;

  Result._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  /// 建立成功結果
  factory Result.success(T data) {
    return Result._(
      data: data,
      isSuccess: true,
    );
  }

  /// 建立失敗結果
  factory Result.failure(AppException error) {
    return Result._(
      error: error,
      isSuccess: false,
    );
  }

  /// 是否為失敗
  bool get isFailure => !isSuccess;

  /// 獲取資料 (如果成功)
  T get dataOrThrow {
    if (isSuccess && data != null) {
      return data!;
    }
    throw error ?? AppException.unknown();
  }

  /// 獲取資料或預設值
  T getOrElse(T defaultValue) {
    return data ?? defaultValue;
  }

  /// 映射資料
  Result<R> map<R>(R Function(T data) transform) {
    if (isSuccess && data != null) {
      try {
        return Result.success(transform(data!));
      } catch (e) {
        return Result.failure(AppException.fromError(e));
      }
    }
    return Result.failure(error ?? AppException.unknown());
  }

  /// 處理結果
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) {
    if (isSuccess && data != null) {
      return success(data!);
    }
    return failure(error ?? AppException.unknown());
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'Result.success($data)';
    }
    return 'Result.failure($error)';
  }
}

/// AppException - 自定義錯誤類型
class AppException implements Exception {
  final String message;
  final String? code;
  final AppExceptionType type;
  final dynamic originalError;

  AppException({
    required this.message,
    this.code,
    required this.type,
    this.originalError,
  });

  /// 從任意錯誤建立 AppException
  factory AppException.fromError(dynamic error) {
    if (error is AppException) {
      return error;
    }

    String message = '發生未知錯誤';
    String? code;
    AppExceptionType type = AppExceptionType.unknown;

    // Firebase 相關錯誤
    if (error.toString().contains('firebase') || 
        error.toString().contains('FirebaseException')) {
      type = AppExceptionType.firebase;
      message = _extractFirebaseMessage(error);
      code = _extractFirebaseCode(error);
    }
    // 網路錯誤
    else if (error.toString().contains('network') ||
             error.toString().contains('SocketException') ||
             error.toString().contains('HandshakeException')) {
      type = AppExceptionType.network;
      message = '網路連接失敗，請檢查網路設定';
    }
    // 其他錯誤
    else {
      message = error.toString();
    }

    return AppException(
      message: message,
      code: code,
      type: type,
      originalError: error,
    );
  }

  /// 網路錯誤
  factory AppException.network({String? message}) {
    return AppException(
      message: message ?? '網路連接失敗，請檢查網路設定',
      type: AppExceptionType.network,
    );
  }

  /// 未登入
  factory AppException.unauthorized({String? message}) {
    return AppException(
      message: message ?? '請先登入',
      type: AppExceptionType.unauthorized,
    );
  }

  /// 權限不足
  factory AppException.forbidden({String? message}) {
    return AppException(
      message: message ?? '您沒有權限執行此操作',
      type: AppExceptionType.forbidden,
    );
  }

  /// 資源不存在
  factory AppException.notFound({String? message}) {
    return AppException(
      message: message ?? '找不到請求的資源',
      type: AppExceptionType.notFound,
    );
  }

  /// 驗證錯誤
  factory AppException.validation({String? message}) {
    return AppException(
      message: message ?? '輸入資料格式不正確',
      type: AppExceptionType.validation,
    );
  }

  /// 未知錯誤
  factory AppException.unknown({String? message}) {
    return AppException(
      message: message ?? '發生未知錯誤',
      type: AppExceptionType.unknown,
    );
  }

  /// Firebase 錯誤
  factory AppException.firebase({
    required String message,
    String? code,
    dynamic originalError,
  }) {
    return AppException(
      message: message,
      code: code,
      type: AppExceptionType.firebase,
      originalError: originalError,
    );
  }

  /// 提取 Firebase 錯誤訊息
  static String _extractFirebaseMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('permission-denied')) {
      return '您沒有權限執行此操作';
    } else if (errorStr.contains('not-found')) {
      return '找不到請求的資源';
    } else if (errorStr.contains('already-exists')) {
      return '資源已存在';
    } else if (errorStr.contains('network')) {
      return '網路連接失敗';
    } else if (errorStr.contains('unavailable')) {
      return '服務暫時無法使用，請稍後再試';
    }
    
    return '操作失敗，請稍後再試';
  }

  /// 提取 Firebase 錯誤代碼
  static String? _extractFirebaseCode(dynamic error) {
    final errorStr = error.toString();
    final match = RegExp(r'\[([^\]]+)\]').firstMatch(errorStr);
    return match?.group(1);
  }

  @override
  String toString() {
    return 'AppException(type: $type, message: $message, code: $code)';
  }
}

/// 錯誤類型枚舉
enum AppExceptionType {
  network,        // 網路錯誤
  unauthorized,   // 未登入
  forbidden,      // 權限不足
  notFound,       // 資源不存在
  validation,     // 驗證錯誤
  firebase,       // Firebase 錯誤
  unknown,        // 未知錯誤
}